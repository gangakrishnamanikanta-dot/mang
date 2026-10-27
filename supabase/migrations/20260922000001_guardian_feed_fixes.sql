-- ── Migration: 20260922000001_guardian_feed_fixes.sql ──────────
-- Fix for relation "public.profile_photos" does not exist and 
-- function "public.calculate_reciprocal_compatibility" missing signatures.

-- 1. Create the missing profile_photos table
CREATE TABLE IF NOT EXISTS public.profile_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    is_approved BOOLEAN DEFAULT false,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profile_photos_profile_id ON public.profile_photos(profile_id);

ALTER TABLE public.profile_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public view for profile photos" ON public.profile_photos;
CREATE POLICY "Public view for profile photos" 
    ON public.profile_photos FOR SELECT 
    USING (true);

DROP POLICY IF EXISTS "Users can manage own photos" ON public.profile_photos;
CREATE POLICY "Users can manage own photos" 
    ON public.profile_photos FOR ALL 
    USING (auth.uid() = profile_id);

-- 2. Recreate calculate_reciprocal_compatibility(profiles, partner_preferences, profiles, partner_preferences)
-- This signature is explicitly called by older RPCs and matches the exact user error.
CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user      public.profiles,
    p_user_pref public.partner_preferences,
    p_cand      public.profiles,
    p_cand_pref public.partner_preferences
)
RETURNS float8
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_forward_score float8 := 50.0;
    v_reverse_score float8 := 50.0;
    v_final_score   float8;
    v_cand_age      integer;
    v_user_age      integer;
    v_hours_since_active float8;
BEGIN
    IF p_cand.date_of_birth IS NOT NULL THEN
        v_cand_age := EXTRACT(YEAR FROM age(p_cand.date_of_birth))::integer;
    END IF;
    IF p_user.date_of_birth IS NOT NULL THEN
        v_user_age := EXTRACT(YEAR FROM age(p_user.date_of_birth))::integer;
    END IF;

    IF p_user_pref.id IS NOT NULL THEN
        IF p_user_pref.min_age IS NOT NULL AND v_cand_age IS NOT NULL THEN
            IF v_cand_age >= p_user_pref.min_age AND (p_user_pref.max_age IS NULL OR v_cand_age <= p_user_pref.max_age) THEN
                v_forward_score := v_forward_score + 10.0;
            END IF;
        END IF;
        IF p_user_pref.caste_id IS NOT NULL AND p_cand.caste_id = p_user_pref.caste_id THEN
            v_forward_score := v_forward_score + 12.0;
        END IF;
        IF p_user_pref.mother_tongue_id IS NOT NULL AND p_cand.mother_tongue_id = p_user_pref.mother_tongue_id THEN
            v_forward_score := v_forward_score + 8.0;
        END IF;
        IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
            v_forward_score := v_forward_score + 8.0;
        END IF;
    ELSE
        v_forward_score := 65.0;
    END IF;

    IF p_cand_pref.id IS NOT NULL THEN
        IF p_cand_pref.min_age IS NOT NULL AND v_user_age IS NOT NULL THEN
            IF v_user_age >= p_cand_pref.min_age AND (p_cand_pref.max_age IS NULL OR v_user_age <= p_cand_pref.max_age) THEN
                v_reverse_score := v_reverse_score + 10.0;
            END IF;
        END IF;
        IF p_cand_pref.caste_id IS NOT NULL AND p_user.caste_id = p_cand_pref.caste_id THEN
            v_reverse_score := v_reverse_score + 12.0;
        END IF;
        IF p_cand_pref.mother_tongue_id IS NOT NULL AND p_user.mother_tongue_id = p_cand_pref.mother_tongue_id THEN
            v_reverse_score := v_reverse_score + 8.0;
        END IF;
        IF p_cand.state IS NOT NULL AND p_user.state IS NOT NULL AND LOWER(TRIM(p_cand.state)) = LOWER(TRIM(p_user.state)) THEN
            v_reverse_score := v_reverse_score + 8.0;
        END IF;
    ELSE
        v_reverse_score := 65.0;
    END IF;

    v_final_score := (v_forward_score * 0.6) + (v_reverse_score * 0.4);

    IF p_cand.updated_at IS NOT NULL THEN
        v_hours_since_active := EXTRACT(EPOCH FROM (now() - p_cand.updated_at)) / 3600.0;
        IF v_hours_since_active < 1.0 THEN
            v_final_score := v_final_score + 10.0;
        ELSIF v_hours_since_active < 24.0 THEN
            v_final_score := v_final_score + 6.0;
        ELSIF v_hours_since_active < 72.0 THEN
            v_final_score := v_final_score + 2.0;
        ELSIF v_hours_since_active > 336.0 THEN
            v_final_score := v_final_score - 15.0;
        END IF;
    END IF;

    IF COALESCE(p_cand.is_verified, false) THEN
        v_final_score := v_final_score + 3.0;
    END IF;

    IF p_cand.profile_photo_url IS NOT NULL AND TRIM(p_cand.profile_photo_url) <> '' THEN
        v_final_score := v_final_score + 4.0;
    END IF;

    RETURN LEAST(98.0, GREATEST(45.0, v_final_score));
END;
$$;

-- 3. Create the (uuid, uuid) overload used in recent migrations like get_discovery_cohorts
CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user_id uuid,
    p_cand_id uuid
)
RETURNS float8
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user public.profiles;
    v_user_pref public.partner_preferences;
    v_cand public.profiles;
    v_cand_pref public.partner_preferences;
BEGIN
    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    SELECT * INTO v_user_pref FROM public.partner_preferences WHERE profile_id = p_user_id;
    SELECT * INTO v_cand FROM public.profiles WHERE id = p_cand_id;
    SELECT * INTO v_cand_pref FROM public.partner_preferences WHERE profile_id = p_cand_id;

    RETURN public.calculate_reciprocal_compatibility(v_user, v_user_pref, v_cand, v_cand_pref);
END;
$$;
