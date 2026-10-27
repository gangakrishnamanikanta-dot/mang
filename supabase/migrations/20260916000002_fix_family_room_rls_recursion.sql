-- ── Migration: 20260916000002_fix_family_room_rls_recursion.sql ────────────────
-- Fix: Prevent PostgreSQL 42P17 infinite recursion in family_members & family_circles RLS
-- Uses SECURITY DEFINER helper function to safely evaluate membership without self-referential RLS loop.

CREATE OR REPLACE FUNCTION public.is_family_circle_member(p_circle_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO 'public'
AS $$
    SELECT (
        EXISTS (
            SELECT 1 FROM public.family_circles
            WHERE id = p_circle_id AND candidate_id = p_user_id
        )
        OR EXISTS (
            SELECT 1 FROM public.family_members 
            WHERE family_circle_id = p_circle_id AND user_id = p_user_id
        )
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_family_circle_member(uuid, uuid) TO authenticated;

-- 1. family_circles SELECT policy
DROP POLICY IF EXISTS "Members can view their family circle" ON public.family_circles;
CREATE POLICY "Members can view their family circle"
    ON public.family_circles FOR SELECT
    TO authenticated
    USING (
        candidate_id = auth.uid() OR public.is_family_circle_member(id, auth.uid())
    );

-- 2. family_members SELECT policy
DROP POLICY IF EXISTS "Members can view circle members" ON public.family_members;
CREATE POLICY "Members can view circle members"
    ON public.family_members FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid() OR public.is_family_circle_member(family_circle_id, auth.uid())
    );

-- 3. family_profile_reviews SELECT policy
DROP POLICY IF EXISTS "Circle members can view reviews" ON public.family_profile_reviews;
CREATE POLICY "Circle members can view reviews"
    ON public.family_profile_reviews FOR SELECT
    TO authenticated
    USING (
        public.is_family_circle_member(family_circle_id, auth.uid())
    );

-- 4. family_profile_reviews INSERT policy
DROP POLICY IF EXISTS "Circle members can insert reviews" ON public.family_profile_reviews;
CREATE POLICY "Circle members can insert reviews"
    ON public.family_profile_reviews FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = reviewed_by AND public.is_family_circle_member(family_circle_id, auth.uid())
    );
