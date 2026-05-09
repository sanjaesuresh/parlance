-- Migration: push_trigger_friend_request
-- DB trigger on friend_requests INSERT that calls the send-push Edge Function
-- to notify the recipient (to_user_id) that they have a new friend request.
--
-- Only fires when the new row has status = 'pending' (the initial state).
-- The trigger is AFTER INSERT so the row is committed before the HTTP call.
--
-- PREREQUISITE: "app.supabase_service_role_key" must be set (see migration 20260508000002).

-- 1. Trigger function
create or replace function public.notify_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_sender_name text;
    v_token       text;
begin
    -- Only notify on a new pending request
    if NEW.status <> 'pending' then
        return NEW;
    end if;

    -- Look up the recipient's push token (may not exist — that's fine)
    select token into v_token
    from   public.push_tokens
    where  user_id = NEW.to_user_id
    limit  1;

    if v_token is null then
        return NEW;  -- no token registered; nothing to do
    end if;

    -- Look up the sender's display name for a friendlier message
    select display_name into v_sender_name
    from   public.profiles
    where  id = NEW.from_user_id
    limit  1;

    -- Fire the push (fire-and-forget via pg_net)
    perform net.http_post(
        url     := 'https://xekrfjufgorrcnpnsaei.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
        ),
        body    := jsonb_build_object(
            'userId', NEW.to_user_id::text,
            'title',  coalesce(v_sender_name, 'Someone') || ' wants to be friends',
            'body',   coalesce(v_sender_name, 'A Parlance user') || ' sent you a friend request.',
            'data',   jsonb_build_object(
                          'type',          'friend_request',
                          'fromUserId',    NEW.from_user_id::text,
                          'requestId',     NEW.id::text
                      )
        )
    );

    return NEW;
end;
$$;

-- 2. Attach trigger to friend_requests
drop trigger if exists trg_push_friend_request on public.friend_requests;

create trigger trg_push_friend_request
    after insert on public.friend_requests
    for each row
    execute function public.notify_friend_request();
