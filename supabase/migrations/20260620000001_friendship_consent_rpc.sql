-- 20260620000001_friendship_consent_rpc.sql
-- SECURITY FIX (Critical): forged-friendship privacy bypass.
--
-- Previously the `friendships_insert_participant` RLS policy allowed any
-- authenticated user to INSERT a row (user_id_1 = me, user_id_2 = <victim>)
-- with no proof of consent. All privacy gates
-- (profile_privacy_rls / stats_rls_friends_only) are expressed as
--   EXISTS (SELECT 1 FROM friendships WHERE user_id_1 = auth.uid() AND user_id_2 = <target>)
-- so a single forged row let an attacker read any user's private profile,
-- stats, and full session-score history.
--
-- Fix: friendships may now only be created through a SECURITY DEFINER RPC that
-- requires a pending friend_request addressed to the caller. The direct client
-- INSERT policy is removed, so a forged row can no longer be written.

CREATE OR REPLACE FUNCTION public.accept_friend_request(request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_from   uuid;
    v_to     uuid;
    v_status text;
BEGIN
    SELECT from_user_id, to_user_id, status
      INTO v_from, v_to, v_status
      FROM friend_requests
     WHERE id = request_id;

    IF v_from IS NULL THEN
        RAISE EXCEPTION 'friend request not found';
    END IF;

    -- Only the recipient of the request may accept it.
    IF v_to <> auth.uid() THEN
        RAISE EXCEPTION 'not authorized to accept this request';
    END IF;

    -- Accept only from a pending state; 'accepted' is tolerated for idempotency
    -- (e.g. a retried client call) so the friendship rows are still ensured.
    IF v_status NOT IN ('pending', 'accepted') THEN
        RAISE EXCEPTION 'request is not pending';
    END IF;

    UPDATE friend_requests SET status = 'accepted' WHERE id = request_id;

    INSERT INTO friendships (user_id_1, user_id_2)
    VALUES (v_to, v_from), (v_from, v_to)
    ON CONFLICT DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_friend_request(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_friend_request(uuid) TO authenticated;

-- Remove the unsafe direct-insert path. Friendship creation now goes solely
-- through accept_friend_request (SECURITY DEFINER), which enforces consent.
-- SELECT and DELETE policies are unchanged: participants may still read their
-- own friendship rows and unfriend (delete) via either the policy or the
-- unfriend_user RPC.
DROP POLICY IF EXISTS "friendships_insert_participant" ON public.friendships;
