# Parlance User Guide

**AI-powered speech coaching for iOS.** Practice speaking. Get real feedback. Improve.

---

## Getting Started

### What Parlance Does

Parlance is a personal speaking coach in your pocket. Each session follows the same loop:

1. Pick a practice mode
2. Get a prompt
3. Record yourself speaking
4. Receive AI-powered feedback and a score
5. Earn XP, build a streak, and track your improvement over time

### Requirements

- iOS 17 or later
- Active internet connection (required — AI scoring needs a network connection)
- Microphone permission (granted on first session)
- Speech recognition permission (granted on first session)

---

## The Four Core Practice Modes

| Mode | What It Trains | Best For |
|------|---------------|----------|
| **Job Interview** | STAR structure, conciseness, confidence signals | Behavioral and situational questions |
| **Pitch / Sales** | Hook strength, urgency, persuasion | Investor pitches, cold outreach, objection handling |
| **Keynote / Talk** | Narrative arc, opening impact, pacing | TED-style talks, conference sessions, toasts |
| **Daily Conversation** | Clarity, naturalness, holding attention | Explaining ideas, impromptu speaking, debate |

Additional modes (Debate, Storytelling, Explanation, Negotiation, Impromptu, Networking) are available at higher difficulty tiers.

---

## Difficulty Tiers

Parlance uses five difficulty tiers. Select yours from the home screen before starting a session.

| Tier | Level Range | Who It's For |
|------|-------------|--------------|
| **Starter** | 1–2 | First-timers; Nervous Novice → First-Timer |
| **Developing** | 3–4 | Building confidence; Getting Warmed Up → Emerging Orator |
| **Confident** | 5–6 | Consistent speakers; Confident Communicator → Polished Speaker |
| **Advanced** | 7–8 | High-stakes settings; Compelling Storyteller → Stage Commander |
| **Expert** | 9–10 | Elite performance; Master Presenter → Elite Orator |

Higher tiers receive harder prompts, stricter scoring criteria, and deeper AI feedback.

---

## Running a Session

### Step 1 — Pick a Mode

From the **Home** tab, tap a practice mode or the **Daily Challenge** card at the top.

### Step 2 — Review Your Prompt

The loading screen shows:
- Your practice prompt
- Three coaching tips tailored to the mode and your difficulty tier
- A **"Tap when ready"** button

Read everything before tapping. Questions are drawn from a bank of 400+ prompts, deduplicated so you rarely repeat.

### Step 3 — Countdown

A 3–2–1 countdown runs after you tap ready. Use it to take a breath. Recording starts automatically when it hits zero.

### Step 4 — Record

- The **mic button** at the center shows a progress ring indicating your target duration
- A subtle nudge appears after 8 seconds if you pause — this is intentional; it keeps you deliberate
- Minimum recording length: **5 seconds** (stop button is locked until then)
- Maximum recording length: **3 minutes**
- Tap the stop button when finished

### Step 5 — Results

After recording, Parlance analyzes your speech. The results screen shows:

- **Overall score** (0–100) with delta vs. your prior average
- **AI coach paragraph** — mode-specific, level-aware coaching from Claude Haiku
- **Best moment** — timestamp + transcript snippet of your strongest section
- **Worst moment** — timestamp + transcript snippet of where to improve
- **Metric breakdown** — five scored dimensions (see below)
- **Filler word highlight** — your transcript with fillers marked inline
- **XP earned**

---

## Scoring System

Every session is scored by AI using your transcript, per-word timing data, and on-device audio features (pitch, energy, speaking rate variation). Scores are holistic — the AI evaluates content quality and delivery together, not just text patterns.

### The Five Core Metrics

