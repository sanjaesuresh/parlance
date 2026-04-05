# Parlance — MVP Product Specification

> This document is the source of truth for the Parlance iOS app. Use it as context when generating implementation plans. It covers product goals, every screen, every feature, AI behavior, gamification, and MVP scope.
>
> **Last reviewed:** 2026-04-03 — PM audit applied. Gap audit pass 2 applied: scoring formulas, word lists, timezone consistency, daily challenge seeding, data model, and 16 additional gaps resolved.

---

## 1. What This App Is

Parlance is a consumer iOS speech coaching app. Think Duolingo but for speaking. The core loop: get a prompt → record yourself speaking → receive AI feedback → improve → repeat. Retention is built through gamification, not willpower.

**The problem:** Most people are bad at speaking in high-stakes situations — interviews, pitches, presentations — because they've never actually practiced out loud. Existing apps either focus only on delivery mechanics (pace, fillers) without coaching argument structure, or they've gone enterprise (Yoodli). The individual user has no premium home.

**Key differentiators:**
1. Mode-specific AI — feedback knows the difference between a good interview answer vs. a good pitch vs. a good keynote
2. Structure coaching — not just delivery mechanics; actual argument flow, hook quality, whether the point lands
3. Consumer-first — Yoodli went enterprise; this is the individual user's premium product
4. Gamification done right — streaks, leagues, XP, daily challenge; they're the reason to return tomorrow
5. Social layer — friends leaderboard; no competitor has this

---

## 2. Platform & Tech Stack

- **Platform:** iOS (SwiftUI, iPhone-first, 390×844pt viewport)
- **Audio:** AVFoundation for recording; SFSpeechRecognizer (SpeechKit) for transcription
- **Questions:** Static question bank — pre-generated offline, stored as a bundled JSON asset in the app. Zero API cost, zero latency, works fully offline. See §12.
- **AI Model:** `claude-haiku-4-5-20251001` — used exclusively for post-session feedback. Chosen for: reliable structured JSON output, 597ms median TTFT, and ~$0.0006/session cost.
- **AI Gateway:** Lightweight Cloudflare Worker proxy (single endpoint, no database, free tier covers 100k req/day). The Claude API key lives server-side only — never in the app binary.
- **Persistence:** SwiftData for local session history, user state, XP, streaks
- **Auth:** None for MVP — single local user profile, set up on first launch
- **Min iOS:** 17.0 (required for SwiftData)
- **Orientation:** Portrait-only. Landscape not supported — lock via `UISupportedInterfaceOrientations` in Info.plist.

---

## 3. API Cost & Rate Limiting

### Per-Session Cost
Each session makes **1 API call** (post-session feedback only — questions come from the static bank):
- ~400 tokens input + ~150 tokens output per feedback call
- Cost per session: ~$0.0006 at Haiku 4.5 pricing
- At 1k MAU × 3 sessions/day: ~$55/month
- At 10k MAU × 3 sessions/day: ~$550/month

### Rate Limiting
- **Client-side cap:** 20 sessions per device per day. Enforced in app before the feedback API call. Shows a friendly message: "You've hit your daily limit — come back tomorrow to keep your streak going."
- **Proxy-level cap (fast follow):** Cloudflare Worker rate-limits by device UUID header. Not required for launch but add before any public launch.
- **Kill switch:** Cloudflare Worker can be toggled off without an app release. If the proxy is unreachable, the session completes normally and the AI Coach Feedback card shows the failure state (§10.4). Questions are unaffected — they come from the local bank.

### API Key Security
- API key stored as environment variable in Cloudflare Worker — never in app binary or any client-accessible config.
- App communicates only with the proxy URL (e.g. `https://parlance-api.yourdomain.workers.dev`).
- Proxy URL stored in `Info.plist` under `ParlanceAPIBaseURL` — can be swapped without a code change.

---

## 4. Design System

### Color Palette (Dark Theme Only)
| Token | Value | Usage |
|-------|-------|-------|
| `bg` | `#0D0D0D` | App background |
| `card` | `#111111` | Card surfaces |
| `border` | `#1E1E1E` | Card borders, dividers |
| `gold` | `#E8A838` | Primary accent — XP, streaks, recording active, daily challenge |
| `red` | `#E05A4E` | Warnings, stop recording, poor metrics |
| `purple` | `#7B68EE` | Keynote mode accent |
| `teal` | `#3BB5A0` | Positive metrics, casual mode accent |
| `text` | `#FFFFFF` | Primary text |
| `sub` | `#888888` | Secondary/subtext |

### Typography
- **Display / scores / timer:** Playfair Display (serif)
- **Body / labels / buttons:** DM Sans

### Components
- Card border-radius: 18pt
- Pill badges (rounded capsule)
- Animated SVG score ring
- Animated XP progress bar
- Animated waveform (38 bars)

---

## 5. Navigation Structure

### Bottom Tab Bar (4 tabs)
Persistent at the bottom. Hidden during active sessions (loading → recording → results).

