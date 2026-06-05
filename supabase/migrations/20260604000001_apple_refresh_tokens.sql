-- 20260604000001_apple_refresh_tokens.sql
-- Store Apple Sign-in refresh tokens server-side so account deletion can
-- revoke them per App Store Guideline 5.1.1(v).
--
-- Supabase does not currently persist Apple refresh tokens via the standard
-- Sign in with Apple flow, so the Cloudflare Worker's /delete-user handler
-- has been silently skipping the revoke step (App Review blocker). The iOS
-- client now captures `authorizationCode` on first Apple sign-in, posts it to
-- /apple/register, and the worker exchanges it for a refresh token and
-- upserts it here. /delete-user reads from this table to revoke at delete
-- time.
--
-- RLS is enabled with NO policies: only the service-role key (which bypasses
-- RLS) can read or write this table. Anon and authenticated clients must
-- never be able to read raw refresh tokens.

create table public.apple_refresh_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  created_at timestamptz not null default now()
);

alter table public.apple_refresh_tokens enable row level security;

comment on table public.apple_refresh_tokens is
  'Stores Apple Sign-in refresh tokens server-side so account deletion can revoke them per App Store Guideline 5.1.1(v). Service-role only.';