| Metric | What It Measures | Scoring Logic |
|--------|-----------------|---------------|
| **Filler Words** | Count of "um," "uh," "like," "you know," etc. | `max(0, 10 − fillerCount)` |
| **Pace** | Words per minute | 130–160 WPM = 10; 110–129 or 161–185 = 7; outside = 4 |
| **Clarity** | Sentence length and fragment detection | −1 per sentence >25 words; −0.5 per fragment <5 words |
| **Structure** | Opening/body/close detection; STAR in interview mode | Presence and quality of each section |
| **Vocabulary Strength** | Type-token ratio, strong verbs, weak-word avoidance | Richness and precision of word choice |

**Overall score** = mean of all metric scores × 10 (range: 0–100).

### Audio Features (Sent to AI)

The AI also receives:
- Pitch mean, standard deviation, and range (monotone vs. dynamic indicator)
- RMS energy and variation (enthusiasm/engagement indicator)
- Speech-to-silence ratio
- Longest pause duration and position
- Speaking rate variation across 10-second windows

This gives the AI a real picture of your delivery — not just what you said, but how you said it.

---

## Gamification

### XP and Levels

- Earn XP every session
- Daily Challenge sessions award bonus XP
- XP accumulates across a 10-level ranking system (Nervous Novice → Elite Orator)
- Your current level is shown on the Home tab

### Streaks

A streak increments every day you complete at least one session. Your current streak is shown on the home screen. Don't break the chain.

### Daily Challenge

One featured prompt per day across all modes. Completing it earns bonus XP and counts toward your streak. Resets at midnight.

### Weekly League

- Resets every Monday
- Global leaderboard ranked by XP earned that week
- Tiers: Bronze → Silver → Gold → Platinum → Diamond
- Tier promotions and demotions happen at the weekly reset

### Achievements

One-time unlocks for milestones:

| Achievement | Trigger |
|-------------|---------|
| First session | Complete any session |
| 7-day streak | Maintain a 7-day streak |
| 80+ score | Score 80 or above in any session |
| 30 sessions | Complete 30 total sessions |
| Level 5 | Reach difficulty level 5 |
| Zero fillers | Complete a session with no detected filler words |

---

## Progress Tab

The **Progress** tab shows your improvement over time:

- **Score history chart** — all sessions plotted chronologically
- **Skill trends** — this week vs. last week, per metric
- **Mode breakdown** — how you perform across different practice modes
- **Recent sessions** — list of your last sessions with scores and timestamps

---

## Profile

Access your profile from the **Profile** tab (bottom-right).

- **Edit Profile** — tap the edit button to update your display name and username
- **Settings** — tap the gear icon to access:
  - **Appearance** — choose System (auto), Light, or Dark mode
  - **Notifications** — manage daily reminder settings
  - **Daily Goal** — set your session target per day

---

## League Tab

Shows the current weekly leaderboard. Includes:

- Your current tier badge and rank
- Global leaderboard (all users by weekly XP)
- Friends leaderboard (people you follow)
- Countdown timer to the next weekly reset

---

## Offline Behavior

Parlance **requires an internet connection**. If your device goes offline:

- A full-screen "No Internet Connection" screen blocks the app
- The app resumes automatically when connectivity is restored

Practice prompts and tips are bundled on-device and load instantly — the network is only required for AI scoring after you record.

---

## Privacy

- Audio recordings are processed locally for transcription (Apple's SFSpeechRecognizer, on-device)
- Transcripts and audio features are sent to Parlance's AI backend for scoring — they are not stored after the scoring call completes
- No audio files leave your device

---

## Tips for Better Scores

1. **Speak at a measured pace** — 130–160 words per minute is the sweet spot. Rushing hurts clarity.
2. **Use the 3 coaching tips** shown on the loading screen. They're tailored to your prompt.
3. **Vary your pitch** — monotone delivery scores lower. Use emphasis to signal key points.
4. **Avoid fillers** — pause silently instead of saying "um" or "uh." Silence is strength.
5. **Structure your answer** — opening statement, 2–3 supporting points, a clear close.
6. **Don't over-run** — 60–90 seconds is usually enough for most prompts. Tight is better than rambling.
7. **Do the Daily Challenge** — bonus XP and streak credit. No reason to skip it.
