-- 20260518000001_personal_bests.sql
-- Per-user, per-mode best score. Backs the +100 XP personal-best bonus.

CREATE TABLE personal_bests (
    user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    mode text NOT NULL,
    best_score int NOT NULL CHECK (best_score >= 0 AND best_score <= 100),
    achieved_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, mode)
);

ALTER TABLE personal_bests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "personal_bests read own"
ON personal_bests FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "personal_bests write own"
ON personal_bests FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "personal_bests update own"
ON personal_bests FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
