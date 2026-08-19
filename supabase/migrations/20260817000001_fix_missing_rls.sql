-- ============================================================
-- FIX RLS POLICIES FOR PARTNER_PREFERENCES AND PROFILE_VIEWS
-- ============================================================

-- 1. partner_preferences
ALTER TABLE public.partner_preferences ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own partner preferences (and others if needed, but matched via Security Definer anyway)
-- The existing script already created "public_read_partner_preferences" (SELECT TO anon, authenticated).
-- Let's create INSERT and UPDATE policies.
DROP POLICY IF EXISTS "Users can insert own partner preferences" ON public.partner_preferences;
CREATE POLICY "Users can insert own partner preferences"
  ON public.partner_preferences FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = profile_id);

DROP POLICY IF EXISTS "Users can update own partner preferences" ON public.partner_preferences;
CREATE POLICY "Users can update own partner preferences"
  ON public.partner_preferences FOR UPDATE
  TO authenticated
  USING (auth.uid() = profile_id);

-- 2. profile_views
ALTER TABLE public.profile_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own profile views" ON public.profile_views;
CREATE POLICY "Users can insert own profile views"
  ON public.profile_views FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = viewer_id);

DROP POLICY IF EXISTS "Users can update own profile views" ON public.profile_views;
CREATE POLICY "Users can update own profile views"
  ON public.profile_views FOR UPDATE
  TO authenticated
  USING (auth.uid() = viewer_id);

-- Ensure authenticated users have INSERT/UPDATE privileges on these tables
GRANT INSERT, UPDATE ON public.partner_preferences TO authenticated;
GRANT INSERT, UPDATE ON public.profile_views TO authenticated;
