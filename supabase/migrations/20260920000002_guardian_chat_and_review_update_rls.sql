-- ============================================================================
-- Migration: Guardian Chat and Family Room Review Update RLS
-- Date: 2026-09-20
-- Description:
--   1. Adds UPDATE policy to family_profile_reviews so family members can cast votes
--   2. Updates messages INSERT policy to allow verified guardians to message on behalf
--      of their candidate if the candidate has an accepted interest or contact unlock
--   3. Updates messages SELECT policy so family guardians and candidates can read
--      messages sent on behalf of their candidate
-- ============================================================================

-- 1. Family Profile Reviews UPDATE Policy
DROP POLICY IF EXISTS "Circle members can update reviews" ON public.family_profile_reviews;
CREATE POLICY "Circle members can update reviews"
    ON public.family_profile_reviews FOR UPDATE
    TO authenticated
    USING (
        is_family_circle_member(family_circle_id, auth.uid())
    )
    WITH CHECK (
        is_family_circle_member(family_circle_id, auth.uid())
    );

-- 2. Enhanced Messages INSERT Policy (Supporting Delegated Guardian Messaging)
DROP POLICY IF EXISTS "Users can insert their own messages with accepted interest" ON public.messages;
CREATE POLICY "Users can insert their own messages with accepted interest"
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
            -- 3. Guardian chatting on behalf of their candidate who has an accepted interest or unlock
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

-- 3. Enhanced Messages SELECT Policy
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations"
    ON public.messages FOR SELECT
    TO authenticated
    USING (
        auth.uid() = sender_id 
        OR auth.uid() = receiver_id
        OR (on_behalf_of IS NOT NULL AND on_behalf_of = auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.family_members fm
            JOIN public.family_circles fc ON fm.family_circle_id = fc.id
            WHERE fm.user_id = auth.uid()
              AND (fc.candidate_id = sender_id OR fc.candidate_id = receiver_id OR fc.candidate_id = on_behalf_of)
        )
    );
