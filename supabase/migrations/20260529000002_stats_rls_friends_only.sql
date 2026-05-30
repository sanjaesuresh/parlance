-- 20260529000002_stats_rls_friends_only.sql
-- Tightens SELECT RLS on `user_stats` and `session_scores` from
-- `using (true)` (world-readable to any authenticated user) to self-or-friend
-- only. The profile-privacy migration `20260518000002` did this for `profiles`
-- but missed these two tables, so a curious user with the Supabase anon JWT
-- could still enumerate every other user's XP, streak, and full session
-- score history — including non-friends.
--
-- The leaderboard / friends-activity / coach-brief surfaces all consume
-- these tables via SECURITY DEFINER RPCs (get_global_leaderboard,
-- get_friend_activity, etc.), which already pre-aggregate or scope the
-- query and continue to work regardless of caller RLS because of definer
-- semantics. Direct SELECTs from a client now only return rows for the
-- caller themselves or their friends.
--
-- "friend" is defined as a row in `friendships` connecting the two users
-- (the table stores both directions of every friendship, so a single EXISTS
-- check is sufficient).

-- ============================================================
-- user_stats
-- ============================================================

DROP POLICY IF EXISTS "user_stats_select_authenticated" ON public.user_stats;

CREATE POLICY "user_stats_select_self_or_friend"
    ON public.user_stats
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM friendships f
            WHERE f.user_id_1 = auth.uid() AND f.user_id_2 = user_stats.user_id
        )
    );

-- ============================================================
-- session_scores
-- ============================================================

DROP POLICY IF EXISTS "session_scores_select_authenticated" ON public.session_scores;

CREATE POLICY "session_scores_select_self_or_friend"
    ON public.session_scores
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM friendships f
            WHERE f.user_id_1 = auth.uid() AND f.user_id_2 = session_scores.user_id
        )
    );
