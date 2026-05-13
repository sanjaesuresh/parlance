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
- Apple ID for Sign in with Apple (required to create an account)
- Active internet connection (required — AI scoring needs a network connection)
- Microphone permission (granted on first session)
- Speech recognition permission (granted on first session)

### Creating an Account

Parlance uses **Sign in with Apple**. On first launch:

1. Tap **Continue with Apple** on the welcome screen
2. Choose whether to share your name and email
3. Set a display name and username (must be unique)
4. Optionally add location and occupation — these help personalize coaching context

Your profile, session history, friend graph, and progress sync across any device you sign into. You can delete your account from **Profile → Settings → Delete Account** at any time; this wipes your data from Parlance's servers.

---

## Practice Modes

| Mode | What It Trains | Best For |
|------|---------------|----------|
| **Real Life** | Whatever your actual situation requires | A specific upcoming conversation — paste the scenario and Parlance builds a session around it |
| **Job Interview** | STAR structure, conciseness, confidence signals | Behavioral and situational questions |
| **Pitch / Sales** | Hook strength, urgency, persuasion | Investor pitches, cold outreach, objection handling |
| **Keynote / Talk** | Narrative arc, opening impact, pacing | TED-style talks, conference sessions, toasts |
| **Daily Convo** | Clarity, naturalness, holding attention | Everyday conversations, reflection, observational chat |
| **Debate / Argue** | Argument flow, rebuttal, position-taking | Holding a stance under pressure, persuasion structure |
| **Storytelling** | Narrative arc, vivid detail, engagement | Personal anecdotes, audience attention |
| **Explain a Topic** | Clarity, analogy, simplification | Teaching complex ideas; sub-categorized into knowledge domains (philosophy, science, economics, etc.) and industries (tech, healthcare, finance, etc.) |
| **Negotiation** | Persuasion, framing, active listening | Salary, business deals, conflict |
| **Impromptu** | Quick thinking, coherence under pressure | Off-the-cuff prompts, no prep |
| **Networking** | Introduction, rapport, memorable delivery | Events, intros, building connections |

**Job Interview**, **Daily Convo**, **Impromptu**, **Explain a Topic**, and **Networking** are available on the free tier. The remaining modes — including **Real Life** — require Pro.

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

Read everything before tapping. Questions are drawn from a bundled bank of roughly 1,750 prompts (10 modes × 5 difficulty bands), deduplicated against your last 50 questions in that mode+band so you rarely repeat.

For **Real Life**, instead of a generated prompt you'll type or paste the scenario you're preparing for. The app validates that what you typed looks like a real speaking situation (a conversation, pitch, talk, etc.) and generates coaching tips tailored to it.

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
- **AI coach paragraph** — mode-specific, level-aware coaching
- **Best moment** — timestamp + transcript snippet of your strongest section
- **Worst moment** — timestamp + transcript snippet of where to improve
- **Metric breakdown** — up to 10 AI-scored dimensions depending on mode (see below)
- **Filler word highlight** — your transcript with fillers marked inline
- **XP earned**

---

## Scoring System

Every session is scored by AI using your transcript, per-word timing data, and on-device audio features (pitch, energy, speaking rate variation). Scores are holistic — the AI evaluates content quality and delivery together, not just text patterns.

### Scored Metrics

7 metrics appear in every session:

| Metric | What It Measures |
|--------|-----------------|
| **Filler Words** | Count of "um," "uh," "like," "you know," etc. |
| **Pace** | Speaking speed and rhythm |
| **Clarity** | How easy your words are to follow |
| **Structure** | Opening, body, and closing flow |
| **Vocabulary** | Word choice strength and variety |
| **Relevance** | Did you answer the question? |
| **Comprehensibility** | Could a listener follow your reasoning? |

Additional metrics appear depending on mode:

| Metric | Modes |
|--------|-------|
| **Delivery Confidence** | Interview, Pitch, Keynote, Debate, Negotiation, Impromptu |
| **Persuasiveness** | Pitch, Debate, Negotiation, Keynote |
| **Engagement** | Storytelling, Keynote, Casual, Explanation, Networking |

