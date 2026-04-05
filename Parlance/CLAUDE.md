# Parlance — AI Speech Coach

## What This App Is

Parlance is a consumer iOS app that sits at the intersection of Duolingo and a personal speaking coach. The core loop: get a prompt → record yourself → receive AI feedback → improve → repeat. Habit-forming through gamification, not willpower.

**The gap it fills:** Nobody has built the consumer-grade, habit-forming version of a speech coach. Yoodli (the main technical competitor) has gone fully enterprise. Individual users have no premium home. Every competitor focuses on delivery mechanics (pace, fillers) without coaching structure and argumentation — the actual gap between a speech app and a real coach.

---

## Four Practice Modes

| Mode | Prompt Type | Feedback Focus |
|------|-------------|----------------|
| **Job Interview** | Behavioral, situational, values-based | STAR structure, conciseness, confidence signals |
| **Pitch / Sales** | Investor pitches, cold outreach, objection handling | Hook strength, urgency, persuasion |
| **Keynote / Talk** | TED-style, conferences, toasts, panels | Narrative arc, opening impact, pacing |
| **Daily Convo** | Explaining ideas, impromptu, debating | Clarity, naturalness, holding attention |

---

## Difficulty System (10 Levels, 5 Tiers)

| Level | Name |
|-------|------|
| 1–2 | Nervous Novice → First-Timer |
| 3–4 | Getting Warmed Up → Emerging Orator |
| 5–6 | Confident Communicator → Polished Speaker |
| 7–8 | Compelling Storyteller → Stage Commander |
| 9–10 | Master Presenter → Elite Orator |

Users set difficulty manually (default: Level 1 for new users). Adaptive difficulty is planned post-MVP.

---

## Post-Session Analysis (5 Metrics)

Each metric gets a score (0–10), a bar visualization, and a specific tip. Overall score = mean of 5 metrics × 10 (0–100).

- **Filler words** — count of "um," "uh," "like," "you know," etc.; `score = max(0, 10 - fillerCount)`
- **Pace** — words per minute; 130–160 WPM = 10, 110–129/161–185 = 7, outside = 4
- **Clarity** — sentence length heuristic; −1 per sentence >25 words, −0.5 per fragment <5 words
- **Structure** — open/body/close detection + STAR compliance in interview mode
- **Vocabulary Strength** — type-token ratio, strong verbs, avoidance of weak-word list

Also surfaces: overall score, AI coach paragraph, best moment + worst moment (timestamp + transcript snippet), XP earned.

---

## AI Behavior

- **Questions come from a static bundled JSON bank** — pre-generated offline, 400+ questions (4 modes × 5 difficulty bands × 20+ each). Zero API cost, zero latency, works offline. AI is NOT called for question generation.
- Each question includes: 3 coaching tips, target duration, difficulty note
- Questions are deduplicated per user per mode per difficulty band (SeenQuestion tracking, recency window: last 50)
- **AI is used only for post-session feedback** — one Claude Haiku call per session via Cloudflare Worker proxy
- AI feedback is mode-specific, prompt-specific, level-aware — not generic
- Feedback tone: direct and coaching-oriented, not cheerful or vague

---

## Gamification & Retention

- **XP** — earned per session, bonus for daily challenge
- **Levels** — 10 named levels; leveling up changes question difficulty and feedback depth
- **Streaks** — daily streak counter on home screen
- **Daily Challenge** — one featured session per day with bonus XP, resets midnight
- **Weekly League** — leaderboard that resets Monday; tier promotions/demotions (Bronze → Silver → Gold etc.)
- **Friends Leaderboard** — separate from global; competing against people you know
- **Achievements** — one-time unlocks (first session, 7-day streak, 80+ score, 30 sessions, level 5, zero fillers, etc.)
- **Progress tab** — score history chart, skill trends (this week vs last week per metric), mode breakdown, recent sessions

---

## Session Flow

1. Pick a mode (or tap daily challenge)
2. App selects a question from the local static bank (instant, no network call)
3. Loading screen (cosmetic, 500ms minimum) — question is already ready
4. Recording screen: user reads prompt + 3 coaching tips → taps to record
5. Timer runs (max 3 minutes); subtle nudge appears after 8 seconds to stay deliberate
6. Tap to finish (min 5 seconds before stop is enabled)
7. Results: overall score, AI coach paragraph (loaded async via Haiku), best/worst moments, metric breakdown, XP earned
8. One-tap to retry (new question) or return home

---

## Navigation (4 Tabs + Full-Screen Sessions)

- **Home** — daily challenge, XP bar, difficulty selector, mode grid, weekly stats
- **Progress** — score history, skill trends, mode breakdown, milestones, recent sessions
- **League** — weekly countdown, global + friends leaderboards, tier info
- **Profile** — achievements, settings, notifications, daily goal

Sessions (loading → recording → results) take over full screen, hide tab bar until user returns home.

---

## Planned But Not Yet Built

- Pre-event countdown mode ("I have a presentation in 3 days")
- Social graph / friend connections
- Adaptive difficulty (auto-adjusts level based on score trends)
- Streak freeze / shield mechanic
- Subscription / paywall (free vs. premium)
- Onboarding flow
- Remote push notifications via APNs (daily reminder uses local UNUserNotificationCenter in MVP)
- Coach persona customization (strict vs. encouraging tone)

---

## Source Structure Intent

```
Parlance: AI Speech Coach/          ← Xcode source root
├── App/                            ← Entry point, app config, root navigation
├── Features/
│   ├── Home/                       ← Home tab (daily challenge, mode grid, XP)
│   ├── Session/                    ← Full-screen session flow (loading → recording)
│   ├── Results/                    ← Post-session results screen
│   ├── Progress/                   ← Progress tab (charts, milestones)
│   ├── League/                     ← League tab (leaderboards, tier)
│   └── Profile/                    ← Profile tab (achievements, settings)
├── Core/
│   ├── Models/                     ← Data models (Session, User, Question, Metric, etc.)
│   ├── Services/                   ← Audio, speech analysis, persistence, networking
│   └── AI/                         ← Claude API integration (post-session feedback only; questions are static)
└── UI/
    ├── Components/                 ← Reusable SwiftUI components
    ├── Theme/                      ← Colors, typography, design tokens
    └── Extensions/                 ← SwiftUI/Swift extensions
```

---

## Docs Structure

```
_docs/
├── plans/        ← Implementation plans (step-by-step, before touching code)
├── specs/        ← Feature specifications (detailed behavior per screen/feature)
└── decisions/    ← Architecture decision records (why we chose X over Y)
```

---

## Key Differentiators (Never Lose Sight Of These)

1. **Mode-specific AI** — feedback knows the difference between interview vs. pitch vs. keynote
2. **Structure coaching** — not just delivery mechanics; actual argument flow and hook strength
3. **Consumer-first** — Yoodli went enterprise; this is the individual user's premium home
4. **Gamification done right** — streaks, leagues, XP aren't bolted on; they're the reason to return
5. **Social layer** — friends leaderboards; no competitor has this
