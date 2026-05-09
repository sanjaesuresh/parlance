-- Migration: push_cron_weekly_recap
-- Every Sunday at 18:00 UTC, sends each user with a push token a weekly recap
-- summarising their XP earned this week and current league rank.
--
-- Uses user_stats.weekly_xp for XP and a rank() window over weekly_xp for rank.
--
-- PREREQUISITE: "app.supabase_service_role_key" must be set (see migration 20260508000002).

do $$
begin
  perform cron.unschedule('parlance-weekly-recap');
exception when others then null;
end $$;

select cron.schedule(
    'parlance-weekly-recap',            -- unique job name
    '0 18 * * 0',                       -- 18:00 UTC every Sunday
    $$
    select
        net.http_post(
            url     := 'https://xekrfjufgorrcnpnsaei.supabase.co/functions/v1/send-push',
            headers := jsonb_build_object(
                'Content-Type',  'application/json',
                'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
            ),
            body    := jsonb_build_object(
                'userId', recap.user_id::text,
                'title',  'Your weekly recap',
                'body',   'You earned ' || recap.weekly_xp || ' XP this week — you''re ranked #' || recap.league_rank || ' in the league.',
                'data',   jsonb_build_object(
                              'type',       'weekly_recap',
                              'weeklyXp',   recap.weekly_xp,
                              'leagueRank', recap.league_rank
                          )
            )
        )
    from (
        -- Users with a push token who have notifications enabled, enriched with XP and rank
        select pt.user_id,
               coalesce(us.weekly_xp, 0)                                   as weekly_xp,
               rank() over (order by coalesce(us.weekly_xp, 0) desc)::int  as league_rank
        from   public.push_tokens pt
        join   public.profiles     p  on p.id = pt.user_id
        left join public.user_stats us on us.user_id = pt.user_id
        where  p.daily_reminder_enabled = true
    ) recap;
    $$
);