Each metric is scored 0–10. **Overall score** (0–100) is set holistically by the AI — it is not a formula.

### Audio Features (Sent to AI)

The AI also receives:
- Pitch mean, standard deviation, and range (monotone vs. dynamic indicator)
- RMS energy and variation (enthusiasm/engagement indicator)
- Speech-to-silence ratio
- Longest pause duration and position
- Speaking rate variation across 10-second windows

This gives the AI a real picture of your delivery — not just what you said, but how you said it.

### Tone & Emotion Analysis (Pro)

Pro subscribers receive an additional **Tone Analysis** card in results. Your audio is analyzed for emotional signals — dominant emotion, nervousness, enthusiasm, and an emotion arc across the session. This is processed by an AI emotion model (see Privacy section below).

---

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
| First Session | Complete any session |
| 7-Day Streak | Maintain a 7-day streak |
| Score 80+ | Score 80 or above in any session |
| 30 Sessions | Complete 30 total sessions |
| Interview Pro | Complete 10 interview-mode sessions |
| Rank 5 (Rhetorician) | Reach Rank 5 through XP |
| Zero Fillers | Complete a session with no detected filler words |
| Master | Reach Rank 10 through XP |

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
  - **Daily Reminder** — toggle a daily notification to keep your streak alive
  - **Sound Effects** — toggle in-app audio feedback
  - **Privacy Policy** and **Terms of Service** links
  - **Reset All Data** — permanently wipes all sessions and progress

---

## League Tab

Shows the current weekly leaderboard. Includes:

- Your current tier badge and rank
- Global leaderboard (all users by weekly XP)
- Friends leaderboard (people who have accepted your friend request)
- Countdown timer to the next weekly reset

### Friends

From the League tab you can:

- **Search users** by display name or username
- **Send a friend request** from any profile
- **Accept or decline** incoming requests
- **Block** users you don't want to see or hear from again — blocked users are hidden from search, leaderboards, and friend suggestions

Friend requests and accepts trigger push notifications if you've granted notification permission.

---

## Offline Behavior

Parlance **requires an internet connection**. If your device goes offline:

- A full-screen "No Internet Connection" screen blocks the app
- The app resumes automatically when connectivity is restored

Practice prompts and tips are bundled on-device and load instantly — the network is only required for AI scoring after you record.

---

## Privacy

- Audio recordings are transcribed on-device using Apple's SFSpeechRecognizer. The audio file is deleted immediately after transcription completes.
- Your transcript and audio features (pitch, pace, energy) are sent to Parlance's AI backend for scoring. They are not stored after the scoring call completes.
- **Pro subscribers only:** your audio is also sent to an AI emotion analysis provider (Hume AI) via Parlance's secure backend to generate the Tone Analysis results. The audio is not retained after analysis.
- Your profile (name, username, location, occupation, XP, level, streak) and session metadata (scores, mode, date, duration) sync to Parlance's Supabase backend so they're available across your devices. Full transcripts and AI feedback paragraphs stay on-device.
- Friend graph (requests, accepts, blocks) is stored server-side so it works across devices.
- **Delete Account** in Settings permanently removes your data from Parlance's servers and signs you out.

---

## Tips for Better Scores

1. **Speak at a measured pace** — 130–160 words per minute is the sweet spot. Rushing hurts clarity.
2. **Use the 3 coaching tips** shown on the loading screen. They're tailored to your prompt.
3. **Vary your pitch** — monotone delivery scores lower. Use emphasis to signal key points.
4. **Avoid fillers** — pause silently instead of saying "um" or "uh." Silence is strength.
5. **Structure your answer** — opening statement, 2–3 supporting points, a clear close.
6. **Don't over-run** — 60–90 seconds is usually enough for most prompts. Tight is better than rambling.
7. **Do the Daily Challenge** — bonus XP and streak credit. No reason to skip it.
