-- Initial schema for Parlance.
-- Inferred from iOS client code (SupabaseModels.swift, SocialService.swift,
-- SyncService.swift). If the live database already has different DDL, the
-- "if not exists" clauses will make this a no-op for existing tables.
-- Before deploying to a fresh project: run all migrations in date order.
--
-- Tables created here: profiles, user_stats, session_scores,
--                       friend_requests, friendships
-- Tables NOT created here (handled by later migrations):
--   push_tokens          → 20260508000001_push_tokens.sql
--   blocked_users        → 20260511000001_ugc_moderation.sql
--   user_reports         → 20260511000001_ugc_moderation.sql

-- ============================================================
-- profiles
-- One row per authenticated user; holds public identity fields.
-- ============================================================

create table if not exists public.profiles (
    id                      uuid        primary key
                                        references auth.users(id) on delete cascade,
    display_name            text        not null,
    username                text        not null,
    avatar_emoji            text        not null default '🎤',
    location                text,
    occupation              text,
    daily_reminder_enabled  boolean     not null default true,
    created_at              timestamptz not null default now(),
    constraint profiles_username_unique unique (username)
);

-- username lookups (search + uniqueness enforcement)
create index if not exists profiles_username_idx on public.profiles (username);

alter table public.profiles enable row level security;

-- any authenticated user can read profiles (needed for search + leaderboards)
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
    on public.profiles
    for select
    to authenticated
    using (true);

-- only the owner can insert their own row
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
    on public.profiles
    for insert
    to authenticated
    with check (id = auth.uid());

-- only the owner can update their own row
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
    on public.profiles
    for update
    to authenticated
    using  (id = auth.uid())
    with check (id = auth.uid());

-- only the owner can delete their own row
drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
    on public.profiles
    for delete
    to authenticated
    using (id = auth.uid());


-- ============================================================
-- user_stats
-- Aggregated XP, streak, and score stats; one row per user.
-- Also readable by friends for leaderboard views.
-- ============================================================

create table if not exists public.user_stats (
    user_id         uuid        primary key
                                references auth.users(id) on delete cascade,
    xp              int         not null default 0,
    weekly_xp       int         not null default 0,
    current_streak  int         not null default 0,
    longest_streak  int         not null default 0,
    avg_score       int         not null default 0,
    total_sessions  int         not null default 0,
    last_session_at timestamptz,
    updated_at      timestamptz not null default now()
);

alter table public.user_stats enable row level security;

-- any authenticated user can read stats (friends leaderboard)
drop policy if exists "user_stats_select_authenticated" on public.user_stats;
create policy "user_stats_select_authenticated"
    on public.user_stats
    for select
    to authenticated
    using (true);

-- only the owner can insert their own stats row
drop policy if exists "user_stats_insert_own" on public.user_stats;
create policy "user_stats_insert_own"
    on public.user_stats
    for insert
    to authenticated
    with check (user_id = auth.uid());

-- only the owner can update their own stats row
drop policy if exists "user_stats_update_own" on public.user_stats;
create policy "user_stats_update_own"
    on public.user_stats
    for update
    to authenticated
    using  (user_id = auth.uid())
    with check (user_id = auth.uid());

-- only the owner can delete their own stats row
drop policy if exists "user_stats_delete_own" on public.user_stats;
create policy "user_stats_delete_own"
    on public.user_stats
    for delete
    to authenticated
    using (user_id = auth.uid());


-- ============================================================
-- session_scores
-- Individual session results; readable by other users to power
-- the "recent scores" sparkline on friend profiles.
-- ============================================================

create table if not exists public.session_scores (
    id          uuid        primary key default gen_random_uuid(),
    user_id     uuid        not null references auth.users(id) on delete cascade,
    score       int         not null,
    mode        text        not null,
    level       int         not null,
    created_at  timestamptz not null default now()
);

-- fast per-user chronological queries (recent scores, history chart)
create index if not exists session_scores_user_created_idx
    on public.session_scores (user_id, created_at desc);

alter table public.session_scores enable row level security;

-- any authenticated user can read scores (friend profile / leaderboard context)
drop policy if exists "session_scores_select_authenticated" on public.session_scores;
create policy "session_scores_select_authenticated"
    on public.session_scores
    for select
    to authenticated
    using (true);

