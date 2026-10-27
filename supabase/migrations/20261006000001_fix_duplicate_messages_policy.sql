-- ============================================================================
-- Migration: 20261006000001_fix_duplicate_messages_policy.sql
-- Purpose:   Remove duplicate messages INSERT policy.
--            The older policy "Users can insert their own messages with accepted
--            interest" is a strict subset of the newer comprehensive policy
--            "Users can insert their own messages with accepted interest or contact unlock"
--            which also covers guardian proxy chat.
-- ============================================================================

-- Drop the older, narrower policy (superseded)
DROP POLICY IF EXISTS "Users can insert their own messages with accepted interest"
  ON public.messages;

-- Verify only one INSERT policy remains (create comprehensive if none left)
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM pg_policies
  WHERE tablename = 'messages'
    AND schemaname = 'public'
    AND cmd = 'INSERT';

  IF v_count = 0 THEN
    CREATE POLICY "Users can insert their own messages with accepted interest or contact unlock"
      ON public.messages FOR INSERT
      TO authenticated
      WITH CHECK (
          auth.uid() = sender_id
          AND (
              -- 1. Direct candidate message with accepted interest
              EXISTS (
                  SELECT 1 FROM public.interests i
                  WHERE (
                      (i.sender_profile_id = auth.uid() AND i.receiver_profile_id = receiver_id)
                      OR
                      (i.sender_profile_id = receiver_id AND i.receiver_profile_id = auth.uid())
                  )
                  AND i.status = 'accepted'
              )
              -- 2. Direct contact unlock
              OR EXISTS (
                  SELECT 1 FROM public.contact_unlocks cu
                  WHERE (
                      (cu.user_id = auth.uid() AND cu.target_profile_id = receiver_id)
                      OR (cu.user_id = receiver_id AND cu.target_profile_id = auth.uid())
                  )
              )
              -- 3. Guardian chatting on behalf of their candidate
              OR (
                  on_behalf_of IS NOT NULL
                  AND EXISTS (
                      SELECT 1 FROM public.family_members fm
                      JOIN public.family_circles fc ON fm.family_circle_id = fc.id
                      WHERE fm.user_id = auth.uid()
                        AND fc.candidate_id = on_behalf_of
                        AND fm.role <> 'Candidate'
                  )
                  AND (
                      EXISTS (
                          SELECT 1 FROM public.interests i
                          WHERE (
                              (i.sender_profile_id = on_behalf_of AND i.receiver_profile_id = receiver_id)
                              OR
                              (i.sender_profile_id = receiver_id AND i.receiver_profile_id = on_behalf_of)
                          )
                          AND i.status = 'accepted'
                      )
                      OR EXISTS (
                          SELECT 1 FROM public.contact_unlocks cu
                          WHERE (
                              (cu.user_id = on_behalf_of AND cu.target_profile_id = receiver_id)
                              OR (cu.user_id = receiver_id AND cu.target_profile_id = on_behalf_of)
                          )
                      )
                  )
              )
          )
      );
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM pg_policies
  WHERE tablename = 'messages'
    AND schemaname = 'public'
    AND cmd = 'INSERT';

  IF v_count != 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 INSERT policy on messages, found %', v_count;
  END IF;

  RAISE NOTICE 'OK: messages table has exactly 1 INSERT policy.';
END $$;
