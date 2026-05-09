-- Migration: push_cron_league_reset
-- Sends a push notification every Sunday at 23:00 UTC (1 hour before the Monday
-- 00:00 UTC weekly league reset) to users who:
--   1. Are in the top 3 by weekly_xp (league ranking)
--   2. Have a push token
--
-- All top-3 users are notified regardless of whether they've played today —
-- the league reset is relevant to them either way.
--
-- PREREQUISITE: "app.supabase_service_role_key" must be set (see migration 20260508000002).

do $$
begin
  perform cron.unschedule('parlance-league-reset-warning');
exception when others then null;
end $$;

select cron.schedule(
    'parlance-league-reset-warning',    -- unique job name
    '0 23 * * 0',                       -- 23:00 UTC every Sunday
    $$
    select
        net.http_post(
            url     := 'https://xekrfjufgorrcnpnsaei.supabase.co/functions/v1/send-push',
            headers := jsonb_build_object(
                'Content-Type',  'application/json',
                'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
            ),
            body    := jsonb_build_object(
                'userId', ranked.user_id::text,
                'title',  'League resets in 1 hour',
                'body',   'Defend your spot before Monday.',
                'data',   jsonb_build_object('type', 'league_reset')
            )
        )
    from (
        -- Top-3 users by weekly XP who have a token
        select us.user_id
        from (
            select user_id,
                   weekly_xp,
                   rank() over (order by weekly_xp desc) as league_rank
            from   public.user_stats
        ) us
        join   public.push_tokens pt on pt.user_id = us.user_id
        where  us.league_rank <= 3
    ) ranked;
    $$
);
