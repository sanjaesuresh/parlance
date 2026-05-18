-- 20260519000001_session_scores_client_id.sql
-- Adds client_session_id to session_scores so the offline retry path can
-- upsert idempotently instead of inserting duplicate rows on the second try.

alter table public.session_scores
    add column if not exists client_session_id uuid;

-- Back-fill any rows written before this column existed so we can apply
-- NOT NULL safely. New rows always come from the client with a stable UUID.
update public.session_scores
    set client_session_id = gen_random_uuid()
    where client_session_id is null;

alter table public.session_scores
    alter column client_session_id set not null;

alter table public.session_scores
    alter column client_session_id set default gen_random_uuid();

-- Idempotent uniqueness: the second sync of the same local session no-ops.
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'session_scores_user_client_session_unique'
    ) then
        alter table public.session_scores
            add constraint session_scores_user_client_session_unique
            unique (user_id, client_session_id);
    end if;
end$$;
