-- 20260518000002_profile_privacy_rls.sql
-- Restrict raw profile reads to self + friends. Non-friends must use
-- get_public_profile() which returns a slim projection.

-- 1) Replace permissive read policy on profiles.
DROP POLICY IF EXISTS "profiles read all" ON profiles;

CREATE POLICY "profiles read self or friend"
ON profiles
FOR SELECT
USING (
    auth.uid() = id
    OR EXISTS (
        SELECT 1 FROM friendships
        WHERE user_id_1 = auth.uid() AND user_id_2 = profiles.id
    )
);

-- 2) Slim public projection. Returns only handle/avatar/tier — never name,
--    location, occupation, streak, or scores. Callable by any authenticated user.
CREATE OR REPLACE FUNCTION get_public_profile(target_id uuid)
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
        p.id,
        p.username,
        p.avatar_emoji,
        COALESCE(s.weekly_xp, 0) AS weekly_xp,
        CASE
            WHEN COALESCE(s.weekly_xp, 0) >= 6000 THEN 'diamond'
            WHEN COALESCE(s.weekly_xp, 0) >= 3000 THEN 'platinum'
            WHEN COALESCE(s.weekly_xp, 0) >= 1500 THEN 'gold'
            WHEN COALESCE(s.weekly_xp, 0) >= 600  THEN 'silver'
            ELSE 'bronze'
        END AS tier
    FROM profiles p
    LEFT JOIN user_stats s ON s.user_id = p.id
    WHERE p.id = target_id;
$$;

REVOKE ALL ON FUNCTION get_public_profile(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_public_profile(uuid) TO authenticated;
