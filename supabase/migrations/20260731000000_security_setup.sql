-- ============================================================
-- PART 1: RATE LIMITING TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.otp_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,          -- email or IP address
  identifier_type TEXT NOT NULL,     -- 'email' or 'ip'
  attempts INT NOT NULL DEFAULT 1,
  first_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  blocked_until TIMESTAMPTZ         -- non-null = currently blocked
);

CREATE INDEX IF NOT EXISTS idx_otp_rate_limits_lookup
  ON public.otp_rate_limits (identifier, identifier_type);

-- Auto-cleanup old entries (older than 24 hours) on every insert
CREATE OR REPLACE FUNCTION public.cleanup_otp_rate_limits()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.otp_rate_limits
  WHERE last_attempt_at < now() - interval '24 hours';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cleanup_otp_rate_limits ON public.otp_rate_limits;
CREATE TRIGGER trg_cleanup_otp_rate_limits
  BEFORE INSERT ON public.otp_rate_limits
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_otp_rate_limits();

-- ============================================================
-- PART 2: RLS ON PROFILES TABLE
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can view their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users can insert their own profile (used by handle_new_user trigger)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Users can delete their own profile
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
CREATE POLICY "Users can delete own profile"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- ============================================================
-- PART 3: RLS ON OTP_RATE_LIMITS TABLE (service role only)
-- ============================================================

ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;

-- Only service_role can read/write rate limits (Edge Functions use service_role)
DROP POLICY IF EXISTS "Service role manages rate limits" ON public.otp_rate_limits;
CREATE POLICY "Service role manages rate limits"
  ON public.otp_rate_limits FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Deny anon access
DROP POLICY IF EXISTS "Deny anon access to rate limits" ON public.otp_rate_limits;
CREATE POLICY "Deny anon access to rate limits"
  ON public.otp_rate_limits FOR ALL
  TO anon
  USING (false);

-- ============================================================
-- PART 4: RLS ON ALL LOOKUP TABLES (public read, no write)
-- ============================================================

DO $block$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename NOT IN ('profiles', 'otp_rate_limits')
      AND tablename NOT LIKE 'pg_%'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);
    EXECUTE format($$
      DROP POLICY IF EXISTS "public_read_%I" ON public.%I;
      CREATE POLICY "public_read_%I"
        ON public.%I FOR SELECT
        TO anon, authenticated
        USING (true);
    $$, tbl, tbl, tbl, tbl);
  END LOOP;
END $block$;

-- ============================================================
-- PART 5: VERIFY handle_new_user TRIGGER EXISTS
-- ============================================================

-- Check if trigger exists, create if missing
DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'on_auth_user_created'
      AND tgrelid = 'auth.users'::regclass
  ) THEN
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER AS $inner$
    BEGIN
      INSERT INTO public.profiles (id, email, phone, full_name, profile_completed)
      VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.phone, ''),
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        false
      );
      RETURN NEW;
    END;
    $inner$ LANGUAGE plpgsql SECURITY DEFINER;

    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
  END IF;
END $block$;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON public.otp_rate_limits TO service_role;
GRANT ALL ON public.profiles TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
