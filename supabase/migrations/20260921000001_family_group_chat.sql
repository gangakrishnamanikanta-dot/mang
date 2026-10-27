-- =====================================================================
-- Family Group Chat: WhatsApp-Style Real-Time Group Messages
-- 1 candidate = 1 immutable permanent family room (enforced by UNIQUE)
-- Guardians enter ONLY via candidate invite code
-- =====================================================================

-- 1. UNIQUE constraint: 1 candidate = exactly 1 permanent family room
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'family_circles_candidate_id_unique'
  ) THEN
    ALTER TABLE public.family_circles
    ADD CONSTRAINT family_circles_candidate_id_unique UNIQUE (candidate_id);
  END IF;
END;
$$;

-- 2. Create family_messages table
CREATE TABLE IF NOT EXISTS public.family_messages (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_circle_id  uuid        NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
  sender_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_name       text        NOT NULL DEFAULT 'Member',
  sender_role       text        NOT NULL DEFAULT 'Member',
  message_type      text        NOT NULL DEFAULT 'text'
                                CHECK (message_type IN ('text', 'shared_profile', 'audio', 'system')),
  content           text,
  media_url         text,
  shared_profile_id uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_family_messages_circle_created
  ON public.family_messages (family_circle_id, created_at DESC);

ALTER TABLE public.family_messages ENABLE ROW LEVEL SECURITY;

-- 3. Helper: is_family_circle_member
CREATE OR REPLACE FUNCTION public.is_family_circle_member(p_circle_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $func$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.family_members
    WHERE family_circle_id = p_circle_id AND user_id = p_user_id
  );
END;
$func$;
GRANT EXECUTE ON FUNCTION public.is_family_circle_member(uuid, uuid) TO authenticated;

-- 4. RLS Policies
DROP POLICY IF EXISTS "Family members can read their group messages" ON public.family_messages;
CREATE POLICY "Family members can read their group messages"
  ON public.family_messages FOR SELECT TO authenticated
  USING (public.is_family_circle_member(family_circle_id, auth.uid()));

DROP POLICY IF EXISTS "Family members can send messages" ON public.family_messages;
CREATE POLICY "Family members can send messages"
  ON public.family_messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id AND public.is_family_circle_member(family_circle_id, auth.uid()));

DROP POLICY IF EXISTS "Sender can delete own message" ON public.family_messages;
CREATE POLICY "Sender can delete own message"
  ON public.family_messages FOR DELETE TO authenticated
  USING (auth.uid() = sender_id);

-- 5. Realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'family_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.family_messages;
  END IF;
END;
$$;