| Tab | Icon | Purpose |
|-----|------|---------|
| Home | house | Daily challenge, mode grid, XP bar |
| Progress | chart.bar | Score history, skill trends, milestones |
| League | trophy | Weekly stats, tier badge, invite friends |
| Profile | person | Achievements, settings |

### Session Overlay
When a session starts, the tab bar hides and the session flow (Loading → Recording → Results) takes over the full screen. Returning home from Results restores the tab bar.

---

## 6. First Launch Setup

Shown once on first launch. No skip option — name is required for the greeting and profile.

**Screen layout:**
1. App logo + tagline: "Your personal speech coach."
2. Name field: "What should we call you?" (plain text input, max 30 chars)
3. Avatar picker: horizontal scroll of 12 emoji options (🎤 🧠 🚀 💼 🦁 🔥 ⚡ 🎯 🏆 💡 🌟 🎭)
4. CTA button: "Let's go" — disabled until name is non-empty
5. Footer: "Your voice data stays private. [Privacy Policy]" — tappable link

**Behavior:**
- On submit: save User record to SwiftData, mark `hasCompletedSetup = true`
- Never shown again once setup is complete
- Privacy Policy link opens in-app SafariViewController (URL configured in Info.plist)

---

## 7. Permissions Flow

Both permissions are requested contextually — not on first launch. Users grant permissions when it's clear why they're needed.

### Microphone Permission
- **When requested:** User taps the record button for the first time
- **Pre-prompt:** A brief in-app sheet appears before the system dialog: "Parlance needs your microphone to record your practice sessions. Your audio is processed on-device." — CTA: "Continue"
- **If denied:** Recording button shows a lock icon; tapping shows: "Microphone access is required to record. Go to Settings → Privacy → Microphone to enable it." with a "Open Settings" button.

### Speech Recognition Permission
- **When requested:** Immediately after microphone permission is granted (same first session)
- **Pre-prompt:** "To analyze your speech, Parlance uses on-device transcription. Your transcript is never stored beyond your session." — CTA: "Enable"
- **If denied:** App records audio but disables metric analysis. Results screen shows score ring hidden, replaced by: "Enable speech recognition in Settings to unlock your full scorecard." Transcript-dependent metrics (filler words, pace, clarity, structure, vocabulary strength) show as "—". AI coach feedback still fires using duration and mode only.

---

## 8. The Four Practice Modes

Each mode has its own color accent, question type, and feedback lens.

### 8.1 Job Interview (`interview`)
- **Accent:** Gold (`#E8A838`)
- **Question types:** Behavioral (STAR), situational, values-based, strengths/weaknesses, motivation
- **Feedback focus:** STAR structure compliance, conciseness, avoiding rambling, confidence signals, specific over vague
- **Example prompts by level:**
  - L1–2: "Tell me about yourself."
  - L3–4: "Describe a time you handled a conflict at work."
  - L5–6: "Tell me about a project where you had to influence without authority."
  - L7–8: "Describe a situation where you failed. What would you do differently?"
  - L9–10: "Why do you want this specific role at this specific company, given your background suggests you'd be more successful elsewhere?"

### 8.2 Pitch / Sales (`pitch`)
- **Accent:** Orange-gold
- **Question types:** Investor pitch, cold outreach, demo scenario, skeptic handling, one-liner
- **Feedback focus:** Hook strength, urgency creation, handling objections, persuasion clarity, call to action
- **Example prompts by level:**
  - L1–2: "Pitch your favorite app in 60 seconds."
  - L3–4: "You have 90 seconds with a skeptical investor — pitch your startup."
  - L5–6: "A prospect says 'We already have a solution for that.' Respond."
  - L7–8: "Pitch a product to someone who has explicitly said they're not interested."
  - L9–10: "Make the case for a controversial business decision to a board that strongly opposes it."

### 8.3 Keynote / Talk (`keynote`)
- **Accent:** Purple (`#7B68EE`)
- **Question types:** TED-style talks, conference presentations, toasts, panel answers
- **Feedback focus:** Narrative arc, opening impact (hook in first 10 seconds), pacing, stage presence, landing the point
- **Example prompts by level:**
  - L1–2: "Give a 1-minute toast at a friend's birthday."
  - L3–4: "Open a 5-minute talk on a topic you know well."
  - L5–6: "Give the opening 2 minutes of a TED talk on a complex idea."
  - L7–8: "Answer a hostile panel question live without notes."
  - L9–10: "Give a 3-minute closing keynote argument that changes someone's mind."

### 8.4 Daily Convo (`casual`)
- **Accent:** Teal (`#3BB5A0`)
- **Question types:** Explaining ideas to non-experts, impromptu debate, persuasion scenarios
- **Feedback focus:** Clarity, naturalness, holding attention without a script, accessible language
- **Example prompts by level:**
  - L1–2: "Explain what you do for work to someone who's never heard of your field."
  - L3–4: "Convince a friend to try something they've always been resistant to."
  - L5–6: "Explain a complex topic (your choice) to a 10-year-old."
  - L7–8: "Argue both sides of a controversial topic — switch sides halfway through."
  - L9–10: "Hold a conversation about an ambiguous ethical dilemma with no right answer."

---

## 9. Difficulty System

### 10 Levels, 5 Tiers

