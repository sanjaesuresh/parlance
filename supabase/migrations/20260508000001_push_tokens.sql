-- Migration: push_tokens
-- Stores APNs device tokens so the server can send push notifications.
-- One row per user — reinstalls overwrite via upsert on user_id.

create table if not exists public.push_tokens (
    id          uuid        primary key default gen_random_uuid(),
    user_id     uuid        not null references auth.users(id) on delete cascade,
    token       text        not null,
    platform    text        not null default 'ios' check (platform in ('ios', 'android', 'web')),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    unique (user_id)
);

-- Note: Postgres creates an implicit index for the UNIQUE (user_id) constraint above;
-- no extra index is needed for service-role lookups.

-- RLS
alter table public.push_tokens enable row level security;

-- Users can read and write only their own row
create policy "Users can manage their own push token"
    on public.push_tokens
    for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Service role bypasses RLS by default in Supabase — no extra policy needed.
