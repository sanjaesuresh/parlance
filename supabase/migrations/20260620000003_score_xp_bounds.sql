-- 20260620000003_score_xp_bounds.sql
-- SECURITY HARDENING (anti-cheat, partial mitigation for client-authoritative
-- scoring): bound the values clients can write to score/XP/stat columns.
--
-- XP, weekly_xp, avg_score and session scores are currently computed on-device
-- and upserted directly by the client, so a tampered client can write
-- arbitrary values (e.g. weekly_xp = 999999 to top the leaderboard). A full
-- fix makes scoring server-authoritative; until then these CHECK constraints
-- reject implausible values at the database boundary.
--
-- Constraints are added NOT VALID so the migration cannot fail on any
-- pre-existing rows, while still being enforced for every new INSERT/UPDATE.
-- After confirming legacy data is clean you may run the matching
-- `ALTER TABLE ... VALIDATE CONSTRAINT ...` statements (commented below).

-- session_scores.score: overall score is the mean of 5 metrics x10 => 0..100.
ALTER TABLE public.session_scores
    ADD CONSTRAINT session_scores_score_range
    CHECK (score >= 0 AND score <= 100) NOT VALID;

-- user_stats: counters are non-negative; avg_score is a 0..100 percentage.
ALTER TABLE public.user_stats
    ADD CONSTRAINT user_stats_nonneg
    CHECK (
        xp             >= 0 AND
        weekly_xp      >= 0 AND
        current_streak >= 0 AND
        longest_streak >= 0 AND
        total_sessions >= 0 AND
        avg_score      >= 0 AND avg_score <= 100
    ) NOT VALID;

-- Once legacy rows are confirmed in-range, validate the constraints:
-- ALTER TABLE public.session_scores VALIDATE CONSTRAINT session_scores_score_range;
-- ALTER TABLE public.user_stats    VALIDATE CONSTRAINT user_stats_nonneg;
