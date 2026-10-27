-- ── Migration: Sanitize auth.users NULL token columns and add RPC lookup ──────
--
-- 1. Fixes GoTrue scan error:
--    "sql: Scan error on column index 3, name "confirmation_token": converting NULL to string is unsupported"
--    which crashes GoTrue whenever user listing, admin updates, or password changes occur
--    for accounts created by the seed migration.
--
-- 2. Adds public.get_auth_user_id_by_email(text) restricted to service_role
--    for O(1) indexed lookup without scanning auth.users or hitting pagination limits.

-- Step 1: Sanitize existing NULL string token columns in auth.users
UPDATE auth.users
SET 
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  email_change = COALESCE(email_change, '')
WHERE 
  confirmation_token IS NULL 
  OR recovery_token IS NULL 
  OR email_change_token_new IS NULL 
  OR email_change IS NULL;

-- Step 2: Create targeted O(1) RPC lookup function restricted to service_role
CREATE OR REPLACE FUNCTION public.get_auth_user_id_by_email(p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  SELECT id INTO v_uid
  FROM auth.users
  WHERE lower(email) = lower(trim(p_email))
  LIMIT 1;
  RETURN v_uid;
END;
$$;

-- Secure the RPC: Only the backend service_role (Edge Functions) can invoke it
REVOKE EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) TO service_role;
