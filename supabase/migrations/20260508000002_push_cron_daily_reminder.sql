-- Migration: push_cron_daily_reminder
-- Adds daily_reminder_enabled to profiles and a pg_cron job that fires at 09:00 UTC
-- every day, calling the send-push Edge Function for users who:
--   1. Have a push token
--   2. Have daily_reminder_enabled = true
--   3. Have NOT completed a session today (UTC)
--
-- IMPORTANT: Before applying this migration, set the service role key as a DB setting:
--   ALTER DATABASE postgres SET "app.supabase_service_role_key" = '<your-service-role-key>';
-- Replace <your-service-role-key> with the value from your Supabase project settings
-- (Settings → API → service_role key). This only needs to be done once.

-- 1. Add daily_reminder_enabled column to profiles (default false = opt-in)
alter table public.profiles
    add column if not exists daily_reminder_enabled boolean not null default false;

-- 2. Schedule the daily reminder cron job (09:00 UTC every day)
--    pg_cron does not support DO blocks, so we call a helper SQL SELECT that
--    iterates over qualifying users and fires net.http_post for each one.
--
--    The inner query collects one row per user and calls the Edge Function.
--    net.http_post is fire-and-forget from Postgres's perspective; failures
--    surface in the pg_net request log but do not abort the cron job.

do $$
begin
  perform cron.unschedule('parlance-daily-reminder');
exception when others then null;
end $$;

select cron.schedule(
    'parlance-daily-reminder',          -- unique job name
    '0 9 * * *',                        -- 09:00 UTC every day
    $$
    select
        net.http_post(
            url     := 'https://xekrfjufgorrcnpnsaei.supabase.co/functions/v1/send-push',
            headers := jsonb_build_object(
                'Content-Type',  'application/json',
                'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
            ),
            body    := jsonb_build_object(
                'userId', u.user_id::text,
                'title',  'Time to practice!',
                'body',   'Open Parlance and keep your streak alive.',
                'data',   jsonb_build_object('type', 'daily_reminder')
            )
        )
    from (
        -- Users who opted in, have a token, and haven't practised today
        select pt.user_id
        from   public.push_tokens  pt
        join   public.profiles     p  on p.id = pt.user_id
        where  p.daily_reminder_enabled = true
          and  not exists (
                   select 1
                   from   public.session_scores ss
                   where  ss.user_id    = pt.user_id
                     and  ss.created_at >= date_trunc('day', now() at time zone 'utc')
               )
    ) u;
    $$
);