| Level | Name | Tier |
|-------|------|------|
| 1 | Nervous Novice | Starter |
| 2 | First-Timer | Starter |
| 3 | Getting Warmed Up | Challenging |
| 4 | Emerging Orator | Challenging |
| 5 | Confident Communicator | Intermediate |
| 6 | Polished Speaker | Intermediate |
| 7 | Compelling Storyteller | Advanced |
| 8 | Stage Commander | Advanced |
| 9 | Master Presenter | Expert |
| 10 | Elite Orator | Expert |

### Level Behavior
- **L1–2 (Starter):** Broad, personal, low-stakes prompts. Feedback is encouraging and focuses on basics.
- **L3–4 (Challenging):** Structured responses required. Behavioral and situational questions appear.
- **L5–6 (Intermediate):** Multi-layered prompts requiring emotional intelligence and nuance.
- **L7–8 (Advanced):** High-pressure, unexpected angles. On-the-spot thinking required.
- **L9–10 (Expert):** Ambiguous prompts with no right answer. Pure conviction and articulation tested.

### Difficulty Selection
- Manual slider on Home tab (levels 1–10)
- **Default for new users:** Level 1 (Nervous Novice)
- Future: Adaptive — app auto-adjusts based on score trends (not in MVP)

---

## 10. Session Flow (Detailed)

### 10.1 Home → Mode Select
User taps a mode card or the Daily Challenge card. Both trigger the session flow.

### 10.2 Loading Screen
- Full-screen overlay in mode's accent color scheme
- Animated concentric pulsing orbs
- Status text cycles every 1.5s: "Calibrating to your level… / Selecting your challenge… / Loading tips… / Almost ready…"
- Selects a question from the local question bank (instant, no network call — see §12)
- Shows user's current level name and difficulty tier
- Loading screen duration is purely cosmetic/UX (500ms minimum) — question is ready immediately
- **Question bank error state:** If the bundled JSON fails to parse (corrupt asset), the loading screen shows: "Something went wrong loading your session. Please restart the app." This state should never occur in production — add a unit test at build time that parses the JSON and asserts a minimum question count per mode/band.

### 10.3 Recording Screen
**Layout (top → bottom):**
1. **Prompt card** — question text in Playfair Display serif, target duration pill ("~90 sec"), difficulty badge (level name)
2. **Three coaching tips** — numbered list, specific to this question
3. **Animated waveform** — 38 bars, wave animation active when recording, static/dim when idle
4. **Timer** — large Playfair Display; gold when recording, dim grey when idle
5. **Mic button** — large circular; gold ▶ to start, red ⬛ to stop; glowing ring animation when active

**Behavior:**
- Timer starts when user taps ▶
- After 8 seconds of recording: inline tip appears — "Stay deliberate — don't rush to fill silence"
- User taps ⬛ to stop; cannot stop before 5 seconds (prevents accidental taps)
- **Maximum recording duration: 3 minutes (180 seconds).** At 2:45, a subtle banner appears: "Wrapping up in 15s…". At 3:00, recording auto-stops identically to a manual stop.
- After stop: brief 1s processing state, then transition to Results

**Audio recording:**
- AVAudioSession configured for recording
- AVAudioRecorder saves .m4a to temp directory
- SFSpeechRecognizer transcribes in real-time or post-recording
- Transcript used for metric analysis

### 10.4 Results Screen
**Layout (top → bottom):**

1. **XP Toast** — slides up from bottom on enter animation (+120 XP, or +200 for daily challenge), dismisses after 2s
2. **Score Ring** — animated SVG circle; color: teal ≥80, gold ≥60, red <60; score number in center in Playfair; fills on appear
3. **Headline verdict** — one line below ring: "Strong performance." / "Getting there." / "Room to grow."
4. **Question recap card** — italic text showing the question they answered
5. **AI Coach Feedback** — gold-bordered dark card; one paragraph of specific, contextual feedback (from Claude API). See failure state below.
6. **Best Moment / Worst Moment** — two side-by-side cards; each with timestamp (e.g., "0:23") and a 1-sentence transcript snippet
7. **Metric Breakdown** — 5 cards in a vertical list (see §11)
8. **Up Next card** — bottom CTA: "Try Again" (new question, same mode) or "Home"

**AI Feedback failure state:** If the feedback API call fails (network error, timeout >8s, or proxy error), the AI Coach Feedback card shows: "Coach feedback unavailable right now. Your scores and metrics are still saved." with a subtle retry icon. Tapping retry re-fires the single feedback call. The rest of the Results screen renders normally — a feedback failure never blocks XP, metrics, or score display.

---

## 11. Speech Analysis (5 Metrics)

All analysis runs against the transcript. In MVP, this is approximated using word counts and heuristic rules.

### Overall Score Formula
Each of the 5 metrics returns a score on a **0–10 scale**. The overall session score is:

```
overallScore = round(mean(fillerScore, paceScore, clarityScore, structureScore, vocabularyScore) × 10)
```

Result is 0–100 (integer). This is the value stored in `Session.overallScore` and shown in the score ring.

