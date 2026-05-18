-- 20260518000008_avatar_url_storage.sql
-- Adds custom avatar upload via Supabase Storage.
--   * profiles gains avatar_url (object path) + avatar_updated_at (cache-bust)
--   * public avatars bucket with owner-only-write RLS
--   * four user-surface RPCs return the new columns

-- ---------- schema ----------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS avatar_url        text,
    ADD COLUMN IF NOT EXISTS avatar_updated_at timestamptz;

-- ---------- storage bucket ----------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 262144, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
    SET public             = EXCLUDED.public,
        file_size_limit    = EXCLUDED.file_size_limit,
        allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "avatars public read"  ON storage.objects;
DROP POLICY IF EXISTS "avatars owner write"  ON storage.objects;
DROP POLICY IF EXISTS "avatars owner update" ON storage.objects;
DROP POLICY IF EXISTS "avatars owner delete" ON storage.objects;

CREATE POLICY "avatars public read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "avatars owner write"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "avatars owner update"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "avatars owner delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- get_public_profile  (was: id, username, avatar_emoji, weekly_xp, tier)
-- Adds: avatar_url, avatar_updated_at
-- ============================================================
-- RETURNS TABLE shape changes, so we must DROP first — Postgres rejects
-- CREATE OR REPLACE FUNCTION when the OUT-parameter row type changes.
-- Drop public wrapper before private body (wrapper depends on body).

DROP FUNCTION IF EXISTS public.get_public_profile(uuid);
DROP FUNCTION IF EXISTS private.get_public_profile(uuid);

CREATE OR REPLACE FUNCTION private.get_public_profile(target_id uuid)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    avatar_url text,
    avatar_updated_at timestamptz,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        p.id,
        p.username,
        p.avatar_emoji,
        p.avatar_url,
        p.avatar_updated_at,
        COALESCE(s.weekly_xp, 0) AS weekly_xp,
        CASE
            WHEN COALESCE(s.weekly_xp, 0) >= 6000 THEN 'diamond'
            WHEN COALESCE(s.weekly_xp, 0) >= 3000 THEN 'platinum'
            WHEN COALESCE(s.weekly_xp, 0) >= 1500 THEN 'gold'
            WHEN COALESCE(s.weekly_xp, 0) >= 600  THEN 'silver'
            ELSE 'bronze'
        END AS tier
    FROM profiles p
    LEFT JOIN user_stats s ON s.user_id = p.id
    WHERE p.id = target_id;
$$;

