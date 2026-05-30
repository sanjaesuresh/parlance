-- 20260529000003_weekly_xp_reset_cron.sql
-- Server-side `weekly_xp` reset job.
--
-- Today the weekly XP reset is performed client-side in `SyncService` the
-- first time a user opens the app on or after Monday. That biases the
-- global leaderboard toward users who haven't synced yet (their old
-- weekly_xp stays high until they next launch). Re-running on the server
-- at Monday 00:00 UTC removes the dependency on client activity.
--
-- The job is idempotent — multiple runs in the same minute produce the
-- same end state (zeroed weekly_xp for everyone). The cron.schedule call
-- itself is wrapped in a DO block that unschedules any prior version first,
-- matching the pattern in the other push cron migrations.

DO $$
BEGIN
    PERFORM cron.unschedule('parlance-weekly-xp-reset');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

SELECT cron.schedule(
    'parlance-weekly-xp-reset',
    '0 0 * * 1', -- Monday 00:00 UTC
    $$ UPDATE public.user_stats SET weekly_xp = 0 WHERE weekly_xp <> 0; $$
);