### 11.1 Filler Words
- Count occurrences of: "um", "uh", "like" (casual use), "you know", "sort of", "kind of", "basically", "literally"
- **Scoring formula:** `score = max(0, 10 - fillerCount)` — each filler word deducts 1 point. 10+ fillers = 0/10.
- Tip: specific to which filler word appeared most

### 11.2 Pace
- Calculate WPM from word count ÷ recording duration
- **Tiered scoring:**
  - 130–160 WPM: **10/10** (ideal range)
  - 110–129 WPM or 161–185 WPM: **7/10** (acceptable but flagged)
  - <110 WPM or >185 WPM: **4/10** (out of range)
- Tip: "too slow — increase energy and vary your pace" (<110), "too fast — slow down and breathe" (>185), or "slightly fast/slow" (borderline bands)

### 11.3 Clarity
- Approximate: split transcript into sentences (split on `.`, `!`, `?`)
- Sentences >25 words: each deducts 1 point
- Sentences <5 words (fragments): each deducts 0.5 points
- **Scoring formula:** `score = max(0, 10 - longSentencePenalty - fragmentPenalty)`
- Tip: "Your sentences are running long — aim for under 20 words per idea" (if long sentence penalty dominates) or "Some of your responses were cut short — try developing each point fully" (if fragment penalty dominates)

### 11.4 Structure
- Check for:
  - **Opening signal** (substring match, case-insensitive): "the key thing", "what i'd say", "to answer that", "let me start", "the short answer", "first and foremost", "to begin"
  - **Middle / development**: response body ≥ 30 words after the first sentence (proxy for having a substantive middle)
  - **Closing signal** (substring match): "so in summary", "the bottom line", "to wrap up", "in conclusion", "overall", "to summarize", "the takeaway"
- **Scoring formula:** Start at 10. Missing opening: −3. Missing closing: −3. Middle too thin (<30 words): −2. Minimum 0.
- **STAR compliance (interview mode only):** Bonus +1 (max 10) if all 4 STAR components are detected:
  - Situation: "when i", "at my previous", "in that role", "at [company]", "in [year/quarter]"
  - Task: "i was responsible for", "my goal was", "i needed to", "i had to"
  - Action: "i decided", "i then", "what i did", "i reached out", "i built", "i led"
  - Result: "as a result", "this led to", "the outcome was", "we achieved", "it resulted in", "by the end"

### 11.5 Vocabulary Strength
*(Replaces the placeholder "Energy" metric — accurately measurable from text alone)*
- Scores the richness and precision of word choice

**Weak-word list** (penalized when used): `stuff`, `things`, `whatever`, `kind of`, `sort of`, `a lot`, `very`, `really`, `basically`, `just`, `good`, `bad`, `big`, `nice`, `get`, `got`, `thing`

**Strong verb signals** (rewarded): specific action verbs vs. generic ones. Strong: `built`, `launched`, `reduced`, `increased`, `negotiated`, `convinced`, `designed`, `led`, `delivered`, `solved`, `implemented`, `grew`, `cut`, `pitched`, `drove`. Generic (not rewarded): `did`, `made`, `got`, `went`, `had`, `was`, `said`.

**Scoring formula:**
```
score = 7  (base)
+ 1 if strong verb ratio > 15% of all verbs (strong verb count / total verb count)
+ 1 if type-token ratio (unique words / total words) > 0.60
+ 1 if no weak words used
- min(4, uniqueWeakWordsUsed × 1)   (−1 per unique weak word, capped at −4)
- 1 if same content word repeated >3× in the session
- 1 if passive constructions >25% of sentences ("was [verb]ed", "were [verb]ed")
score = clamp(score, 0, 10)
```
- Tip: specific to the dominant weakness detected (e.g., "Try replacing 'things' with specific nouns", "Use stronger action verbs — 'drove' instead of 'did'")

### Best / Worst Moment Detection
- Split transcript into 10-second segments
- Best moment: segment with highest ratio of strong-signal words (from strong verb list) and lowest filler density
- Worst moment: segment with most fillers or longest run-on sentence
- Return timestamp (e.g., "0:30") and the sentence from that segment
- **Short recording fallback:** If the recording is under 20 seconds (fewer than 2 complete 10-second segments), show only the Best Moment card using the single available segment. Omit the Worst Moment card entirely.

---

## 12. Question Bank & AI Integration

### 12.1 Question Bank (Static, Bundled)

Questions are **pre-generated offline** (one-time cost), quality-controlled, and bundled into the app as a JSON asset. No API call is made at session start.

**Structure:**
- 4 modes × 5 difficulty bands × minimum 20 questions each = **400+ questions** at launch
- Each question tagged with: `mode`, `difficultyBand` (1–2, 3–4, 5–6, 7–8, 9–10), `id`
- Each question includes: `question`, `tips` (3 items), `targetDuration`, `difficultyNote`

**Selection logic:**
1. Filter questions by current mode + difficulty band
2. Exclude any question IDs in the user's local history (stored in SwiftData)
3. Select randomly from remaining eligible questions
4. If all questions in a band have been seen: reset that band's history and re-use (users will cycle back only after exhausting the pool)

