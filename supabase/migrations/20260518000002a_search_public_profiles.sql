-- 20260518000002a_search_public_profiles.sql
-- Username-prefix search returning slim public projection.
-- Used by SocialService.searchUsers — non-friend search must NOT leak display_name.

CREATE OR REPLACE FUNCTION search_public_profiles(q text)
RETURNS TABLE (
    id uuid,
    username text,
    avatar_emoji text,
    weekly_xp int,
    tier text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        p.id, p.username, p.avatar_emoji,
        COALESCE(s.weekly_xp, 0),
        CASE
            WHEN COALESCE(s.weekly_xp, 0) >= 6000 THEN 'diamond'
            WHEN COALESCE(s.weekly_xp, 0) >= 3000 THEN 'platinum'
            WHEN COALESCE(s.weekly_xp, 0) >= 1500 THEN 'gold'
            WHEN COALESCE(s.weekly_xp, 0) >= 600  THEN 'silver'
            ELSE 'bronze'
        END
    FROM profiles p
    LEFT JOIN user_stats s ON s.user_id = p.id
    WHERE p.username ILIKE '%' || q || '%' AND p.id <> auth.uid()
    LIMIT 20;
$$;

REVOKE ALL ON FUNCTION search_public_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION search_public_profiles(text) TO authenticated;