-- 6. RPC: send_family_message
CREATE OR REPLACE FUNCTION public.send_family_message(
  p_circle_id         uuid,
  p_content           text    DEFAULT NULL,
  p_message_type      text    DEFAULT 'text',
  p_media_url         text    DEFAULT NULL,
  p_shared_profile_id uuid    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $func$
DECLARE
  v_user_id uuid;
  v_member  record;
  v_msg_id  uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Authentication required');
  END IF;

  SELECT role, display_name INTO v_member
  FROM public.family_members
  WHERE family_circle_id = p_circle_id AND user_id = v_user_id;

  IF v_member.role IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Not a member of this family room');
  END IF;

  INSERT INTO public.family_messages
    (family_circle_id, sender_id, sender_name, sender_role, message_type, content, media_url, shared_profile_id)
  VALUES
    (p_circle_id, v_user_id,
     COALESCE(v_member.display_name, v_member.role), v_member.role,
     p_message_type, NULLIF(TRIM(p_content), ''), p_media_url, p_shared_profile_id)
  RETURNING id INTO v_msg_id;

  RETURN jsonb_build_object('status', 'success', 'message_id', v_msg_id);
END;
$func$;
GRANT EXECUTE ON FUNCTION public.send_family_message(uuid, text, text, text, uuid) TO authenticated;

-- 7. RPC: get_family_messages (paginated, ascending order)
CREATE OR REPLACE FUNCTION public.get_family_messages(
  p_circle_id uuid,
  p_limit     int         DEFAULT 50,
  p_before    timestamptz DEFAULT NULL
)
RETURNS TABLE (
  id                   uuid,
  sender_id            uuid,
  sender_name          text,
  sender_role          text,
  message_type         text,
  content              text,
  media_url            text,
  shared_profile_id    uuid,
  shared_profile_name  text,
  shared_profile_photo text,
  created_at           timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $func$
BEGIN
  IF NOT public.is_family_circle_member(p_circle_id, auth.uid()) THEN
    RAISE EXCEPTION 'Access denied: not a member of this family room';
  END IF;

  RETURN QUERY
  SELECT
    fm.id, fm.sender_id, fm.sender_name, fm.sender_role, fm.message_type,
    fm.content, fm.media_url, fm.shared_profile_id,
    p.full_name         AS shared_profile_name,
    p.profile_photo_url AS shared_profile_photo,
    fm.created_at
  FROM public.family_messages fm
  LEFT JOIN public.profiles p ON p.id = fm.shared_profile_id
  WHERE fm.family_circle_id = p_circle_id
    AND (p_before IS NULL OR fm.created_at < p_before)
  ORDER BY fm.created_at ASC
  LIMIT p_limit;
END;
$func$;
GRANT EXECUTE ON FUNCTION public.get_family_messages(uuid, int, timestamptz) TO authenticated;

-- 8. Enhanced get_or_create_family_circle (returns full member list)
CREATE OR REPLACE FUNCTION public.get_or_create_family_circle()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $func$
DECLARE
  v_user_id  uuid;
  v_profile  record;
  v_circle   record;
  v_invite   text;
  v_members  jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id LIMIT 1;

  IF v_profile.account_type = 'guardian' THEN
    -- Guardian: get their candidate's circle
    SELECT fc.* INTO v_circle
    FROM public.family_members fm
    JOIN public.family_circles fc ON fc.id = fm.family_circle_id
    WHERE fm.user_id = v_user_id AND fm.role <> 'Candidate'
    LIMIT 1;
  ELSE
    -- Candidate: get or create their one permanent circle
    SELECT * INTO v_circle FROM public.family_circles WHERE candidate_id = v_user_id LIMIT 1;

    IF v_circle.id IS NULL THEN
      LOOP
        v_invite := 'MANG-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::text, 4, '0');
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.family_circles WHERE invite_code = v_invite);
      END LOOP;

      INSERT INTO public.family_circles (candidate_id, family_name, invite_code)
      VALUES (v_user_id, COALESCE(v_profile.full_name || ' Family', 'Sacred Family Room'), v_invite)
      RETURNING * INTO v_circle;

      INSERT INTO public.family_members (family_circle_id, user_id, role, display_name)
      VALUES (v_circle.id, v_user_id, 'Candidate', COALESCE(v_profile.full_name, 'Candidate'))
      ON CONFLICT (family_circle_id, user_id) DO NOTHING;
    END IF;
  END IF;

  IF v_circle.id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'No family circle found');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'user_id',      fm.user_id,
      'role',         fm.role,
      'display_name', fm.display_name,
      'joined_at',    fm.created_at
    ) ORDER BY fm.created_at ASC
  ) INTO v_members
  FROM public.family_members fm
  WHERE fm.family_circle_id = v_circle.id;

  RETURN jsonb_build_object(
    'status',       'success',
    'circle_id',    v_circle.id,
    'family_name',  v_circle.family_name,
    'invite_code',  v_circle.invite_code,
    'candidate_id', v_circle.candidate_id,
    'member_count', COALESCE(jsonb_array_length(v_members), 0),
    'members',      COALESCE(v_members, '[]'::jsonb)
  );
END;
$func$;
GRANT EXECUTE ON FUNCTION public.get_or_create_family_circle() TO authenticated;