**History tracking:**
- `SeenQuestion` records stored in SwiftData: `questionId`, `mode`, `date`
- Recency window: last 50 sessions per mode (so older questions can re-appear naturally)

**No fallback needed** — the bank is always available offline. The loading screen never waits on a network call.

**Updating the bank post-launch:**
- New question packs can ship as app updates or (post-MVP) fetched as a JSON asset from a CDN with local caching. Not required for v1.

### 12.2 AI Model
`claude-haiku-4-5-20251001` used exclusively for post-session feedback. All calls go through the Cloudflare Worker proxy — the app never holds the API key.

### 12.3 AI Coach Feedback

**When:** After speech analysis completes, fired in parallel with Results screen render. Does not block the screen — score ring, metrics, and XP toast render immediately. The AI Coach card shows a subtle shimmer skeleton loader until feedback arrives.

**API call:**
- Sends: mode, level, question text, overall score, all 5 metric scores, recording duration, transcript (or first 400 words), any detected best/worst moment snippets
- System prompt instructs Claude to return one paragraph of specific, contextual coaching

**Response format:**
```json
{
  "feedback": "string — one paragraph of coaching"
}
```

**Feedback must:**
- Reference the actual question asked
- Acknowledge what went well AND what to improve
- Be mode-aware (interviewer vs. pitch judge vs. audience)
- Be level-appropriate (level 2 gets gentler, level 9 gets rigorous)
- Avoid generic phrases like "Great job!" or "Keep practicing!"

**Failure handling:** See §10.4 Results Screen failure state.

---

## 13. Gamification System

### 13.1 XP
- Base XP per session: +120
- Daily Challenge bonus: +200 (on top of base)
- Stored locally, persists across sessions
- Powers rank progression (see below)

### 13.2 Ranks *(formerly "Levels" — renamed to avoid collision with Difficulty Levels)*
XP progression uses a separate **Rank** system to distinguish from the Difficulty Level system (§9).

| Rank | Name | XP Required |
|------|------|-------------|
| 1 | Newcomer | 0 |
| 2 | Apprentice | 500 |
| 3 | Practitioner | 1,200 |
| 4 | Communicator | 2,500 |
| 5 | Rhetorician | 4,500 |
| 6 | Debater | 7,000 |
| 7 | Presenter | 10,500 |
| 8 | Orator | 15,000 |
| 9 | Virtuoso | 21,000 |
| 10 | Master | 30,000 |

- **Rank-up:** Brief celebration animation on home screen (gold burst + rank name display)
- Home XP bar shows: "Rank 4 — Communicator · 2,100 / 2,500 XP"
- Profile shows rank badge separately from difficulty level
- **Max rank state (Rank 10 — Master):** XP bar fills completely and shows "Rank 10 · Master · MAX" as a static gold bar with no progress indicator. No further rank-up animation fires. XP continues to accumulate for weekly league tier calculations.

### 13.3 Streaks
- Daily streak increments when user completes ≥1 session per calendar day
- **Timezone: all streak calculations use the local device calendar.** "Day" = midnight-to-midnight in the device's current timezone. No UTC normalization — this is a local-only app.
- Streak shown prominently on home header with 🔥
- Streak resets if no session completed in a calendar day (local time)
- Future: streak freeze / shield mechanic (post-MVP)

### 13.4 Daily Challenge
- One featured session per day with bonus XP (+200)
- Mode rotates daily: Mon=Interview, Tue=Pitch, Wed=Keynote, Thu=Casual, Fri=Interview, Sat=Pitch, Sun=Keynote
- **Difficulty:** Locked to the user's practice level at the moment the Home tab first loads that day. Changing the difficulty slider after that does not change the daily challenge question for the current day.
- **Question selection:** A random question is selected from the static bank for the current mode + user's locked difficulty band. It is **per-user random** — not a shared "question of the day." Standard question deduplication (SeenQuestion) applies.
- Resets at midnight local device time (consistent with streak timezone, §13.3)
- Gold gradient card on home tab — most prominent CTA

### 13.5 Weekly League
The League tab shows the user's own weekly performance and tier — not a fake global ranking.

**What's real in MVP:**
- User's own weekly XP, session count, best score
- User's tier badge (Bronze → Silver → Gold → Platinum → Diamond), progressed by XP thresholds
- A "Challenge Friends" section with an invite link (deep link to App Store page)

**What's deferred (needs backend):**
- Real global or friends leaderboard
- Tier promotion/demotion based on competitive ranking

**Tier thresholds (weekly XP earned):**
| Tier | Weekly XP |
|------|-----------|
| Bronze | 0–599 |
| Silver | 600–1,499 |
| Gold | 1,500–2,999 |
| Platinum | 3,000–5,999 |
| Diamond | 6,000+ |

The League tab teases the competitive leaderboard concept with UI that shows "Leaderboard unlocks with friends — invite someone to compete" in the empty leaderboard space.

