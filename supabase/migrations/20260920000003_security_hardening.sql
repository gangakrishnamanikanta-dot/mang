-- Security Hardening: Function Search Path Immutability & API RPC Role Hardening

DO $$
DECLARE
    f record;
    v_sql text;
BEGIN
    -- 1. Search path immutability for SECURITY DEFINER / PLPGSQL functions (if they exist)
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_family_guardian_limit') THEN
        ALTER FUNCTION public.check_family_guardian_limit() SET search_path = public, pg_temp;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'calculate_guna_milan_points') THEN
        ALTER FUNCTION public.calculate_guna_milan_points(integer, integer, integer, integer, integer, integer) SET search_path = public, pg_temp;
    END IF;

    -- 2. Revoke execute on trigger functions (triggers run internally, never via direct REST RPC)
    FOR f IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
          AND p.proname IN (
              'check_family_guardian_limit',
              'handle_new_user',
              'handle_new_message',
              'trg_exclude_on_interest_decline',
              'trg_fulfill_horoscope_requests_on_profile_update',
              'trg_pp_refresh_matches_fn',
              'trg_profiles_refresh_matches_fn',
              'trigger_refresh_cache_on_preference_change'
          )
    LOOP
        v_sql := format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated;', f.proname, f.args);
        EXECUTE v_sql;
    END LOOP;

    -- 3. Revoke execute on admin / internal functions from anon
    FOR f IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
          AND p.proname IN (
              'admin_delete_user',
              'admin_toggle_admin',
              'admin_toggle_verify',
              'cleanup_expired_otps',
              'set_user_subscription',
              'get_admin_stats',
              'get_admin_users'
          )
    LOOP
        v_sql := format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM anon;', f.proname, f.args);
        EXECUTE v_sql;
    END LOOP;

    -- 4. Revoke execute on authenticated user operations from anonymous role
    FOR f IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
          AND p.proname IN (
              'join_family_circle',
              'get_or_create_family_circle',
              'get_guardian_active_candidate',
              'block_user',
              'unblock_user',
              'delete_user_account',
              'unlock_contact_number',
              'report_user',
              'send_interest_with_quota',
              'respond_to_interest',
              'toggle_shortlist',
              'get_or_create_conversation',
              'get_candidates',
              'get_top_matches_v2',
              'get_discovery_cohorts',
              'get_recently_active_profiles',
              'get_visited_profiles_with_score',
              'get_user_membership_status',
              'get_user_public_key',
              'set_user_public_key',
              'search_discovery_profiles',
              'refresh_user_match_cache',
              'record_profile_view_capped',
              'record_matches_shown',
              'get_incoming_horoscope_requests',
              'get_blocked_users',
              'get_behavioral_signals',
              'get_candidate_behavioral_score',
              'get_compatibility_index_v2',
              'get_one_way_score',
              'calculate_reciprocal_compatibility',
              'calculate_mutual_compatibility',
              'calculate_one_way_score',
              'send_refresh_notify',
              'is_family_circle_member',
              'ist_today'
          )
    LOOP
        v_sql := format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM anon;', f.proname, f.args);
        EXECUTE v_sql;
    END LOOP;
END $$;
