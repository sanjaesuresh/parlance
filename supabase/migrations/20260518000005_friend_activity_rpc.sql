-- 20260518000004_friend_activity_rpc.sql
-- Surface recent friend events: session scores and personal bests.

CREATE OR REPLACE FUNCTION get_friend_activity(limit_n int DEFAULT 10)
RETURNS TABLE (
    actor_id uuid,
    actor_username text,
    actor_display_name text,
    actor_avatar_emoji text,
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
        c.event_type,
        c.event_at,
        c.payload
    FROM combined c
    JOIN profiles p ON p.id = c.actor_id
    ORDER BY c.event_at DESC
    LIMIT limit_n;
$$;

REVOKE ALL ON FUNCTION get_friend_activity(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_friend_activity(int) TO authenticated;
