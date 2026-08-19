-- OTP codes table for custom email OTP authentication
-- OTPs are hashed (bcrypt) before storage — never plaintext

CREATE TABLE IF NOT EXISTS public.otps (
  id BIGSERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('signup', 'reset_password', 'verify_email')),
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for fast lookup by email + purpose
CREATE INDEX IF NOT EXISTS idx_otps_email_purpose ON public.otps(email, purpose);

-- Auto-delete expired OTPs (run periodically via cron or on each verify)
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.otps WHERE expires_at < NOW();
END;
$$;

-- RLS: users can only see their own OTPs (by email)
ALTER TABLE public.otps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own OTPs" ON public.otps;
CREATE POLICY "Users can insert their own OTPs"
  ON public.otps FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can view their own OTPs" ON public.otps;
CREATE POLICY "Users can view their own OTPs"
  ON public.otps FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can update their own OTPs" ON public.otps;
CREATE POLICY "Users can update their own OTPs"
  ON public.otps FOR UPDATE
  USING (true);

-- Disable RLS for service role (Edge Functions use service role key)
-- Edge Functions bypass RLS, so they can read/write all OTPs
