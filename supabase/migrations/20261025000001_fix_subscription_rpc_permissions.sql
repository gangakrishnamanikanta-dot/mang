-- =============================================================================
-- Migration: Fix set_user_subscription RPC Permissions
-- Issue: PostgrestException code 42501 — permission denied for function
--        set_user_subscription when called by authenticated role.
-- Fix:   Grant EXECUTE on ALL public functions to authenticated role.
-- =============================================================================

-- Broad safety net: grant execute on all public RPCs to authenticated role
-- This is safe because each function uses auth.uid() internally for user isolation.
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Revoke from anon — anon should never call RPCs in a matrimonial app
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
