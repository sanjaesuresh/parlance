-- 20260518000003_global_leaderboard_rpc.sql

CREATE INDEX IF NOT EXISTS user_stats_weekly_xp_idx
    ON user_stats (weekly_xp DESC);

CREATE OR REPLACE FUNCTION get_global_leaderboard(limit_n int DEFAULT 10)
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
            COALESCE(s.weekly_xp, 0) AS weekly_xp,
            DENSE_RANK() OVER (ORDER BY COALESCE(s.weekly_xp, 0) DESC) AS rank
        FROM profiles p
        LEFT JOIN user_stats s ON s.user_id = p.id
    )
    SELECT jsonb_agg(jsonb_build_object(
        'id', id,
        'username', username,
        'avatar_emoji', avatar_emoji,
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
            COALESCE(s.weekly_xp, 0) AS weekly_xp,
            DENSE_RANK() OVER (ORDER BY COALESCE(s.weekly_xp, 0) DESC) AS rank
        FROM profiles p
        LEFT JOIN user_stats s ON s.user_id = p.id
    )
    SELECT jsonb_build_object(
        'id', id,
        'username', username,
        'avatar_emoji', avatar_emoji,
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

REVOKE ALL ON FUNCTION get_global_leaderboard(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_global_leaderboard(int) TO authenticated;
