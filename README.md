# Parlance

**AI-powered speech coaching app for iOS.** Think Duolingo, but for speaking.

Get a prompt. Record yourself. Receive AI feedback. Improve. Repeat.

## What It Does

Parlance helps you practice speaking in high-stakes situations — interviews, pitches, presentations, debates — with real-time analysis and AI coaching. Retention is built through gamification, not willpower.

### Practice Modes

| Mode | Focus |
|------|-------|
| Job Interview | STAR structure, conciseness, confidence |
| Pitch / Sales | Hook strength, urgency, persuasion |
| Keynote / Talk | Narrative arc, opening impact, pacing |
| Daily Conversation | Clarity, naturalness, holding attention |
| Debate | Argument flow, rebuttal, logical structure |
| Storytelling | Narrative arc, engagement, vivid detail |
| Explanation | Clarity, analogy use, simplification |
| Negotiation | Persuasion, framing, active listening |
| Impromptu | Quick thinking, coherence under pressure |
| Networking | Introduction, rapport, memorable delivery |

### Key Features

- **On-device speech analysis** — filler words, pace, clarity, structure, vocabulary
- **AI coach feedback** — powered by Claude Haiku, mode-specific and level-aware
- **Substance-based scoring** — content quality matters, not just delivery mechanics
- **400+ practice prompts** — bundled offline, zero API cost for questions
- **Gamification** — XP, 10-level ranking system, daily streaks, achievements
- **Daily challenge** — one featured session per day with bonus XP
- **Weekly league** — tiered leaderboard (Bronze through Diamond)
- **Social** — search users by username, view profiles, friend leaderboards

## Tech Stack

- **Platform:** iOS 17+ (SwiftUI, portrait-only)
- **Persistence:** SwiftData
- **Audio:** AVFoundation recording, SFSpeechRecognizer transcription
- **AI:** Claude Haiku via Cloudflare Worker proxy (1 call per session, ~$0.0006/session)
- **Questions:** Static bundled JSON — works fully offline

## Project Structure

```
Parlance.xcodeproj/
Parlance/                  ← main app source
├── App/                   ← entry point, app config
├── Core/
│   ├── AI/                ← Claude API integration
│   ├── Models/            ← SwiftData models
│   └── Services/          ← audio, speech analysis, persistence
├── Features/
│   ├── Home/              ← daily challenge, mode grid, XP
│   ├── Session/           ← recording flow (loading → recording)
│   ├── Results/           ← post-session scores + AI feedback
│   ├── Progress/          ← score history, skill trends
│   ├── League/            ← social tab, leaderboards
│   ├── Profile/           ← achievements, settings
│   └── Setup/             ← first-launch onboarding
├── Resources/             ← questions.json (400+ prompts)
└── UI/
    ├── Components/        ← reusable SwiftUI views
    ├── Extensions/        ← Color+Hex, View+CardStyle
    └── Theme/             ← colors, fonts, constants
ParlanceTests/
ParlanceUITests/
cloudflare-worker/         ← API proxy for Claude Haiku
```

## Setup

1. Open `Parlance.xcodeproj` in Xcode 16+
2. Build and run on iOS 17+ simulator or device
3. For AI feedback: deploy the Cloudflare Worker in `cloudflare-worker/` and set `ParlanceAPIBaseURL` in Info.plist

## Key Differentiators

1. **Mode-specific AI** — feedback knows the difference between interview vs. pitch vs. keynote
2. **Structure coaching** — not just delivery mechanics; actual argument flow and hook strength
3. **Consumer-first** — Yoodli went enterprise; this is the individual user's premium home
4. **Gamification done right** — streaks, leagues, XP aren't bolted on; they're the reason to return
5. **Social layer** — friends leaderboards; no competitor has this
