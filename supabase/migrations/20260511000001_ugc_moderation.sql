-- UGC moderation tables: blocked_users + user_reports

create table if not exists blocked_users (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists blocked_users_blocker_idx on blocked_users (blocker_id);
create index if not exists blocked_users_blocked_idx on blocked_users (blocked_id);

alter table blocked_users enable row level security;

create policy "users select their own blocks" on blocked_users
  for select using (auth.uid() = blocker_id);

create policy "users insert their own blocks" on blocked_users
  for insert with check (auth.uid() = blocker_id);

create policy "users delete their own blocks" on blocked_users
  for delete using (auth.uid() = blocker_id);

create table if not exists user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  details text,
  created_at timestamptz not null default now(),
  status text not null default 'open',
  check (reporter_id <> reported_id)
);

create index if not exists user_reports_reported_idx on user_reports (reported_id);
create index if not exists user_reports_status_idx on user_reports (status);

alter table user_reports enable row level security;

create policy "users insert their own reports" on user_reports
  for insert with check (auth.uid() = reporter_id);

-- Reads of user_reports are admin-only; no select policy here.
