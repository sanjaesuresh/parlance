# 2026-05-08: Unfriend uses a Postgres RPC, not client-side DELETE

## Context

Adding unfriend functionality required deleting two `friendships` rows (compound PK stores both directions) and any historical `friend_requests` rows between the two users. The historical wipe is necessary because `friend_requests` has `unique (from_user_id, to_user_id)` — leaving the old `accepted` row would block a future `pending` insert when the users tried to re-friend.

## Decision

Implement unfriend as a `security definer` Postgres function `unfriend_user(other_user_id uuid)`, not as client-side DELETE statements with a permissive RLS policy.

## Why

- **Atomicity.** Three deletes (two on `friendships`, up to two on `friend_requests`) succeed or fail together. A client-side approach would risk a partially-unfriended state if the second call failed.
- **Narrower attack surface.** No `DELETE` policy on `friendships` is exposed to the client at all. The function gates the operation and rejects self-unfriend.
- **One round-trip.** Mobile clients on flaky networks benefit.

Cancel-request is the opposite case: it touches one row only, so we use a direct `DELETE` + a narrow RLS policy (`from_user_id = auth.uid() and status = 'pending'`).

## Consequences

- All future "remove friend" code paths must go through this RPC, not direct DELETE.
- The RPC is `security definer` — review carefully if its body is ever changed.
- We do NOT keep a `friend_requests` audit log of accepted/declined history. If product later wants this, we'll need a separate `friend_request_events` log.