-- only the owner can insert their own score rows
drop policy if exists "session_scores_insert_own" on public.session_scores;
create policy "session_scores_insert_own"
    on public.session_scores
    for insert
    to authenticated
    with check (user_id = auth.uid());

-- only the owner can update their own score rows
drop policy if exists "session_scores_update_own" on public.session_scores;
create policy "session_scores_update_own"
    on public.session_scores
    for update
    to authenticated
    using  (user_id = auth.uid())
    with check (user_id = auth.uid());

-- only the owner can delete their own score rows
drop policy if exists "session_scores_delete_own" on public.session_scores;
create policy "session_scores_delete_own"
    on public.session_scores
    for delete
    to authenticated
    using (user_id = auth.uid());


-- ============================================================
-- friend_requests
-- Tracks pending/accepted/declined friend requests.
-- status is constrained to ('pending','accepted','declined').
-- Unique (from_user_id, to_user_id) prevents duplicate requests.
-- ============================================================

create table if not exists public.friend_requests (
    id              uuid        primary key default gen_random_uuid(),
    from_user_id    uuid        not null references auth.users(id) on delete cascade,
    to_user_id      uuid        not null references auth.users(id) on delete cascade,
    status          text        not null default 'pending'
                                check (status in ('pending', 'accepted', 'declined')),
    created_at      timestamptz not null default now(),
    constraint friend_requests_unique_pair unique (from_user_id, to_user_id)
);

-- fast lookups for the incoming-request badge count and notification triggers
create index if not exists friend_requests_pending_to_idx
    on public.friend_requests (to_user_id)
    where status = 'pending';

alter table public.friend_requests enable row level security;

-- participants can see requests they sent or received
drop policy if exists "friend_requests_select_participant" on public.friend_requests;
create policy "friend_requests_select_participant"
    on public.friend_requests
    for select
    to authenticated
    using (from_user_id = auth.uid() or to_user_id = auth.uid());

-- only the sender can create a request
drop policy if exists "friend_requests_insert_own" on public.friend_requests;
create policy "friend_requests_insert_own"
    on public.friend_requests
    for insert
    to authenticated
    with check (from_user_id = auth.uid());

-- only the recipient can update status (accept / decline)
drop policy if exists "friend_requests_update_recipient" on public.friend_requests;
create policy "friend_requests_update_recipient"
    on public.friend_requests
    for update
    to authenticated
    using  (to_user_id = auth.uid())
    with check (to_user_id = auth.uid());

-- either participant can delete the row (sender cancels; recipient dismisses)
drop policy if exists "friend_requests_delete_participant" on public.friend_requests;
create policy "friend_requests_delete_participant"
    on public.friend_requests
    for delete
    to authenticated
    using (from_user_id = auth.uid() or to_user_id = auth.uid());


-- ============================================================
-- friendships
-- Stores accepted friendships as TWO symmetric rows (A→B + B→A)
-- so leaderboard queries only need eq("user_id_1", currentId).
-- PK is (user_id_1, user_id_2).
-- ============================================================

create table if not exists public.friendships (
    user_id_1   uuid        not null references auth.users(id) on delete cascade,
    user_id_2   uuid        not null references auth.users(id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (user_id_1, user_id_2)
);

-- separate indexes on each column for symmetric lookups
create index if not exists friendships_user_id_1_idx on public.friendships (user_id_1);
create index if not exists friendships_user_id_2_idx on public.friendships (user_id_2);

alter table public.friendships enable row level security;

-- either participant can read the row
drop policy if exists "friendships_select_participant" on public.friendships;
create policy "friendships_select_participant"
    on public.friendships
    for select
    to authenticated
    using (user_id_1 = auth.uid() or user_id_2 = auth.uid());

-- either participant can insert (SocialService inserts both rows in acceptRequest)
drop policy if exists "friendships_insert_participant" on public.friendships;
create policy "friendships_insert_participant"
    on public.friendships
    for insert
    to authenticated
    with check (user_id_1 = auth.uid() or user_id_2 = auth.uid());

-- either participant can delete (unfriend; unfriend_user RPC removes both rows)
drop policy if exists "friendships_delete_participant" on public.friendships;
create policy "friendships_delete_participant"
    on public.friendships
    for delete
    to authenticated
    using (user_id_1 = auth.uid() or user_id_2 = auth.uid());
