-- 20260518000006_global_leaderboard_unique_ranks.sql
-- Fix: use ROW_NUMBER() with a deterministic tiebreak so the global leaderboard
-- returns exactly N rows even when many users are tied (e.g. all at 0 XP).
-- Replaces the DENSE_RANK() version from 20260518000004.

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
