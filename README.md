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

- **AI-powered scoring** — Claude Haiku scores all metrics holistically in one call, using the transcript, per-word timestamps, and on-device audio features (pitch, energy, speaking rate variation)
- **On-device audio analysis** — pitch (autocorrelation) and RMS energy extracted via `vDSP`/Accelerate, giving the AI delivery data beyond text
- **Per-word timestamps** — `SFSpeechRecognizer` segments used to detect pauses, speech-to-silence ratio, and pace variation; passed to AI for timing-aware scoring
- **Mode-specific metrics** — 8–10 metrics per mode via `MetricKey` enum, not a one-size-fits-all formula
- **400+ practice prompts** — bundled offline, zero API cost for question generation
- **Gamification** — XP, 10-level ranking system, daily streaks, achievements
- **Daily challenge** — one featured session per day with bonus XP
- **Weekly league** — tiered leaderboard (Bronze through Diamond)
- **Social** — search users by username, view profiles, friends leaderboards
- **Network gate** — full-screen offline blocker via `NWPathMonitor`; AI scoring requires connectivity

### UX

- **5-tier difficulty picker** — Starter / Developing / Confident / Advanced / Expert (replaces 1–10 slider)
- **Honest loading screen** — shows prompt + coaching tips + "Tap when ready"; no fake progress
- **3-2-1 countdown** — buffer between ready and recording; recording auto-starts
- **Target-duration ring** — progress ring around the mic button; turns teal on completion
- **Results delta** — score shown with delta vs. prior average
- **Filler word highlighting** — transcript rendered with fillers marked inline
- **Dark / light / system theme** — `AppTheme` enum stored in UserDefaults, applied via `preferredColorScheme`
- **Profile editing** — display name and username editable via sheet; gear icon opens settings

## Tech Stack

- **Platform:** iOS 17+ (SwiftUI, portrait-only)
- **Persistence:** SwiftData
- **Audio:** AVFoundation recording, AVAudioEngine tap for feature extraction, SFSpeechRecognizer transcription
- **AI:** Claude Haiku via Cloudflare Worker proxy — one call per session (scoring + feedback), ~$0.0006/session
- **Audio features:** Accelerate / vDSP (pitch autocorrelation, RMS energy)
- **Networking:** NWPathMonitor for connectivity gating
- **Questions:** Static bundled JSON — works fully offline

## Project Structure

```
Parlance.xcodeproj/
Parlance/                  ← main app source
├── App/                   ← entry point, app config
├── Core/
│   ├── AI/                ← Claude API integration (ClaudeClient, FeedbackGenerator)
│   ├── Models/            ← SwiftData models + MetricKey, ScoringResult, AudioFeatures, TimingStats, WordSegment
│   └── Services/          ← audio recording, AudioFeatureExtractor, SpeechTranscriber, NetworkMonitor, persistence
├── Features/
│   ├── Home/              ← daily challenge, mode grid, XP, tier picker
│   ├── Session/           ← LoadingView, CountdownView, RecordingView, SessionCoordinator
│   ├── Results/           ← post-session scores, AI feedback, filler transcript, MetricCardView
│   ├── Progress/          ← score history, skill trends, milestones
│   ├── League/            ← social tab, leaderboards, tier info
│   ├── Profile/           ← ProfileView, ProfileEditSheet, settings sheet
│   └── Setup/             ← first-launch onboarding
├── Resources/             ← questions.json (400+ prompts)
└── UI/
    ├── Components/        ← reusable SwiftUI views, NoConnectionView
    ├── Extensions/        ← Color+Hex, View+CardStyle
    └── Theme/             ← AppColors (dynamic light/dark), AppTheme, fonts, constants
ParlanceTests/
ParlanceUITests/
```

## Setup

1. Open `Parlance.xcodeproj` in Xcode 16+
2. Build and run on iOS 17+ simulator or device
3. For AI feedback: deploy the Cloudflare Worker and set `ParlanceAPIBaseURL` in Info.plist

> Note: The Cloudflare Worker source is not included in this repo. Contact the maintainer for the worker code.

## Docs

```
_docs/
├── plans/        ← implementation plans (step-by-step, pre-code)
├── specs/        ← feature specifications (detailed behavior per screen/feature)
├── decisions/    ← architecture decision records
└── user-guide/   ← end-user documentation
```

## Key Differentiators

1. **Mode-specific AI** — feedback knows the difference between interview vs. pitch vs. keynote
2. **Structure coaching** — not just delivery mechanics; actual argument flow and hook strength
3. **Consumer-first** — Yoodli went enterprise; this is the individual user's premium home
4. **Gamification done right** — streaks, leagues, XP aren't bolted on; they're the reason to return
5. **Social layer** — friends leaderboards; no competitor has this
