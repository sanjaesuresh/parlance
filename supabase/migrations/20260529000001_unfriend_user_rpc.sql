-- 20260529000001_unfriend_user_rpc.sql
-- Adds the `unfriend_user(other_user_id uuid)` RPC referenced by
-- `SocialService.removeFriend` and documented in
-- _docs/decisions/2026-05-08-unfriend-rpc.md, but never previously committed
-- as a migration. The function exists in the live Supabase project (created
-- via the dashboard); this file brings version control back in sync so a
-- fresh project / staging clone can reproduce the live behavior.
--
-- Why an RPC and not direct DELETEs from the client:
--   - Atomic: both directions of `friendships` and any historical
--     `friend_requests` between the two users are wiped in one transaction.
--   - Smaller surface: no DELETE policy on `friendships` exposed to clients.
--   - Single round-trip on flaky networks.
--   - Wiping accepted `friend_requests` is necessary because of the
--     unique(from_user_id, to_user_id) constraint — leaving an old row
--     would block re-friending.
--
-- Implementation follows the same pattern as the other SECURITY DEFINER
-- functions: a private-schema body + a thin public-schema wrapper, set
-- search_path = public, REVOKE from PUBLIC and GRANT EXECUTE to authenticated.

-- ============================================================
-- private.unfriend_user — the SECURITY DEFINER body
-- ============================================================

CREATE OR REPLACE FUNCTION private.unfriend_user(other_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id uuid := auth.uid();
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'authentication required';
    END IF;

    IF caller_id = other_user_id THEN
        RAISE EXCEPTION 'cannot unfriend yourself';
    END IF;

    -- Delete both directions of the friendship.
    DELETE FROM friendships
    WHERE (user_id_1 = caller_id AND user_id_2 = other_user_id)
       OR (user_id_1 = other_user_id AND user_id_2 = caller_id);

    -- Wipe accepted/declined friend_requests history between the two users
    -- so a future re-friend isn't blocked by the unique(from, to)
    -- constraint. Pending requests get cleared too — re-friending after an
    -- unfriend should start a fresh request flow.
    DELETE FROM friend_requests
    WHERE (from_user_id = caller_id AND to_user_id = other_user_id)
       OR (from_user_id = other_user_id AND to_user_id = caller_id);
END;
$$;

REVOKE ALL ON FUNCTION private.unfriend_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.unfriend_user(uuid) TO authenticated;

-- ============================================================
-- public.unfriend_user — thin SECURITY INVOKER wrapper exposed via PostgREST
-- ============================================================

CREATE OR REPLACE FUNCTION public.unfriend_user(other_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
    SELECT private.unfriend_user(other_user_id);
$$;

REVOKE ALL ON FUNCTION public.unfriend_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.unfriend_user(uuid) TO authenticated;
