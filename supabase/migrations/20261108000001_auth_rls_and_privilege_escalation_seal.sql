-- =============================================================================
-- Migration: 20261108000001_auth_rls_and_privilege_escalation_seal.sql
-- Description: Step 1 Security Hardening - Privilege Escalation Seal & RLS Lockdown
--   1. Enforce strict tamper-proof protection on sensitive profile columns:
--      is_admin, is_suspended, suspended_at, suspension_reason, is_verified, and id.
--   2. Revoke public & authenticated execution of get_auth_user_id_by_email to eliminate
--      account enumeration oracle.
--   3. Explicitly revoke table privileges on otps and otp_rate_limits for non-service roles.
-- =============================================================================

-- 1. Security Enforcement Trigger for public.profiles
CREATE OR REPLACE FUNCTION public.enforce_profile_security_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := COALESCE(auth.role(), '');
  v_uid uuid := auth.uid();
  v_is_service_role boolean := (auth.jwt() ->> 'role') = 'service_role' OR v_role = 'service_role';
  v_is_admin boolean := false;
BEGIN
  -- Service role has full administrative authority
  IF v_is_service_role THEN
    RETURN NEW;
  END IF;

  -- Check if caller is an existing confirmed administrator
  IF v_uid IS NOT NULL THEN
    SELECT COALESCE(is_admin, false) INTO v_is_admin
    FROM public.profiles
    WHERE id = v_uid;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Non-admin callers cannot create an admin, suspended, or verified profile directly
    IF NOT v_is_admin THEN
      NEW.is_admin := false;
      NEW.is_suspended := false;
      NEW.suspended_at := NULL;
      NEW.suspension_reason := NULL;
      NEW.is_verified := false;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- If caller is a confirmed administrator, allow all modifications
    IF v_is_admin THEN
      RETURN NEW;
    END IF;

    -- Block suspended users from updating their profile
    IF OLD.is_suspended = true THEN
      RAISE EXCEPTION 'Access denied: account is suspended'
        USING ERRCODE = '42501';
    END IF;

    -- Block non-admin callers from tampering with administrative/security fields
    IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
      RAISE EXCEPTION 'Access denied: Cannot alter administrative privileges (is_admin)'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.is_suspended IS DISTINCT FROM OLD.is_suspended THEN
      RAISE EXCEPTION 'Access denied: Cannot alter account suspension state (is_suspended)'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.suspended_at IS DISTINCT FROM OLD.suspended_at THEN
      RAISE EXCEPTION 'Access denied: Cannot alter account suspension timestamp (suspended_at)'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.suspension_reason IS DISTINCT FROM OLD.suspension_reason THEN
      RAISE EXCEPTION 'Access denied: Cannot alter account suspension reason'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
      RAISE EXCEPTION 'Access denied: Cannot alter account verification status (is_verified)'
        USING ERRCODE = '42501';
    END IF;

    -- Prevent modifying user primary key ID
    IF NEW.id IS DISTINCT FROM OLD.id THEN
      RAISE EXCEPTION 'Access denied: Cannot alter account ID'
        USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_enforce_profile_security_fields'
  ) THEN
    CREATE TRIGGER trg_enforce_profile_security_fields
      BEFORE INSERT OR UPDATE ON public.profiles
      FOR EACH ROW
      EXECUTE FUNCTION public.enforce_profile_security_fields();
  END IF;
END $$;

-- 2. Revoke get_auth_user_id_by_email from authenticated and anon callers (Anti-Enumeration)
REVOKE EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) TO postgres;

-- 3. Explicit Table-Level Privilege Lockdown on otps and otp_rate_limits
REVOKE ALL ON TABLE public.otps FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.otps TO service_role;
GRANT ALL ON TABLE public.otps TO postgres;

REVOKE ALL ON TABLE public.otp_rate_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.otp_rate_limits TO service_role;
GRANT ALL ON TABLE public.otp_rate_limits TO postgres;