### 13.6 Achievements (Milestones)
| Achievement | Unlock Condition |
|-------------|-----------------|
| First Session | Complete 1 session |
| 7-Day Streak | 7 consecutive days with a session |
| Interview Pro | Complete 10 interview sessions |
| Score 80+ | Achieve overall score ≥80 |
| Zero Fillers | Complete a session with 0 filler words |
| Rank 5 | Reach Rank 5 (Rhetorician) |
| 30 Sessions | Complete 30 total sessions |
| Master | Reach Rank 10 |

Each achievement has locked/unlocked state. Progress shown for multi-step ones (e.g., "12/30 sessions").

---

## 14. Screen Specifications

### 14.1 Home Tab

**Header row:**
- Left: "Good morning, [name]" or greeting based on time of day (morning/afternoon/evening)
- Right: Streak badge 🔥 with day count, avatar emoji

**XP progress bar:**
- Shows current XP / XP needed for next rank
- Animated fill on appear and after each session
- Rank label below bar (e.g., "Rank 4 — Communicator")

**Daily Challenge card:**
- Full-width gold gradient card
- Title: "Daily Challenge" + bonus XP label "+200 XP"
- Subtitle: mode + difficulty (e.g., "Interview · Level 5")
- One-tap starts session

**Difficulty slider:**
- Labeled 1–10
- Current level name shown below slider (e.g., "Level 5 — Confident Communicator")
- Changes persist and affect next session

**Practice Modes grid (2×2):**
| Card | Emoji | Accent |
|------|-------|--------|
| Job Interview | 💼 | Gold |
| Pitch / Sales | 🚀 | Orange |
| Keynote / Talk | 🎤 | Purple |
| Daily Convo | 💬 | Teal |

Each card shows mode name + emoji + tapping starts a session in that mode.

**Weekly Stats row (4 stats):**
- Sessions (this week)
- Avg Score (this week)
- Best Score (this week) *(replaces "Avg Pause" — no pause detection in MVP)*
- Filler word count (this week total)

### 14.2 Progress Tab

**Score history chart:**
- SVG line chart of last 16 sessions
- X-axis: session number; Y-axis: score 0–100
- Color line: teal

**Weekly activity bar chart:**
- Sessions per day for the current week (Mon–Sun)
- Bar height = session count

**Skill trends (5 rows):**
- One row per metric (Filler Words, Pace, Clarity, Structure, Vocabulary Strength)
- Shows: metric name, current avg score, previous week avg, delta arrow (↑ or ↓)

**Mode breakdown:**
- Usage percentage per mode (donut or bar)
- For each mode: best score ever, total session count

**Milestone cards:**
- Shows achievement progress
- Partially complete achievements show progress bar

**Recent Sessions list:**
- Each row: mode icon, overall score, date, duration, difficulty level
- Tapping a row expands to show full metric breakdown

### 14.3 League Tab

**User's Weekly Stats card:**
- Current weekly XP, session count, best score this week
- Tier badge (e.g., "Gold Tier") with XP progress to next tier

**Weekly countdown timer:**
- Countdown to next Monday midnight **local device time** reset (consistent with streak and daily challenge timezone — all resets use local time in this offline app)
- Format: "Resets in 3d 14h 22m"

**Leaderboard section:**
- Empty state with teaser: "Compete with friends — invite someone to unlock the leaderboard"
- Invite button: generates a shareable link (App Store URL)
- No fake global data shown

**Tier info card:**
- Explains tier thresholds (Bronze through Diamond)
- Shows user's current tier and XP needed for next tier

### 14.4 Profile Tab

**Header:**
- Emoji avatar (large)
- Display name
- Join date
- Rank badge (e.g., "Rank 4 · Communicator") — separate from difficulty
- **Streak stats row:** "🔥 12-day streak · Best: 34 days" — shows `currentStreak` and `longestStreak` side by side

**XP progress bar** (same as home but in profile context)

**Achievement grid (2×4):**
- Each cell: achievement icon, name, locked/unlocked visual
- Tapping shows achievement description and unlock condition

**Settings toggles:**
- **Daily Reminder (on/off):** Implemented via `UNUserNotificationCenter` local notifications (not push). Toggling on requests notification permission if not yet granted; if denied, shows: "Enable notifications in Settings to turn on reminders." Default reminder time: 9:00 AM local. Fires a scheduled local notification daily at that time: "Your daily challenge is waiting 🎤". Toggle off cancels all pending Parlance notifications.
- Sound Effects (on/off)
- Auto-Advance after results (on/off)

**Menu items:**
- Notification Preferences
- Set Daily Goal (session count)
- Appearance (future: light/dark toggle)
- Share Progress
- Privacy Policy *(opens in-app SafariViewController)*
- Reset All Data *(destructive — shows confirmation sheet: "This will permanently delete all your sessions, XP, streaks, and achievements. This cannot be undone." with "Reset" in red and "Cancel")*

**Footer:** "Parlance v1.0 · Made with 🎤"

---

## 15. Privacy & Data Handling

### What data leaves the device
- **Transcripts:** Sent to Claude API (via proxy) as part of the feedback prompt. First 400 words only.
- **Question context:** Mode, level, difficulty tier, previous question string.
- **No PII sent:** Display name and avatar are never sent to any API.

