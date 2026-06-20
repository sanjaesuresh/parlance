-- 20260620000002_search_profiles_escape_like.sql
-- SECURITY FIX (Medium): wildcard injection / user enumeration in
-- search_public_profiles.
--
-- The query was built as `p.username ILIKE '%' || q || '%'` with no escaping
-- of LIKE metacharacters. The iOS client sanitizes input, but the RPC is
-- GRANTed to `authenticated` and is directly callable via PostgREST with an
-- arbitrary `q`. Passing `q = '%'` (or '_') matches every user, enabling cheap
-- enumeration of the entire user base 20 rows at a time.
--
-- Fix: escape `\`, `%`, and `_` in the user-supplied term, use an explicit
-- ESCAPE clause, and require a minimum query length so a near-empty query
-- cannot match everyone. Projection and grants are unchanged.

DROP FUNCTION IF EXISTS public.search_public_profiles(text);
DROP FUNCTION IF EXISTS private.search_public_profiles(text);

CREATE OR REPLACE FUNCTION private.search_public_profiles(q text)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    avatar_url text,
    avatar_updated_at timestamptz,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH term AS (
        -- Escape LIKE metacharacters so they are matched literally.
        SELECT replace(replace(replace(coalesce(q, ''), '\', '\\'), '%', '\%'), '_', '\_') AS pat
    )
    SELECT
        p.id,
        p.username,
        p.avatar_emoji,
        p.avatar_url,
        p.avatar_updated_at,
        COALESCE(s.weekly_xp, 0),
        CASE
            WHEN COALESCE(s.weekly_xp, 0) >= 6000 THEN 'diamond'
            WHEN COALESCE(s.weekly_xp, 0) >= 3000 THEN 'platinum'
            WHEN COALESCE(s.weekly_xp, 0) >= 1500 THEN 'gold'
            WHEN COALESCE(s.weekly_xp, 0) >= 600  THEN 'silver'
            ELSE 'bronze'
        END
    FROM profiles p
    LEFT JOIN user_stats s ON s.user_id = p.id, term
    -- Require at least 2 meaningful characters; reject blank/too-short queries
    -- so a near-empty term cannot enumerate the whole table.
    WHERE length(btrim(coalesce(q, ''))) >= 2
      AND p.username ILIKE '%' || term.pat || '%' ESCAPE '\'
      AND p.id <> auth.uid()
    LIMIT 20;
$$;

REVOKE ALL ON FUNCTION private.search_public_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.search_public_profiles(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.search_public_profiles(q text)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    avatar_url text,
    avatar_updated_at timestamptz,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
AS $$
    SELECT * FROM private.search_public_profiles(q);
$$;

REVOKE ALL ON FUNCTION public.search_public_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(text) TO authenticated;