REVOKE ALL ON FUNCTION private.get_public_profile(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.get_public_profile(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profile(target_id uuid)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    avatar_url text,
    avatar_updated_at timestamptz,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
AS $$
    SELECT * FROM private.get_public_profile(target_id);
$$;

REVOKE ALL ON FUNCTION public.get_public_profile(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid) TO authenticated;

-- ============================================================
-- search_public_profiles  (was: id, username, avatar_emoji, weekly_xp, tier)
-- Adds: avatar_url, avatar_updated_at
-- Filter preserved verbatim (ILIKE '%' || q || '%' AND p.id <> auth.uid())
-- ============================================================

DROP FUNCTION IF EXISTS public.search_public_profiles(text);
DROP FUNCTION IF EXISTS private.search_public_profiles(text);

CREATE OR REPLACE FUNCTION private.search_public_profiles(q text)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    avatar_url text,
    avatar_updated_at timestamptz,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        p.id,
        p.username,
        p.avatar_emoji,
        p.avatar_url,
        p.avatar_updated_at,
        COALESCE(s.weekly_xp, 0),
        CASE
            WHEN COALESCE(s.weekly_xp, 0) >= 6000 THEN 'diamond'
            WHEN COALESCE(s.weekly_xp, 0) >= 3000 THEN 'platinum'
            WHEN COALESCE(s.weekly_xp, 0) >= 1500 THEN 'gold'
            WHEN COALESCE(s.weekly_xp, 0) >= 600  THEN 'silver'
            ELSE 'bronze'
        END
    FROM profiles p
    LEFT JOIN user_stats s ON s.user_id = p.id
    WHERE p.username ILIKE '%' || q || '%' AND p.id <> auth.uid()
    LIMIT 20;
$$;

REVOKE ALL ON FUNCTION private.search_public_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.search_public_profiles(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.search_public_profiles(q text)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    avatar_url text,
    avatar_updated_at timestamptz,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
AS $$
    SELECT * FROM private.search_public_profiles(q);
$$;

REVOKE ALL ON FUNCTION public.search_public_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(text) TO authenticated;

-- ============================================================
-- get_global_leaderboard  (jsonb return; preserve ROW_NUMBER tiebreak)
-- Adds avatar_url, avatar_updated_at to BOTH CTEs and BOTH jsonb_build_object payloads
-- ============================================================

CREATE OR REPLACE FUNCTION private.get_global_leaderboard(limit_n int DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    top_rows jsonb;
    me_row   jsonb;
    caller   uuid := auth.uid();
BEGIN
    WITH ranked AS (
        SELECT
            p.id,
            p.username,
            p.avatar_emoji,
            p.avatar_url,
            p.avatar_updated_at,
            COALESCE(s.weekly_xp, 0) AS weekly_xp,
            ROW_NUMBER() OVER (
                ORDER BY COALESCE(s.weekly_xp, 0) DESC, p.id ASC
            ) AS rank
        FROM profiles p
        LEFT JOIN user_stats s ON s.user_id = p.id
    )
    SELECT jsonb_agg(jsonb_build_object(
        'id', id,
        'username', username,
        'avatar_emoji', avatar_emoji,
        'avatar_url', avatar_url,
        'avatar_updated_at', avatar_updated_at,
        'weekly_xp', weekly_xp,
        'rank', rank,
        'tier',
            CASE
                WHEN weekly_xp >= 6000 THEN 'diamond'
                WHEN weekly_xp >= 3000 THEN 'platinum'
                WHEN weekly_xp >= 1500 THEN 'gold'
                WHEN weekly_xp >= 600  THEN 'silver'
                ELSE 'bronze'
            END
    ) ORDER BY rank)
    INTO top_rows
    FROM ranked
    WHERE rank <= limit_n;

    WITH ranked AS (
        SELECT
            p.id,
            p.username,
            p.avatar_emoji,
            p.avatar_url,
            p.avatar_updated_at,
            COALESCE(s.weekly_xp, 0) AS weekly_xp,
            ROW_NUMBER() OVER (
                ORDER BY COALESCE(s.weekly_xp, 0) DESC, p.id ASC
            ) AS rank
        FROM profiles p
        LEFT JOIN user_stats s ON s.user_id = p.id
    )
    SELECT jsonb_build_object(
        'id', id,
        'username', username,
        'avatar_emoji', avatar_emoji,
        'avatar_url', avatar_url,
        'avatar_updated_at', avatar_updated_at,
        'weekly_xp', weekly_xp,
        'rank', rank,
        'tier',
            CASE
                WHEN weekly_xp >= 6000 THEN 'diamond'
                WHEN weekly_xp >= 3000 THEN 'platinum'
                WHEN weekly_xp >= 1500 THEN 'gold'
                WHEN weekly_xp >= 600  THEN 'silver'
                ELSE 'bronze'
            END
    )
    INTO me_row
    FROM ranked
    WHERE id = caller;

    RETURN jsonb_build_object('top', COALESCE(top_rows, '[]'::jsonb), 'me', me_row);
END;
$$;

REVOKE ALL ON FUNCTION private.get_global_leaderboard(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.get_global_leaderboard(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_global_leaderboard(limit_n int DEFAULT 10)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT private.get_global_leaderboard(limit_n);
$$;

REVOKE ALL ON FUNCTION public.get_global_leaderboard(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_global_leaderboard(int) TO authenticated;

-- ============================================================
-- get_friend_activity  (union of score_events + pb_events joined to profiles)
-- Adds: actor_avatar_url, actor_avatar_updated_at
-- Body structure (score_events / pb_events / combined / final SELECT) preserved verbatim.
-- ============================================================

DROP FUNCTION IF EXISTS public.get_friend_activity(int);
DROP FUNCTION IF EXISTS private.get_friend_activity(int);

CREATE OR REPLACE FUNCTION private.get_friend_activity(limit_n int DEFAULT 10)
RETURNS TABLE (
    actor_id uuid,
    actor_username text,
    actor_display_name text,
    actor_avatar_emoji text,
    actor_avatar_url text,
    actor_avatar_updated_at timestamptz,
    event_type text,
    event_at timestamptz,
    payload jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH friend_ids AS (
        SELECT user_id_2 AS id FROM friendships WHERE user_id_1 = auth.uid()
    ),
    score_events AS (
        SELECT
            ss.user_id AS actor_id,
            'score'::text AS event_type,
            ss.created_at AS event_at,
            jsonb_build_object('score', ss.score, 'mode', ss.mode) AS payload
        FROM session_scores ss
        WHERE ss.user_id IN (SELECT id FROM friend_ids)
    ),
    pb_events AS (
        SELECT
            pb.user_id AS actor_id,
            'personal_best'::text AS event_type,
            pb.achieved_at AS event_at,
            jsonb_build_object('mode', pb.mode, 'score', pb.best_score) AS payload
        FROM personal_bests pb
        WHERE pb.user_id IN (SELECT id FROM friend_ids)
    ),
    combined AS (
        SELECT * FROM score_events
        UNION ALL
        SELECT * FROM pb_events
    )
    SELECT
        c.actor_id,
        p.username,
        p.display_name,
        p.avatar_emoji,
        p.avatar_url,
        p.avatar_updated_at,
        c.event_type,
        c.event_at,
        c.payload
    FROM combined c
    JOIN profiles p ON p.id = c.actor_id
    ORDER BY c.event_at DESC
    LIMIT limit_n;
$$;

REVOKE ALL ON FUNCTION private.get_friend_activity(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.get_friend_activity(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_friend_activity(limit_n int DEFAULT 10)
RETURNS TABLE (
    actor_id uuid,
    actor_username text,
    actor_display_name text,
    actor_avatar_emoji text,
    actor_avatar_url text,
    actor_avatar_updated_at timestamptz,
    event_type text,
    event_at timestamptz,
    payload jsonb
)
LANGUAGE sql
STABLE
AS $$
    SELECT * FROM private.get_friend_activity(limit_n);
$$;

REVOKE ALL ON FUNCTION public.get_friend_activity(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_friend_activity(int) TO authenticated;