### Privacy policy (required for App Store)
- Must be live at a URL before App Store submission
- Must disclose: use of Anthropic API for transcript processing, no sale of data, local-only persistence
- Link shown in first-launch setup screen footer and in Profile → Privacy Policy

### On-device only (never sent anywhere)
- Session audio files — deleted from temp directory after transcription completes (success or failure). If transcription fails, the file is still deleted before the Results screen is displayed; the session is saved with an empty `transcript` string and metrics show as "—".
- XP, streaks, achievements
- Session history
- User display name and avatar

---

## 16. MVP Scope (What to Build First)

### In Scope for MVP
- [ ] First-launch setup screen (name + avatar)
- [ ] Permission request flows (microphone + speech recognition)
- [ ] All 4 tabs with full UI (Home, Progress, League, Profile)
- [ ] Full session flow (Loading → Recording → Results)
- [ ] Real audio recording via AVFoundation
- [ ] Speech-to-text transcription via SFSpeechRecognizer
- [ ] All 5 metric calculations (heuristic approximations)
- [ ] Static question bank (400+ questions, bundled JSON, 4 modes × 5 bands × 20+ each)
- [ ] Question selection with per-user history deduplication (SeenQuestion tracking)
- [ ] AI coach feedback (Claude Haiku via proxy, 1 call/session) with failure state
- [ ] Local persistence: session history, XP, ranks, streaks, achievements
- [ ] Gamification: XP, ranks, streaks, daily challenge (rotating modes), achievements
- [ ] Weekly league (user's own stats + tier badge; no fake global data)
- [ ] Cloudflare Worker proxy (single endpoint, holds API key)
- [ ] 20 sessions/day client-side rate limit
- [ ] Full design system (dark theme, typography, animations)
- [ ] Privacy policy link in setup + profile
- [ ] Daily Reminder local notification (UNUserNotificationCenter, scheduled at 9 AM local time)
- [ ] Question bank JSON unit test (parse + minimum count assertion at build time)

### Out of Scope for MVP
- [ ] Real global / friends leaderboard (needs backend)
- [ ] Tier promotion/demotion based on competitive ranking
- [ ] Pre-event countdown mode
- [ ] Real friend connections / social graph
- [ ] Adaptive difficulty
- [ ] Streak freeze / shield mechanic
- [ ] Subscription / paywall
- [ ] Remote push notifications (APNs)
- [ ] Coach persona customization
- [ ] Backend / server / cloud sync
- [ ] Auth / user accounts
- [ ] Audio-based energy/pitch analysis
- [ ] Proxy-level rate limiting (fast follow after launch)

---

## 17. Local Data Models

**User**
- displayName, avatarEmoji, joinDate
- xp (Int), rank (Int, 1–10), currentStreak (Int), longestStreak (Int)
- lastSessionDate (Date?)
- practiceLevel (Int, 1–10) — current difficulty setting
- hasCompletedSetup (Bool)

**Session**
- id, date, mode (SessionMode enum), difficultyLevel (Int)
- duration (TimeInterval)
- transcript (String) — empty string if transcription failed
- overallScore (Int, 0–100)
- metrics: fillerCount (Int), paceScore (Int), clarityScore (Int), structureScore (Int), vocabularyScore (Int) — each 0–10; −1 if transcription unavailable (displayed as "—")
- question (String), aiCoachFeedback (String?)
- bestMomentTimestamp (TimeInterval), bestMomentText (String) — both empty string if no segments
- worstMomentTimestamp (TimeInterval), worstMomentText (String) — both empty string if fewer than 2 segments
- xpEarned (Int), wasDailyChallenge (Bool)

**Achievement**
- id, name, description, iconName
- isUnlocked (Bool), unlockedDate (Date?)
- progress (Int), goal (Int) — for incremental achievements

**SeenQuestion** (persisted in SwiftData)
- questionId (String), mode (SessionMode), difficultyBand (String, e.g. "1-2", "3-4", "5-6", "7-8", "9-10"), seenAt (Date)
- Used to avoid repeating questions; recency window: last 50 per mode **per difficulty band**
- `difficultyBand` is required for correct deduplication — question selection in §12.1 filters by both mode and band

---

## 18. File & Folder Structure

```
Parlance: AI Speech Coach/
├── App/
│   ├── ParlanceApp.swift             ← @main entry point
│   └── ContentView.swift             ← Root tab view + session overlay
├── Features/
│   ├── Setup/
│   │   └── FirstLaunchSetupView.swift ← Name + avatar picker, shown once
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── DailyChallengeCard.swift
│   │   └── ModeGridView.swift
│   ├── Session/
│   │   ├── SessionCoordinator.swift  ← State machine: loading → recording → done
│   │   ├── LoadingView.swift
│   │   ├── RecordingView.swift
│   │   └── RecordingViewModel.swift
│   ├── Results/
│   │   ├── ResultsView.swift
│   │   ├── ResultsViewModel.swift
│   │   ├── ScoreRingView.swift
│   │   ├── MetricCardView.swift
│   │   └── XPToastView.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ProgressViewModel.swift
│   ├── League/
│   │   ├── LeagueView.swift
│   │   └── LeagueViewModel.swift
│   └── Profile/
│       ├── ProfileView.swift
│       └── ProfileViewModel.swift
├── Core/
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Session.swift
│   │   ├── Achievement.swift
│   │   ├── SeenQuestion.swift        ← SwiftData record for question history
│   │   └── SessionMode.swift        ← enum: interview, pitch, keynote, casual
│   ├── Services/
│   │   ├── AudioRecorder.swift      ← AVFoundation recording
│   │   ├── SpeechTranscriber.swift  ← SFSpeechRecognizer wrapper
│   │   ├── SpeechAnalyzer.swift     ← Metric calculation from transcript
│   │   ├── QuestionBankService.swift ← Loads bundled JSON, selects question, tracks history
│   │   ├── PersistenceService.swift ← SwiftData session + user storage
│   │   ├── GamificationService.swift ← XP, ranks, streaks, achievements
│   │   └── PermissionsService.swift ← Mic + speech recognition permission state
│   └── AI/
│       ├── ClaudeClient.swift        ← URLSession wrapper for proxy
│       └── FeedbackGenerator.swift   ← Coach feedback prompt + parsing
└── UI/
    ├── Components/
    │   ├── AnimatedWaveformView.swift
    │   ├── XPProgressBar.swift
    │   └── PillBadge.swift
    ├── Theme/
    │   ├── AppColors.swift
    │   ├── AppFonts.swift
    │   └── AppConstants.swift
    └── Extensions/
        ├── View+CardStyle.swift
        └── Color+Hex.swift
```

---

## 19. Claude API Prompt Templates

### Coach Feedback System Prompt
```
You are a direct, no-nonsense speech coach. A user just completed a {mode} speaking session at level {level} ({levelName}).

They were asked: "{question}"
Their recording lasted {duration} seconds.
Overall score: {overallScore}/100

Metrics:
- Filler words: {fillerCount} instances
- Pace: {paceScore}/10
- Clarity: {clarityScore}/10
- Structure: {structureScore}/10
- Vocabulary Strength: {vocabularyScore}/10

Transcript excerpt: "{transcriptExcerpt}"

Return ONLY valid JSON in this exact format:
{
  "feedback": "One paragraph of specific, actionable coaching feedback."
}

Your feedback must:
- Reference the actual question they were answering
- Acknowledge one specific strength from their performance
- Identify the most important area to improve
- Be direct and coaching-oriented — no cheerful filler phrases like "Great job!" or "Keep it up!"
- Be calibrated to level {level}: gentler for levels 1-4, rigorous for levels 7-10
- Be mode-aware: {mode} context affects what "good" looks like
```

---

## 20. Launch Readiness Checklist

Before submitting to the App Store:

**Core functionality**
- [ ] All user-visible error states handled (feedback API failure, permission denied, no internet)
- [ ] Question bank JSON asset bundled and loads correctly for all 4 modes × 5 difficulty bands
- [ ] Question history deduplication works (no repeats within recency window)
- [ ] Empty state designed and implemented (Progress tab with 0 sessions, League tab, achievements all locked)
- [ ] Rate limit state handled gracefully (20 sessions/day message)
- [ ] First-launch setup flow works end-to-end

**Permissions & Privacy**
- [ ] Microphone permission pre-prompt and denial state implemented
- [ ] Speech recognition permission pre-prompt and denial state implemented
- [ ] Privacy policy URL live and linked from setup screen + Profile
- [ ] App Privacy section completed in App Store Connect (data types: "Other Diagnostic Data" sent to third-party API)

**Design & Polish**
- [ ] Tested on iPhone SE (smallest supported) and latest iPhone
- [ ] Dynamic Type: all text scales without layout breakage
- [ ] VoiceOver labels set on all interactive elements and score displays
- [ ] Animations don't run when Reduce Motion is enabled (use withAnimation conditionally)
- [ ] App Store screenshots prepared (Home, Recording, Results, League)

**Security**
- [ ] Claude API key confirmed server-side only (not in binary or any client file)
- [ ] Cloudflare Worker deployed and proxy URL set in Info.plist
- [ ] 20 sessions/day client-side rate limit tested

**Analytics (basic)**

**Framework: [TelemetryDeck](https://telemetrydeck.com)** — privacy-first, no personal data collected, GDPR compliant, free tier covers 100k signals/month. Add via Swift Package Manager: `https://github.com/TelemetryDeck/SwiftSDK`. Initialize in `ParlanceApp.swift` with the app identifier from TelemetryDeck dashboard.

- [ ] Session started event (`sessionStarted` — properties: `mode`, `level`)
- [ ] Session completed event (`sessionCompleted` — properties: `mode`, `level`, `overallScore`, `duration`, `wasDailyChallenge`)
- [ ] Daily challenge completed event (`dailyChallengeCompleted` — properties: `mode`, `level`)
- [ ] Rank-up event (`rankUp` — properties: `newRank`, `rankName`)
- [ ] Achievement unlocked event (`achievementUnlocked` — properties: `achievementId`, `achievementName`)

Note: No user-identifying data, names, transcripts, or device IDs should be included in any TelemetryDeck signal.
