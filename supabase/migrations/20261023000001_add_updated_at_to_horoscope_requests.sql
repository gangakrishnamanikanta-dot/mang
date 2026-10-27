-- =====================================================================
-- Migration: 20261023000001_add_updated_at_to_horoscope_requests.sql
-- Description: Add missing updated_at column to horoscope_requests required by
--              trg_fulfill_horoscope_requests_on_profile_update trigger.
-- =====================================================================

ALTER TABLE public.horoscope_requests
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
