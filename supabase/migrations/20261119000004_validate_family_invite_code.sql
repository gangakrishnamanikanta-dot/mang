-- Migration: 20261119000004_validate_family_invite_code.sql
-- Description: Unauthenticated pre-validation for family invite codes prior to OTP dispatch

CREATE OR REPLACE FUNCTION public.validate_family_invite_code(p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_circle record;
  v_guardian_count int;
  v_candidate_name text;
BEGIN
  IF p_invite_code IS NULL OR TRIM(p_invite_code) = '' THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Please enter a family invite code.');
  END IF;

  SELECT * INTO v_circle
  FROM public.family_circles
  WHERE UPPER(invite_code) = UPPER(TRIM(p_invite_code));

  IF v_circle.id IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Invalid family invite code. Please verify with the candidate.');
  END IF;

  SELECT count(*) INTO v_guardian_count
  FROM public.family_members
  WHERE family_circle_id = v_circle.id
    AND role <> 'Candidate';

  IF v_guardian_count >= 2 THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'This candidate profile already has the maximum of 2 connected guardian accounts.'
    );
  END IF;

  SELECT full_name INTO v_candidate_name
  FROM public.profiles
  WHERE id = v_circle.candidate_id;

  RETURN jsonb_build_object(
    'valid', true,
    'candidate_name', COALESCE(v_candidate_name, 'the candidate'),
    'family_name', v_circle.family_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_family_invite_code(text) TO anon, authenticated, service_role;
