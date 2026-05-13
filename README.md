# Parlance

**AI-powered speech coaching app for iOS.** Think Duolingo, but for speaking.

Get a prompt. Record yourself. Receive AI feedback. Improve. Repeat.

## What It Does

Parlance helps you practice speaking in high-stakes situations — interviews, pitches, presentations, debates — with real-time analysis and AI coaching. Retention is built through gamification, not willpower.

### Practice Modes

| Mode | Focus |
|------|-------|
| Real Life | Practice your actual upcoming conversation — user-defined scenario |
| Job Interview | STAR structure, conciseness, confidence |
| Pitch / Sales | Hook strength, urgency, persuasion |
| Keynote / Talk | Narrative arc, opening impact, pacing |
| Daily Conversation | Clarity, naturalness, holding attention |
| Debate / Argue | Argument flow, rebuttal, logical structure |
| Storytelling | Narrative arc, engagement, vivid detail |
| Explain a Topic | Clarity, analogy use, simplification (sub-categorized by knowledge / industry domain) |
| Negotiation | Persuasion, framing, active listening |
| Impromptu | Quick thinking, coherence under pressure |
| Networking | Introduction, rapport, memorable delivery |

### Key Features

- **AI-powered scoring** — Gemini scores all metrics holistically in one call, using the transcript, per-word timestamps, and on-device audio features (pitch, energy, speaking rate variation)
- **On-device audio analysis** — pitch (autocorrelation) and RMS energy extracted via `vDSP`/Accelerate, giving the AI delivery data beyond text
- **Per-word timestamps** — `SFSpeechRecognizer` segments used to detect pauses, speech-to-silence ratio, and pace variation; passed to AI for timing-aware scoring
- **Mode-specific metrics** — 8–10 metrics per mode via `MetricKey` enum, not a one-size-fits-all formula
- **Tone & emotion analysis (Pro)** — audio analyzed by Hume AI (via Cloudflare Worker) for emotional signals: dominant emotion, nervousness, enthusiasm, and an emotion arc across the session
- **1,700+ practice prompts** — bundled offline, zero API cost for question generation
- **Real Life mode** — paste the actual situation you're preparing for; the app validates the scenario and generates a session around it
- **Gamification** — XP, 10-level ranking system, daily streaks, achievements
- **Daily challenge** — one featured session per day with bonus XP
- **Weekly league** — tiered leaderboard (Bronze through Diamond)
- **Account + cloud sync** — Apple Sign-In via Supabase; profile, session history, and friend graph sync across devices
- **Social** — search users by username, send/accept friend requests, friends leaderboard, block users
- **Push notifications** — daily reminders and social events (friend requests / accepts) via APNs
- **Network gate** — full-screen offline blocker via `NWPathMonitor`; AI scoring requires connectivity
- **Scoring retry** — if the AI call fails after recording, a dedicated error screen lets users retry scoring without re-recording
- **Pro subscription** — StoreKit 2; unlocks all modes, Advanced/Expert tiers, emotion analysis, and unlimited daily sessions

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
- **Local persistence:** SwiftData (on-device SQLite)
- **Auth + cloud sync:** Supabase (Apple Sign-In, profiles, user_stats, friendships, push tokens, session sync)
- **Audio:** AVFoundation recording, AVAudioEngine tap for feature extraction, SFSpeechRecognizer transcription
- **AI:** Gemini via Cloudflare Worker proxy — one scoring call per session; Pro users also get Hume AI emotion analysis in parallel; Real Life mode validates user scenarios via Gemini
- **Audio features:** Accelerate / vDSP (pitch autocorrelation, RMS energy)
- **Push:** APNs token registration via Supabase Edge Functions
- **Networking:** NWPathMonitor for connectivity gating
- **Questions:** Static bundled JSON (~1,750 prompts across 10 modes × 5 difficulty bands) — works fully offline

## Project Structure

```
ParlanceApp/                       ← main app source + Parlance.xcodeproj
├── App/                   ← ContentView (root TabView), SplashView, ActiveSessionState, AppDelegate, DeepLinkRouter
├── Core/
│   ├── AI/                ← ClaudeClient (scoring), FeedbackGenerator, HumeClient (emotion), RealLifeScenarioValidator (local rules), RealLifeTipsClient
│   ├── Models/            ← SwiftData models + MetricKey, ScoringResult, EmotionResult, AudioFeatures, TimingStats, ExplanationCategory, SupabaseModels
│   └── Services/          ← AudioRecorder, AudioFeatureExtractor, SpeechTranscriber, SubscriptionService, PersistenceService, NetworkMonitor, SupabaseManager, AuthService, SyncService, SocialService, PushTokenService, RealLifeScenarioHistoryStore, ProfanityFilter, SoundService
├── Features/
│   ├── Auth/              ← AuthView (Apple Sign-In), AuthProfileSetupView, welcome / welcome-back / account-deleted splash views
│   ├── Home/              ← daily challenge, mode grid, XP, tier picker
│   ├── Session/           ← LoadingView, CountdownView, RecordingView, SessionCoordinator
│   ├── RealLife/          ← Real Life scenario setup + validation
│   ├── Results/           ← post-session scores, AI feedback, filler transcript, ToneAnalysisCard (Pro)
│   ├── Progress/          ← score history, skill trends, period filter, per-session detail
│   ├── League/            ← social tab, friends + global leaderboards, tier info
│   ├── Paywall/           ← PaywallView (StoreKit 2 purchase)
│   ├── Profile/           ← ProfileView (level/XP badge, tappable rank card), ProfileEditSheet, SettingsSheet
│   ├── NoConnection/      ← full-screen offline gate
│   ├── Resources/         ← questions.json (~1,750 prompts) + bundled fonts
│   └── Setup/             ← first-launch onboarding
└── UI/
    ├── Components/        ← SafariView, AnimatedWaveformView, PillBadge, ProgressBar, XPProgressBar, SectionHeader
    ├── Extensions/        ← Color+Hex, View+CardStyle, View+Shimmer, Score+Color
    └── Theme/             ← AppColors (dynamic light/dark), AppTheme, AppFonts, AppConstants
ParlanceTests/
ParlanceUITests/
```

## Setup

1. Open `ParlanceApp/Parlance.xcodeproj` in Xcode 26+
2. Build and run on iOS 17+ simulator or device
3. For AI feedback: deploy the Cloudflare Worker and set `ParlanceAPIBaseURL` in Info.plist
4. Supabase URL + anon key are embedded in `SupabaseManager.swift`; RLS policies enforce access control

The Cloudflare Worker (`cloudflare-worker/`) is gitignored and deployed separately. It exposes three endpoints:
- `POST /feedback` — Gemini scoring (requires `GEMINI_API_KEY` worker secret)
- `POST /emotion` — Hume AI emotion analysis for Pro users (requires `HUME_API_KEY` worker secret)
- `POST /real-life/tips` — AI-generated coaching tips for Real Life scenarios (`RealLifeTipsClient`)

## Docs

```
_docs/
├── plans/        ← implementation plans (step-by-step, pre-code)
├── specs/        ← feature specifications (detailed behavior per screen/feature)
├── decisions/    ← architecture decision records
└── guides/       ← engineering guide + user-facing guide
```

## Key Differentiators

1. **Mode-specific AI** — feedback knows the difference between interview vs. pitch vs. keynote
2. **Structure coaching** — not just delivery mechanics; actual argument flow and hook strength
3. **Consumer-first** — Yoodli went enterprise; this is the individual user's premium home
4. **Gamification done right** — streaks, leagues, XP aren't bolted on; they're the reason to return
5. **Social layer** — friends leaderboards; no competitor has this
