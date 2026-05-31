# Parlance — Engineering Guide

> Complete technical reference for engineers joining the project. Covers every major system: how sessions work end-to-end, how AI scoring is generated, how the social/league system is built, gamification mechanics, data storage, and known issues.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Session Flow — End to End](#2-session-flow--end-to-end)
3. [Audio Recording](#3-audio-recording)
4. [Speech Transcription & Delivery Analysis](#4-speech-transcription--delivery-analysis)
5. [AI Scoring — How Scores Are Generated](#5-ai-scoring--how-scores-are-generated)
6. [The Cloudflare Worker](#6-the-cloudflare-worker)
7. [Session Model & Data Storage](#7-session-model--data-storage)
8. [Gamification — XP, Ranks, Streaks](#8-gamification--xp-ranks-streaks)
9. [League System](#9-league-system)
10. [Daily Challenge](#10-daily-challenge)
11. [Question Bank](#11-question-bank)
12. [Progress & Skill Trends](#12-progress--skill-trends)
13. [Achievements](#13-achievements)
14. [Social / Leaderboard](#14-social--leaderboard)
15. [Network Gate](#15-network-gate)
16. [Persistence Layer (SwiftData)](#16-persistence-layer-swiftdata)
17. [Auth — Apple Sign-In + Supabase](#17-auth--apple-sign-in--supabase)
18. [Cloud Sync — SyncService](#18-cloud-sync--syncservice)
19. [Real Life Mode](#19-real-life-mode)
20. [Push Notifications](#20-push-notifications)
21. [Known Issues & Gotchas](#21-known-issues--gotchas)
22. [Key Constants](#22-key-constants)
23. [File Map](#23-file-map)

---

## 1. Architecture Overview

**Platform:** iOS 17+ (SwiftUI, portrait-only, no UIKit)
**Local persistence:** SwiftData (on-device SQLite) — source of truth for sessions, transcripts, achievements, and `SeenQuestion` dedupe.
**Cloud backend:** Supabase — auth, profile sync, friend graph, leaderboard feed, push tokens. Local SwiftData is reconciled with server-side `profiles`, `user_stats`, `session_scores`, and friendship tables via `SyncService`.
**AI inference:** Gemini via a Cloudflare Worker proxy (one scoring call per session; Pro users also get an emotion analysis call via Hume AI; Real Life mode fetches AI-generated tips; Progress tab fetches a weekly coach brief).
**Audio:** AVFoundation (recording) + Speech framework (transcription) + Accelerate/vDSP (audio feature extraction).
**Networking:** `Core/Networking/APIClient.swift` wraps a typed `Endpoint<Request, Response>` value. `ClaudeClient`, `HumeClient`, `RealLifeTipsClient`, and `WeeklyBriefClient` all share this layer (one place for base URL, headers, JSON encoding, error mapping).
**Cloudflare Worker** at `AppConstants.apiBaseURL` (set in Info.plist as `ParlanceAPIBaseURL`). Endpoints:
- `POST /feedback` — Gemini scoring (transcript is OpenAI-moderated server-side before scoring)
- `POST /emotion/submit` — submit Hume batch job, returns `jobId` (Pro)
- `POST /emotion/status` — poll for Hume result by `jobId` (Pro)
- `POST /emotion` — legacy synchronous Hume path (kept for back-compat)
- `POST /real-life/tips` — AI-generated tips + prompt for Real Life scenarios
- `POST /coach/weekly-brief` — weekly coach brief (rate-limited; client caches last good copy)
- `POST /delete-user` — cascades account deletion across all user-owned Supabase rows + auth row

`send-push` Edge Function (Supabase) is JWT-authenticated.
**Questions:** Pre-generated static JSON bundled in the app (`ParlanceApp/Features/Resources/questions.json`, **3,192 prompts** across 10 modes × 5 difficulty bands; the bank was rewritten 1,748 → 1,200 to drop forced-fiction prompts, then expanded to 3,192). Zero network calls for question selection.
**Auth:** Sign in with Apple via `AuthService`, which wraps `SupabaseClient.auth`. Account creation is required to use the app; an unauthenticated user sees `AuthView`.
**Social:** Real, server-backed. Friend requests, accepts, blocks, friend leaderboard, user search — all via `SocialService` against Supabase tables with RLS.
**Push:** APNs token registration via `PushTokenService`; tokens are stored in Supabase and consumed by Edge Functions for daily reminders and social events. The `send-push` Edge Function now requires a Supabase JWT — anonymous calls are rejected.
**Subscriptions:** `SubscriptionService` manages StoreKit 2 purchases. `isPro` is the gating flag throughout the app. Receipt fetching uses `AppTransaction` (the iOS 17+ replacement for the deprecated `appStoreReceiptURL`). The DEBUG-only TestFlight/sandbox auto-grant was removed before submission to App Store Review.
**Avatars:** `AvatarService` uploads photos to the Supabase `avatars` bucket at a lowercased-user-id path (required for the RLS UUID-match policy). `AvatarView` renders avatars at every call site with photo + emoji fallback. URLs are cache-busted via `avatar_updated_at` so a new upload invalidates `URLCache`. Server enforces size and MIME limits in addition to RLS `WITH CHECK`.

**Navigation model:** TabView (Home / Progress / League / Profile) as the root, gated behind `AuthView`. Sessions take over full-screen via `SessionCoordinator`, hiding the tab bar until the user returns home. `DeepLinkRouter` handles universal links and push-notification opens.

**State management:** SwiftUI-native (`@State`, `@StateObject`, `@Published`, `@EnvironmentObject`). No Redux, TCA, or third-party state library. ViewModels are `@MainActor ObservableObject`.

---

## 2. Session Flow — End to End

The session lifecycle is managed entirely by `SessionCoordinator.swift` (a SwiftUI view that acts as a state machine). Entry point is `HomeViewModel.startSession()` which builds an `ActiveSessionState` and passes it in.

### State machine phases

```
.loading → .countdown → .recording → .processing → .results(Session)
```

**`.loading`** — `LoadingView` shows for a minimum of 500ms (cosmetic). The question is already selected before this screen appears.

**`.countdown`** — 3-second countdown. When complete, sets `autoStartRecording = true` and transitions to `.recording`.

**`.recording`** — `RecordingView` renders the question, coaching tips, and waveform. `AudioRecorder.startRecording()` begins recording to a temp `.m4a` file at 44100Hz mono AAC. A 50ms timer drives the waveform animation and elapsed time. The "Stop" button is disabled for the first 5 seconds (`AppConstants.minRecordingDuration`). Max duration is 3 minutes (`AppConstants.maxRecordingDuration = 180`). User taps stop → fires `processSession()` → transitions to `.processing`.

**`.processing`** — Spinner with "Analyzing your performance…". All heavy work (transcription, audio analysis, AI call) happens here. This is the only blocking screen in the app.

**`.results(Session)`** — `ResultsView` rendered with the completed `Session` object.

### `processSession()` — the critical path

Called on `@MainActor`. The path branches on `subscription.isPro`:

**Non-Pro path:**
```swift
// 1. Stop recorder, get audio file URL
let audioURL = recorder.stopRecording()

// 2. Parallel: transcribe + extract audio features
async let transcriptionTask = SpeechTranscriber.transcribe(url: audioURL)
async let audioFeaturesTask = AudioFeatureExtractor.extract(from: audioURL)
let (transcriptionResult, audioFeatures) = await (transcriptionTask, audioFeaturesTask)
// emotionResult = nil

// 3. Delete audio file
recorder.deleteRecording()
```

**Pro path (three parallel tasks):**
```swift
// 1. Stop recorder, get audio file URL
let audioURL = recorder.stopRecording()

// 2. Parallel: transcribe + extract audio features + analyze emotion via Hume
async let transcriptionTask = SpeechTranscriber.transcribe(url: audioURL)
async let audioFeaturesTask = AudioFeatureExtractor.extract(from: audioURL)
async let emotionTask = HumeClient.analyzeEmotion(audioURL: audioURL, workerBaseURL: apiURL)
let (transcriptionResult, audioFeatures, emotionResult) = await (transcriptionTask, audioFeaturesTask, emotionTask)

// 3. Delete audio file — the Hume call uploads the file first, so deletion happens after all three tasks
recorder.deleteRecording()
```

**Common suffix (both paths):**
```swift
// 4. Compute timing stats from word-level timestamps
let timingStats = TimingStats.compute(from: segments, totalDuration: duration)

// 5. Count filler words (local, fast)
let fillerCount = SpeechAnalyzer.analyzeFillers(in: transcript).count

// 6. Fetch AI scoring (BLOCKING — user sees spinner until this returns)
// emotionResult is passed through to enrich the scoring prompt for Pro users
let scoringResult = try await FeedbackGenerator.fetchScoring(...)

// 7. Create Session, persist, gamification, → .results
```

The AI scoring call (step 6) can fail. On failure, the coordinator transitions to `.scoringFailed` (retry/discard UI) rather than saving a zero-score session. Retrying from `.scoringFailed` re-enters `scoreAndSave()` directly (skipping re-transcription) using the stored `pendingTranscript`, `pendingTimingStats`, etc.

The results phase distinguishes:
- **Transcription failure** — surfaced separately from scoring failure so the user knows whether to retry the AI call or re-record.
- **Mid-session interruption** — call/route/audio interruptions are reported with a specific message.
- **Dismiss during scoring** — cancels the in-flight scoring task instead of letting it complete in the background.
- **Force-quit recovery** — if a recording file survives a force-quit, the next launch detects it and offers to continue to scoring.

`ResultsView` has been decomposed into phase subviews (loading / failure / scored) so the results screen no longer holds all rendering branches in one body.

### Pre-flight gates

Before sending anything to the AI, `SessionCoordinator` (and the worker) reject:
- Transcripts shorter than the minimum useful length.
- Transcripts containing profanity that exceeds the `ProfanityFilter` threshold.
- Server-side: the `/feedback` worker runs OpenAI's `omni-moderation-latest` on every transcript and refuses to score flagged content. Moderation errors fail open (logged) to avoid stacking a new outage surface on top of Gemini.

---

## 3. Audio Recording

**File:** `ParlanceApp/Core/Services/AudioRecorder.swift`

Records to a UUID-named temp file in `FileManager.default.temporaryDirectory`. Format: MPEG4 AAC, 44100Hz, mono, high quality.

```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

A 50ms `Timer` drives:
- `elapsedTime` — seconds since recording started
- `audioLevels` — sliding window of normalized power values for waveform display (`(averagePower + 50) / 50` mapped to 0–1)
- Auto-stop at `maxRecordingDuration = 180s`

**The audio file is deleted immediately after** transcription and audio feature extraction complete. Nothing is persisted to disk beyond the session.

---

## 4. Speech Transcription & Delivery Analysis

### Transcription — `SpeechTranscriber.swift`

Uses Apple's `SFSpeechRecognizer` with on-device recognition (`requiresOnDeviceRecognition = true`). Returns `TranscriptionResult`:

```swift
struct TranscriptionResult {
    let transcript: String      // formattedString (includes punctuation)
    let segments: [WordSegment] // per-word timestamps from SFTranscriptionSegment
}

struct WordSegment {
    let word: String
    let timestamp: TimeInterval  // seconds from recording start
    let duration: TimeInterval   // how long the word lasted
}
```

Key properties from `SFTranscriptionSegment`: `substring`, `timestamp`, `duration`. These were previously discarded — now retained for timing analysis.

### Timing Analysis — `TimingStats.swift`

Computed from word segments at end of recording:

| Stat | How computed |
|------|-------------|
| `speechToSilenceRatio` | Sum of all word durations / total session duration |
| `longestPauseDuration` | Max gap between consecutive words: `segments[i].timestamp - (segments[i-1].timestamp + segments[i-1].duration)` |
| `longestPauseAfterWord` | Word preceding the longest pause |
| `speakingRateStdDev` | Std dev of word count per 10-second window across session |
| `wordCount` | `segments.count` |

### Audio Feature Extraction — `AudioFeatureExtractor.swift`

Reads the saved `.m4a` file **after** recording ends (synchronous, called from cooperative thread pool via `async let`). Loads entire file into `AVAudioPCMBuffer`, then processes in 2048-sample frames (~46ms at 44100Hz).

**Per frame:**
- RMS energy: `vDSP_rmsqv` on raw PCM samples
- Pitch (voiced frames only, RMS > 0.01): normalized autocorrelation via `vDSP_dotpr`, lag range 85–300Hz, confidence threshold 0.4

**Session-level stats returned (`AudioFeatures`):**

| Stat | Interpretation |
|------|---------------|
| `pitchMeanHz` | Average fundamental frequency |
| `pitchStdDevHz` | High = dynamic delivery; low = monotone |
| `energyMeanRMS` | Overall loudness |
| `energyStdDevRMS` | High = varied energy/enthusiasm |

### Filler Word Detection — `SpeechAnalyzer.swift`

Local regex matching on 19 patterns (um, uh, er, ah, hmm, you know, I mean, like, sort of, kind of, basically, literally, actually, honestly, obviously, you see, the thing is, to be honest, I guess).

Two functions remain (all scoring logic removed in the scoring rework):
- `analyzeFillers(in:) -> FillerResult` — count + most frequent filler, used for the session record
- `fillerRanges(in:) -> [Range<String.Index>]` — character ranges for inline highlighting in the transcript UI

---

## 5. AI Scoring — How Scores Are Generated

### Overview

One Gemini call per session replaces all local heuristic scoring. The call is made synchronously (user sees a spinner) after recording ends. The AI receives the full transcript, timing stats, and audio features (and emotion data for Pro users), and returns scores for every applicable metric plus coaching feedback.

### Metrics system

**7 universal metrics** (all modes):

| Key | Display Name | What it measures |
|-----|-------------|-----------------|
| `fillerWords` | Filler Words | Ums, uhs, verbal crutches |
| `pace` | Pace | Speaking speed and rhythm |
| `clarity` | Clarity | How easy words are to follow |
| `structure` | Structure | Opening, body, closing flow |
| `vocabulary` | Vocabulary | Word choice strength and variety |
| `relevance` | Relevance | Did they answer the question? |
| `comprehensibility` | Comprehensibility | Could a listener follow the reasoning? |

**3 conditional metrics** (mode-specific):

| Key | Display Name | Modes |
|-----|-------------|-------|
| `deliveryConfidence` | Delivery Confidence | Interview, Pitch, Keynote, Debate, Negotiation, Impromptu |
| `persuasiveness` | Persuasiveness | Pitch, Debate, Negotiation, Keynote |
| `engagement` | Engagement | Storytelling, Keynote, Casual, Explanation, Networking |

**Metrics per mode** (defined in `MetricKey.metrics(for:)`):

| Mode | Total metrics |
|------|--------------|
| Interview | 8 (universal + deliveryConfidence) |
| Pitch | 9 (universal + deliveryConfidence + persuasiveness) |
| Keynote | 10 (all) |
| Casual | 8 (universal + engagement) |
| Debate | 9 (universal + deliveryConfidence + persuasiveness) |
| Storytelling | 8 (universal + engagement) |
| Explanation | 8 (universal + engagement) |
| Negotiation | 9 (universal + deliveryConfidence + persuasiveness) |
| Impromptu | 8 (universal + deliveryConfidence) |
| Networking | 8 (universal + engagement) |

### Prompt construction — `FeedbackGenerator.buildPrompt()`

The prompt is built dynamically per session. Key inputs:

```
Mode: Job Interview
Level: 5 (Confident Communicator)
Tone: be direct and specific — name what worked and what to fix

Question asked: "..."
Transcript: "..."

Session data:
- Word count: 142
- Speech-to-silence ratio: 78%
- Longest pause: 2.3s (after "...")
- Speaking rate variation: 1.8 words/10s std dev

Audio delivery:
- Pitch mean: 174Hz, std dev: 38Hz
- Energy mean RMS: 0.412, std dev: 0.187

Score these metrics:
- fillerWords (Filler Words): Ums, uhs, and verbal crutches
- pace (Pace): Speaking speed and rhythm
...
```

**Tone calibration by level:**
- Levels 1–4: constructive, acknowledge effort
- Levels 5–6: direct and specific
- Levels 7–10: rigorous, high standard

### AI response structure

Gemini returns raw JSON (no markdown fences):

```json
{
  "metrics": {
    "fillerWords": { "score": 7, "tip": "You used 'basically' 4 times..." },
    "pace": { "score": 8, "tip": "Good rhythm. Slight rush in closing." },
    ...
  },
  "overallScore": 72,
  "feedback": "One coaching paragraph...",
  "bestMoment": { "quote": "exact phrase", "reason": "why it worked" },
  "worstMoment": { "quote": "exact phrase", "reason": "what to fix" }
}
```

Scores are 0–10 per metric. `overallScore` is 0–100, set holistically by the AI (not a formula). The AI is explicitly told to NOT compute it as an average.

### Failure handling

If the AI call fails for any reason (`URLError`, timeout, bad JSON), the session is still saved with:
- `metrics: [:]` (empty dictionary)
- `overallScore: 0`
- `feedback: nil`
- Empty moment quotes

The results screen handles this gracefully — AI-scored sessions use `session.isAIScored` (true when `metricScoresData != nil`) to decide which UI path to render.

### Network path

```
iOS app → POST /feedback → Cloudflare Worker → POST generativelanguage.googleapis.com (Gemini)
```

Timeout: **30 seconds** (`AppConstants.scoringTimeout`) for the scoring call. The legacy `feedbackTimeout` constant is 8 seconds and still referenced as a constant but not actively used.

### Emotion analysis (Pro only)

```
iOS app → POST /emotion/submit → Cloudflare Worker → Hume AI (submit job)
iOS app → POST /emotion/status (loop)      → Cloudflare Worker → Hume AI (poll)
```

`HumeClient` was reworked to **poll Hume from the client** rather than letting the worker poll. Cloudflare Workers cap a single request at ~30s of wall time, and Hume jobs frequently exceed that. The legacy `POST /emotion` endpoint is still routed for back-compat, but the active path is submit + status loop. The `EmotionResult` model contains:
- `dominantEmotion: String`
- `confidenceScore: Double`
- `nervousnessScore: Double`
- `enthusiasmScore: Double`
- `emotionArc: [String]` — emotion labels over time

This result is passed into `FeedbackGenerator.fetchScoring()` to enrich the AI prompt and is stored on the `Session` model for display in `ToneAnalysisCard`.

---

## 6. The Cloudflare Worker

**File:** `cloudflare-worker/src/index.js` (deployed separately)  
**Deployed to:** URL stored in `Info.plist` as `ParlanceAPIBaseURL` and exposed as `AppConstants.apiBaseURL`  
**Config:** `cloudflare-worker/wrangler.toml`

Endpoints:

### `POST /feedback` — AI scoring

The worker receives `{ messages, transcript }`. It:

1. Runs `moderateTranscript(transcript, OPENAI_API_KEY)` against OpenAI's `omni-moderation-latest`. If flagged, returns a `refused` response and never calls Gemini.
2. Otherwise proxies the messages to Gemini.

The user's free-text portion of the prompt is sandboxed — moderation isolates the transcript from the rest of the prompt so a flagged transcript cannot exfiltrate or mutate the instruction envelope.

Proxies to Gemini's REST API with:
- Model: `gemini-3-flash-preview`
- `maxOutputTokens: 2048`
- Auth: `GEMINI_API_KEY` (Cloudflare Worker secret)

Returns the raw Gemini JSON response. `ClaudeClient.fetchScoring()` decodes it — it tries two paths: raw decode as `ScoringResult`, then unwrapping a `"feedback"` field (legacy compatibility).

### `POST /emotion/submit` + `POST /emotion/status` — Hume AI emotion analysis (Pro only)

`submit` receives multipart form data with the `.m4a` audio file, submits it to Hume AI's batch inference API (prosody model), and returns `{ jobId }`. `status` accepts `{ jobId }` and returns one of:
```json
{
  "status": "COMPLETED",
  "dominantEmotion": "Enthusiasm",
  "confidenceScore": 0.72,
  "nervousnessScore": 0.31,
  "enthusiasmScore": 0.68,
  "emotionArc": ["Calm", "Enthusiasm", "Joy", "Enthusiasm"]
}
```
or `{ "status": "PENDING" }` / `{ "status": "FAILED" }`. The iOS client polls until completion. This pattern dodges the Cloudflare Workers ~30s single-request ceiling that the previous synchronous `/emotion` endpoint hit.

Auth: `HUME_API_KEY` (Cloudflare Worker secret).

### `POST /coach/weekly-brief` — weekly progress summary

Generates a short narrative coach brief from the user's last-week session metrics. Rate-limited per user. On rate-limit, the iOS client silently swallows the error and keeps the previously cached brief (`WeeklyBriefClient`).

### `POST /delete-user` — account deletion cascade

Replaces the old per-table cleanup with a single server-side cascade across `profiles`, `user_stats`, `session_scores`, `friendships`, `blocks`, `push_tokens`, plus the `auth.users` row.

### `POST /real-life/tips` — Real Life scenario tips

Receives a scenario string, calls Gemini with a short prompt asking for 3 mode-aware coaching tips, and returns:

```json
{ "tips": ["...", "...", "..."] }
```

Timeout client-side is 4s (`RealLifeTipsClient`). On worker-side failure, the client falls back to a static tip set so the session can still launch.

**Secrets:** Set via `wrangler secret put GEMINI_API_KEY`, `wrangler secret put HUME_API_KEY`, `wrangler secret put OPENAI_API_KEY`, plus the Supabase + Apple keys listed at the top of `cloudflare-worker/src/index.js`.

**CI:** Worker unit tests run on every PR. A nightly AI-quality job exercises the scoring path end-to-end against a fixed transcript fixture.

---

## 7. Session Model & Data Storage

**File:** `ParlanceApp/Core/Models/Session.swift`

SwiftData `@Model` class. All sessions are stored on-device. No cloud backup.

### Fields

**Core identity:**
```swift
var id: UUID
var date: Date
var modeRaw: String          // SessionMode raw value
var difficultyLevel: Int     // 1-10
var duration: TimeInterval
var transcript: String
var overallScore: Int        // 0-100
var fillerCount: Int
var question: String         // full question text (not ID)
var xpEarned: Int
var wasDailyChallenge: Bool
var aiCoachFeedback: String? // the coaching paragraph
```

**AI metric storage (new sessions):**
```swift
var metricScoresData: Data?  // JSON-encoded [String: Int], e.g. {"pace": 7, "clarity": 8, ...}
var metricTipsData: Data?    // JSON-encoded [String: String]
var bestMomentQuote: String
var bestMomentReason: String
var worstMomentQuote: String
var worstMomentReason: String
```

Computed accessors:
```swift
var metricScores: [String: Int]     // decoded from metricScoresData
var metricTips: [String: String]    // decoded from metricTipsData
var isAIScored: Bool                // metricScoresData != nil
```

**Legacy fields (kept for sessions created before the scoring rework):**
```swift
var paceScore: Int
var clarityScore: Int
var structureScore: Int
var vocabularyScore: Int
var bestMomentTimestamp: TimeInterval
var bestMomentText: String
var worstMomentTimestamp: TimeInterval
var worstMomentText: String
```

### Migration strategy

Old sessions have legacy fields populated, `metricScoresData = nil` → `isAIScored = false`. New sessions have `metricScoresData` populated, legacy score fields zeroed. The UI branches on `isAIScored` everywhere — legacy sessions show the old 5-metric display, new sessions show the AI metric display.

`overallScore` is unchanged in both paths, so progress charts and leaderboard stats work for all sessions.

### Why `Data?` for metrics instead of native dictionary

SwiftData cannot persist `[String: Int]` or `[String: String]` directly. The workaround is JSON-encode to `Data?` on write and JSON-decode on read. This happens in the computed property getters/setters. Encoding `[String: Int]` and `[String: String]` never fails so the `try?` is safe.

---

## 8. Gamification — XP, Ranks, Streaks

**File:** `ParlanceApp/Core/Services/GamificationService.swift`

Stateless enum with static methods — no singleton, no state.

### XP

```swift
static let baseXP = 120           // every session
static let dailyChallengeXP = 200 // bonus on top of baseXP for daily challenges
```

XP is awarded by `GamificationService.awardXP(to:wasDailyChallenge:)`, which directly mutates `user.xp`. SwiftData propagates the change.

### Ranks

10 levels defined in `Rank.swift`:

| Level | Name | XP required |
|-------|------|-------------|
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

`user.rank` is a computed property: `Rank.from(xp: user.xp)` — no stored rank field, always computed live. Level up is implicit.

### Streaks

`updateStreak(for user:)` logic:
- If `lastSessionDate` is nil → streak = 1
- If last session was today → no change (prevents double-counting multiple sessions per day)
- If last session was yesterday → streak += 1
- Otherwise → streak reset to 1

`longestStreak` is updated any time `currentStreak` exceeds it.

### Daily session limit

`AppConstants.maxSessionsPerDay = 20`. Enforced in `HomeViewModel.startSession()`. `user.isAtDailyLimit` returns true when hit. The counter resets when the first session of a new day is recorded.

---

## 9. League System

**Files:** `ParlanceApp/Core/Models/LeagueTier.swift`, `ParlanceApp/Features/League/LeagueViewModel.swift`, `ParlanceApp/Core/Services/SocialService.swift`

The league reads from two sources:

- **Local SwiftData** for the current user's weekly XP and own tier
- **Supabase `session_scores` table** (via `SocialService`) for global and friends leaderboards

### Tier thresholds (weekly XP)

| Tier | Min weekly XP |
|------|--------------|
| Bronze | 0 |
| Silver | 600 |
| Gold | 1,500 |
| Platinum | 3,000 |
| Diamond | 6,000 |

`LeagueTier.from(weeklyXP:)` computes the user's current tier. Weekly XP is summed from local `session.xpEarned` for the current ISO week via `PersistenceService.sessionsThisWeek()` (Monday–Sunday).

### Leaderboard feeds

After each session, `SyncService.syncAfterSession(...)` inserts a row into Supabase's `session_scores` table:

```swift
struct SessionScoreRow {
    let userId: UUID
    let score: Int
    let mode: String
    let level: Int
    // server-side: createdAt timestamp
}
```

**Real Life sessions are intentionally excluded** from `session_scores` so users can't game the leaderboard with custom prompts. They still count toward local XP, streak, and `user_stats`.

The friends leaderboard pulls the user's accepted friendships, joins against `session_scores` for the current week, and sums per-user. Same query for the global leaderboard but without the friendship filter (with blocked users excluded).

### Reset

The league resets every Monday at midnight. `LeagueViewModel.timeUntilReset()` computes time until next Monday using `Calendar.nextDate(after:matching:)`. The reset is client-computed against `session_scores.created_at` — there is no scheduled server job.

---

## 10. Daily Challenge

**Logic:** `HomeViewModel`

The daily challenge is a fixed practice mode per day of the week, determined by `SessionMode.dailyChallengeMode(weekday:)` (weekday is `Calendar.component(.weekday, from: .now)`, 1=Sunday). The specific mapping is in `SessionMode`.

**Level locking:** The daily challenge locks the user's difficulty level at the moment they first view it each day (`lockDailyChallengeLevel(for:)`). This prevents changing difficulty mid-day to game the daily XP. The lock is stored on `User`:

```swift
var dailyChallengeLevelLock: Int?    // locked difficulty level
var dailyChallengeLockDate: Date?    // date the lock was set
```

If `dailyChallengeLockDate` is today, the locked level is used. Otherwise it gets re-locked.

**Completion tracking:** `user.dailyChallengeCompletedDate` is set to `Date.now` when a daily challenge session completes. `user.hasDailyChallengeCompletedToday` checks if this date is today.

**XP:** Daily challenge awards `baseXP (120) + dailyChallengeXP (200) = 320 XP` total.

**Explain topic of the day:** When the day's challenge mode is Explanation, the home card surfaces the **fixed daily Explain topic** (not "Explain something") so the user knows the specific topic before tapping in. The topic is deterministic per day so it's consistent across users. `SessionCoordinator` syncs `displayedPrompt` if the user reshuffles the Explain sub-category mid-session.

---

## 11. Question Bank

**Service:** `ParlanceApp/Core/Services/QuestionBankService.swift`
**Data:** `ParlanceApp/Features/Resources/questions.json` — static JSON bundled in the app binary (**3,192 entries** as of the most recent expansion)
**Format:**

```swift
struct Question: Codable, Identifiable {
    let id: String
    let mode: SessionMode
    let difficultyBand: String  // "1-2", "3-4", "5-6", "7-8", "9-10"
    let question: String
    let tips: [String]          // 3 coaching tips shown during recording
    let targetDuration: Int     // suggested duration in seconds
    let difficultyNote: String  // short tag
    let category: ExplanationCategory?  // only set for explanation mode
}
```

Every `(mode, band)` pair is populated — `selectQuestion` never returns `nil` for a valid combo. The history of the bank: 1,200 → 1,748 → rewritten down to 1,200 to remove forced-fiction prompts → expanded to **3,192**. A separate pass stripped all 1,129 em dashes for transcription consistency.

**Selection logic** (`QuestionBankService.selectQuestion(mode:band:category:excludingIds:)`):

- **Non-explanation modes:** filter `mode + band`, exclude seen IDs (last 50 from `SeenQuestion`), pick random. Fall back to the full band pool if all seen.
- **Explanation mode** (sub-categorized): if a specific `ExplanationCategory` is selected, prefer unseen matches in that category, then any match in that category, then knowledge-tier ("Any topic") unseen, then knowledge-tier any. Industry categories (tech, healthcare, finance, etc.) are excluded from the "Any topic" pool to avoid imposing domain familiarity.

Questions are never fetched from the network. Zero latency, works fully offline (the network gate blocks the app, but once online all question selection is local).

### Real Life mode bypasses the bank

When `mode == .realLife`, the bank is not consulted. The user enters a scenario in `RealLifeSetupView`, it's validated locally by `RealLifeScenarioValidator`, and `RealLifeTipsClient` fetches AI-generated coaching tips before the session starts. The scenario is persisted in `RealLifeScenarioHistoryStore` for the "use a recent scenario" affordance.

---

## 12. Progress & Skill Trends

**File:** `ParlanceApp/Features/Progress/ProgressViewModel.swift`

### Score history chart

`scoreHistory(from sessions:)` takes the most recent 16 sessions (newest-first from SwiftData), reverses them, and returns `[Int]` of `overallScore` values. Rendered as a line chart in the Progress tab.

### Weekly activity heatmap

`weeklyActivity(from sessions:)` returns a 7-element `[Int]` (Mon–Sun) counting sessions per day. Weekday mapping: `(Calendar.weekday + 5) % 7` maps Sunday(1)→6, Monday(2)→0, etc.

### Skill trends

`skillTrends(currentWeek:previousWeek:)` computes per-metric averages for this week vs last week. Returns `[SkillTrend]` with `name`, `current`, `previous`, `delta` (current − previous).

**For AI-scored sessions:** reads from `session.metricScores[key.rawValue]`  
**For legacy sessions:** falls back to `paceScore`, `clarityScore`, `structureScore`, `vocabularyScore`, or `max(0, 10 - fillerCount)` for fillerWords

Only the 7 universal metrics are tracked in trends (mode-specific metrics like `engagement` are excluded since they don't exist across all sessions).

### Mode breakdown

`modeBreakdown(from:)` returns session count and best score per mode. Used for the mode distribution visualization.

---

## 13. Achievements

**File:** `ParlanceApp/Core/Models/Achievement.swift`

8 achievements, seeded into SwiftData on first launch by `PersistenceService.seedAchievementsIfNeeded()`:

| ID | Name | Unlock condition |
|----|------|-----------------|
| `first_session` | First Session | Complete 1 session |
| `streak_7` | 7-Day Streak | `user.currentStreak >= 7` |
| `interview_pro` | Interview Pro | 10 interview sessions (progress-tracked) |
| `score_80` | Score 80+ | Any session `overallScore >= 80` |
| `zero_fillers` | Zero Fillers | `fillerCount == 0` and transcript is non-empty |
| `rank_5` | Rank 5 | `user.rank.level >= 5` (Rhetorician) |
| `sessions_30` | 30 Sessions | 30 total sessions (progress-tracked) |
| `master` | Master | `user.rank.level >= 10` |

Achievements are checked in `SessionCoordinator.checkAchievements()` after every session. Progress-based achievements (interview_pro, sessions_30) use `PersistenceService.updateAchievementProgress()` which auto-unlocks when `progress >= goal`.

---

## 14. Social / Leaderboard

**File:** `ParlanceApp/Core/Services/SocialService.swift`

Social is **fully server-backed via Supabase** with row-level security policies enforcing access control.

### Tables (Supabase)

| Table | Purpose |
|-------|---------|
| `profiles` | Public profile (display name, username, location, occupation, `avatar_url`, `avatar_updated_at`, daily reminder pref) |
| `user_stats` | XP, level, current streak, longest streak, total sessions; RLS now restricts writes to the owner |
| `session_scores` | One row per scoreable session keyed by `client_session_id` for idempotency; powers leaderboards (Real Life excluded) |
| `friendships` | Directed friend requests and accepted friendships; `unfriend_user` RPC for symmetric removal |
| `blocks` | One-way user blocks; queries filter against this on both ends |
| `push_tokens` | APNs device tokens per user, written by `PushTokenService` |
| `avatars` (storage bucket) | User-uploaded avatar images at `<lowercased-uid>/...`; RLS `WITH CHECK` + size and MIME limits |

### `SocialService` capabilities

```swift
func searchUsers(query: String) async -> [SocialProfile]
func sendFriendRequest(to userId: UUID) async -> Bool
func acceptFriendRequest(from userId: UUID) async -> Bool
func declineFriendRequest(from userId: UUID) async -> Bool
func removeFriend(_ userId: UUID) async -> Bool   // calls unfriend_user RPC
func blockUser(_ userId: UUID) async -> Bool
func unblockUser(_ userId: UUID) async -> Bool
func relationshipState(with userId: UUID) async -> RelationshipState
func refreshFriendsLeaderboard() async
func friendsRankWithDelta() async -> (rank: Int, delta24h: Int)
```

The Friends sub-tab renders a tappable **friends rank chip** with a 24-hour delta arrow that opens a ranked sheet. Public profile rows on the global leaderboard are tappable and route into `UserProfileDetailView`. The add-friend button reflects pending request state correctly when viewing another user's public profile.

`RelationshipState` enum: `.none | .pendingSent | .pendingReceived | .friends | .isSelf`.

User search sanitizes input (letters, numbers, space, dash only) and runs `ilike` on `username` / `display_name` with a `limit(20)` cap. Blocked users are stripped from results client-side via the in-memory `blockedUserIds` set.

### Profile creation flow

On first sign-in:

1. `AuthService` completes Apple Sign-In and obtains the Supabase session
2. `SyncService.fetchAndImportProfile(uid:)` queries `profiles` and `user_stats`; if neither exists (new user), `AuthProfileSetupView` collects display name, username, optional location and occupation
3. `SyncService.createProfile(...)` upserts `profiles` and `user_stats` rows
4. Local SwiftData `User` is created with the same `supabaseUID`

---

## 15. Network Gate

**File:** `ParlanceApp/Core/Services/NetworkMonitor.swift`  
**File:** `ParlanceApp/Features/NoConnection/NoConnectionView.swift`

`NetworkMonitor` wraps `NWPathMonitor` (Apple's Network framework) as an `@MainActor ObservableObject`. It publishes `isConnected: Bool` (defaults to `true`). The monitor starts when `ContentView` initializes (app launch) and runs for the app's lifetime via `deinit { monitor.cancel() }`.

Connectivity changes fire on a background dispatch queue; the update is hopped to the main thread via `DispatchQueue.main.async`.

`ContentView` holds a `@StateObject private var networkMonitor = NetworkMonitor()` and overlays `NoConnectionView()` with a fade transition when `!networkMonitor.isConnected`. The overlay covers all content including tab navigation — the entire app is blocked offline.

Auto-dismisses when connectivity is restored (no "Try Again" button needed).

---

## 16. Persistence Layer (SwiftData)

**File:** `ParlanceApp/Core/Services/PersistenceService.swift`

Singleton `@MainActor` class. All database operations run on the main context (`container.mainContext`).

**Schema:** 4 models: `User`, `Session`, `Achievement`, `SeenQuestion`

**One user per app instance.** `getUser()` fetches the first (and only) `User`. There are no guards — if there are somehow two users, the first one wins.

**`SeenQuestion` model:** Tracks which questions the user has seen to prevent repeats. Stores `questionId`, `modeRaw`, `difficultyBand`, and `seenAt`. Queries are capped to `seenQuestionWindow = 50` most recent per mode+band. This means after 50 questions in a mode+band, the oldest are "forgotten" and can repeat — by design.

**`try? context.save()`** is used everywhere. Errors are silently swallowed. In practice, SwiftData on iOS rarely fails to save, but this means data loss on failure is undetected. A future improvement would be to log save errors.

**Migration degrade path.** If the persistent container fails to open and a fresh attempt also fails (e.g. schema mismatch the migrator can't resolve), the service degrades to an **in-memory store** rather than crashing the app. This keeps the session loop usable while the user contacts support; cloud sync will repopulate profile and stats on the next launch with a working store.

**Profile import merges, not overwrites.** `SyncService.fetchAndImportProfile(...)` merges the server profile into the local `User` rather than overwriting unsynced local fields.

**Offline sync queue.** Failed `syncAfterSession(...)` writes are persisted to UserDefaults as a **FIFO queue** under `parlance.pendingSync`. On the next successful sync, queued rows are drained in insertion order before the new write — previously a single pending blob was kept, which dropped older sessions when multiple failed in a row.

**`resetAllData()`** deletes all models from all tables. Used in dev/testing, exposed in the Profile settings debug section.

---

## 17. Auth — Apple Sign-In + Supabase

**File:** `ParlanceApp/Core/Services/AuthService.swift`
**File:** `ParlanceApp/Features/Auth/AuthViewModel.swift`
**File:** `ParlanceApp/Features/Auth/AuthView.swift`

`AuthService` is an `@MainActor ObservableObject` published as `@EnvironmentObject` from `ParlanceApp.swift`. It exposes:

```swift
@Published private(set) var currentUser: Supabase.User?
@Published private(set) var isAuthenticated: Bool
@Published private(set) var isLoading: Bool
@Published var didJustSignIn: Bool
@Published var pendingAppleDisplayName: String?  // captured from Apple credential, used by profile setup
var currentUserID: String? { currentUser?.id.uuidString }
```

### Flow

1. `AuthView` presents the "Continue with Apple" button (`SignInWithAppleButton` from `AuthenticationServices`)
2. `AuthViewModel` generates a nonce, requests `[.fullName, .email]`, hashes the nonce, and submits the resulting ID token to Supabase via `client.auth.signInWithIdToken(...)`
3. On success, `AuthService` observes the auth state change and updates `currentUser` / `isAuthenticated`
4. `SyncService.fetchAndImportProfile(uid:)` runs; if no profile row exists, `AuthProfileSetupView` collects the missing fields before unlocking the app

### Sign-out and deletion

- **Sign out:** `AuthService.signOut()` clears the Supabase session and wipes the local SwiftData store (so a different account on the same device starts fresh).
- **Delete account:** `AuthService.deleteAccount()` invokes a Supabase Edge Function that cascades a delete across all user-owned rows (`profiles`, `user_stats`, `session_scores`, `friendships`, `blocks`, `push_tokens`) and then deletes the auth row. The client signs out and shows `AccountDeletedSplashView`.

### UI-test bypass

In DEBUG builds, passing `--ui-test-seed-pro` as a launch argument skips the Supabase auth listener entirely. `UITestBootstrap` seeds an authenticated state directly so UI tests don't need real Apple credentials.

---

## 18. Cloud Sync — SyncService

**File:** `ParlanceApp/Core/Services/SyncService.swift`

`SyncService` reconciles local SwiftData with Supabase. It is **not** general bidirectional sync — it's a curated set of write paths plus a one-shot fetch on sign-in.

### What syncs to Supabase

| Local trigger | Server-side write |
|---------------|------------------|
| Sign-in (new account) | `profiles` + `user_stats` upsert |
| Profile edit | `profiles` update |
| Session completion | `user_stats` upsert (XP, level, streak, total sessions) + `session_scores` insert (excluded for Real Life) |
| Settings change (daily reminder, etc.) | `profiles` update |
| First launch after grant | `push_tokens` upsert via `PushTokenService` |

### What does NOT sync

- **Full session records** — transcripts, AI feedback paragraphs, per-metric tips, best/worst moment quotes, audio features all stay local in SwiftData.
- **Achievements** — earned locally; not exposed cross-device.
- **`SeenQuestion` history** — dedupe is per-device.
- **Real Life scenarios** — `RealLifeScenarioHistoryStore` keeps them in UserDefaults, never uploaded.

### Failure handling

If `syncAfterSession(...)` fails (network blip, RLS rejection, server error), the score/mode/level are JSON-encoded to UserDefaults under `parlance.pendingSync` as a **FIFO queue** (see Persistence section). On the next successful sync, queued rows are drained in insertion order before the new write. There's no exponential backoff — retries happen opportunistically when a sync is next triggered.

### Idempotency

`session_scores` inserts include a `client_session_id` matching the local SwiftData `Session.id`. The table has a uniqueness constraint on this column, so a duplicate retry from the offline queue is a no-op at the DB level — clients can retry safely without producing double leaderboard entries.

### Backend invariants

- `send-push` Edge Function requires a Supabase JWT — anonymous calls are rejected.
- `/feedback` transcript content is isolated from the surrounding instruction envelope so a flagged or adversarial transcript cannot mutate the prompt shape.
- `user_stats` RLS was tightened so users cannot write rows they do not own.
- Weekly XP reset runs on a scheduled job; the server is the source of truth for "this week" rather than relying on a client-side rollover.
- `unfriend_user` is a committed RPC (one-call symmetric removal across the friendship pair).

---

## 18a. Theming & Design Tokens

**Files:** `ParlanceApp/UI/Theme/AppColors.swift`, `AppTheme.swift`, `AppFonts.swift`, `AppConstants.swift`

The theme system was reworked into a token-driven warm-editorial palette with explicit mode/difficulty ramps. Highlights:

- **Light mode** rebuilt for stronger card-vs-background contrast and warmer cinnamon→cocoa accents.
- **`AppTheme`** (System / Light / Dark) is hoisted to the App scene via `preferredColorScheme`. UIKit chrome (status bar, nav bar) is kept in sync via a window-level `overrideUserInterfaceStyle` so a theme switch is fully consistent.
- **Mode palette + difficulty ramp** are exposed as tokens rather than hard-coded per call site, so a new mode or difficulty band only touches the token table.
- A teach-first onboarding sweep accompanied the token refactor; canonical components replaced ad-hoc card and badge variants.

## 19. Real Life Mode

**Files:**
- `ParlanceApp/Features/RealLife/RealLifeSetupView.swift`
- `ParlanceApp/Features/RealLife/RealLifeSetupViewModel.swift`
- `ParlanceApp/Core/AI/RealLifeScenarioValidator.swift`
- `ParlanceApp/Core/AI/RealLifeTipsClient.swift`
- `ParlanceApp/Core/Services/RealLifeScenarioHistoryStore.swift`

Real Life mode lets a user paste their actual upcoming scenario instead of receiving a generated prompt. It is Pro-only.

### Flow

1. User taps the **Real Life** mode tile (gated by `subscription.isPro`)
2. `RealLifeSetupView` shows a multi-line text field and recent scenarios (from `RealLifeScenarioHistoryStore`)
3. On **Continue**, `RealLifeScenarioValidator.validate(_:)` runs locally — a rule-based filter (length floor, letter ratio, "ask the AI" pattern guards, must contain a speech-act or audience term). On failure, an inline message guides the user.
4. `RealLifeTipsClient.fetchTips(scenario:)` calls `POST /real-life/tips` to get 3 AI-generated coaching tips. Timeout: 4s. On failure, fall back to a static tip set so the session can still run.
5. Scenario + tips are wrapped into an `ActiveSessionState` and the standard `SessionCoordinator` flow proceeds.
6. The scenario text is appended to `RealLifeScenarioHistoryStore` (UserDefaults, capped to N most recent) for the "recent scenarios" affordance.

### Scoring caveat

Real Life sessions are scored exactly like other modes by the same `FeedbackGenerator.fetchScoring(...)` path. However, they are **excluded from `session_scores`** in `SyncService` to prevent users gaming the leaderboard with prompt-tuned scenarios. XP, streak, and `user_stats` aggregates still count Real Life sessions.

The local rule-based validator is intentionally lenient; the Cloudflare worker performs additional server-side classification as a defense in depth.

---

## 20. Push Notifications

**File:** `ParlanceApp/Core/Services/PushTokenService.swift`
**File:** `ParlanceApp/App/AppDelegate.swift`

The app registers for APNs after the user authenticates and grants notification permission. `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` hands the token to `PushTokenService.uploadToken(_:)`, which upserts a row in `push_tokens` keyed on `(user_id, device_token)`.

### Notification categories

| Category | Trigger | Payload |
|----------|---------|---------|
| Daily reminder | Supabase scheduled Edge Function (per-user opt-in via `profiles.daily_reminder_enabled`) | Generic copy + deep link to Home |
| Friend request received | `SocialService.sendFriendRequest` writes `friendships` row → DB trigger fires Edge Function | `userId` payload → `DeepLinkRouter` opens the requester's profile |
| Friend request accepted | `acceptFriendRequest` → DB trigger fires Edge Function | Same deep link payload |

`DeepLinkRouter` handles the foreground tap by switching the tab and pushing the appropriate destination on the navigation stack.

---

## 21. Known Issues & Gotchas

### Important

**`SpeechTranscriber` uses `requiresOnDeviceRecognition = true`**  
On-device speech recognition requires iOS 16+ and may not be available on all devices or locales. If the recognizer is unavailable, the entire transcription fails and the AI receives an empty transcript (scoring all metrics 1–2). There's no fallback to server-side recognition.

**`AudioFeatureExtractor` loads the entire audio file into memory**  
A 3-minute session at 44100Hz mono Float32 ≈ 32MB RAM. Acceptable for current max duration, but will become a problem if max recording duration is increased significantly.

**Streak logic doesn't handle timezone changes**  
`Calendar.current` is used for date comparisons. A user who crosses a timezone boundary mid-day could get their streak incorrectly reset or incremented.

**`try? context.save()` silently swallows persistence errors**  
No error logging means data loss on save failure is undetectable.

**Daily challenge level lock is per-calendar-day, not per reset**  
`dailyChallengeLockDate` is compared with `isDateInToday`. If a user changes their device clock, the lock can be bypassed.

### Design notes

**`overallScore` is holistic, not a formula.** Do not try to reverse-engineer or reconstruct it from metric scores. The AI is explicitly instructed to set it based on judgment, not math.

**Legacy sessions display differently.** Any session created before the scoring rework (i.e., with `metricScoresData == nil`, `isAIScored == false`) renders the old 5-metric layout. This is intentional and permanent — those sessions don't have AI tips to show.

**The prompt's metric list is dynamic.** `MetricKey.metrics(for: mode)` determines which metrics appear in the AI prompt. Adding a new metric means: (1) add a case to `MetricKey`, (2) add it to `universal` or update the mode switch, (3) it automatically appears in the prompt and the results UI.

---

## 22. Key Constants

Defined in `ParlanceApp/UI/Theme/AppConstants.swift`:

| Constant | Value | Purpose |
|----------|-------|---------|
| `maxRecordingDuration` | 180s | Auto-stops recording |
| `minRecordingDuration` | 5s | Stop button disabled until this |
| `wrapUpWarningTime` | 165s | Visual warning at 2m45s |
| `deliberateNudgeTime` | 8s | "Stay deliberate" nudge appears briefly |
| `loadingMinDuration` | 0.5s | Loading screen minimum display time |
| `maxSessionsPerDay` | 20 | Daily session cap per user |
| `baseXP` | 120 | XP per session |
| `dailyChallengeXP` | 200 | Bonus XP for daily challenge |
| `feedbackTimeout` | 8s | Timeout for legacy `fetchFeedback` |
| `scoringTimeout` | 30s | Timeout for AI scoring call |
| `seenQuestionWindow` | 50 | Max recent questions tracked per mode+band |

---

## 23. File Map

```
ParlanceApp/                                   main app source (also contains Parlance.xcodeproj)
├── App/
│   ├── ActiveSessionState.swift              Session context (mode, level, question, isChallenge)
│   ├── AppDelegate.swift                     APNs registration + DeepLink hand-off
│   ├── ContentView.swift                     Root TabView + AuthView gate + NetworkMonitor overlay
│   ├── DeepLinkRouter.swift                  Universal links + push-notification routing
│   └── SplashView.swift
├── Core/
│   ├── AI/
│   │   ├── ClaudeClient.swift                Cloudflare Worker /feedback (via APIClient)
│   │   ├── FeedbackGenerator.swift           Prompt builder + fetchScoring()
│   │   ├── HumeClient.swift                  Emotion analysis — client polls /emotion/submit + /emotion/status (Pro)
│   │   ├── RealLifeContentDenylist.swift     Local denylist for Real Life pre-flight
│   │   ├── RealLifeScenarioValidator.swift   Local rule-based scenario pre-flight check
│   │   ├── RealLifeTipsClient.swift          AI-generated tips → /real-life/tips
│   │   └── WeeklyBriefClient.swift           Weekly coach brief → /coach/weekly-brief
│   ├── Networking/
│   │   └── APIClient.swift                   Typed Endpoint + base URL + JSON encode/decode for every AI client
│   ├── Models/
│   │   ├── Achievement.swift                 Achievement definitions + SwiftData model
│   │   ├── ActivityEvent.swift               Activity feed event (carries avatar_url)
│   │   ├── AudioFeatures.swift               Pitch/energy summary stats (transient)
│   │   ├── DifficultyLevel.swift             Level names, tiers, bands
│   │   ├── EmotionResult.swift               Hume AI response model (Pro-only)
│   │   ├── ExplanationCategory.swift         Knowledge/industry sub-categories for explanation mode
│   │   ├── GlobalLeaderboardSnapshot.swift   Leaderboard row DTO (carries avatar_url)
│   │   ├── LeagueTier.swift                  Bronze–Diamond tiers with XP thresholds
│   │   ├── MetricKey.swift                   10 metric keys with mode mapping
│   │   ├── PromotionStatus.swift             Weekly tier promotion/demotion result
│   │   ├── PublicProfile.swift               Public profile DTO for tappable leaderboard rows
│   │   ├── Question.swift                    Question struct (from JSON bank)
│   │   ├── Rank.swift                        10 rank levels with XP thresholds
│   │   ├── ScoringResult.swift               AI response model (Codable)
│   │   ├── SeenQuestion.swift                Question deduplication (SwiftData)
│   │   ├── Session.swift                     Session record (SwiftData)
│   │   ├── SessionMode.swift                 11-case practice mode enum (incl. realLife)
│   │   ├── SocialProfile.swift               Social profile DTO (real users via Supabase)
│   │   ├── SupabaseModels.swift              Codable row types for Supabase tables
│   │   ├── TimingStats.swift                 Computed timing stats from word segments
│   │   ├── User.swift                        User profile (SwiftData, mirrors Supabase profile + avatar_url/avatar_updated_at)
│   │   └── WordSegment.swift                 Per-word timestamp + duration
│   └── Services/
│       ├── AudioFeatureExtractor.swift       vDSP pitch/RMS extraction
│       ├── AudioRecorder.swift               AVAudioRecorder wrapper + force-quit recovery
│       ├── AuthService.swift                 Apple Sign-In + Supabase session state
│       ├── AvatarService.swift               Upload, delete, cache-busted URL for Supabase avatars
│       ├── GamificationService.swift         XP, streaks, daily limits
│       ├── NetworkMonitor.swift              NWPathMonitor wrapper
│       ├── PermissionsService.swift          Mic + speech recognition permissions
│       ├── PersistenceService.swift          SwiftData singleton; in-memory fallback on twice-failed migration
│       ├── ProfanityFilter.swift             Username + display-name + pre-flight transcript filter
│       ├── PushTokenService.swift            APNs token upsert into Supabase
│       ├── QuestionBankService.swift         Loads + filters questions.json
│       ├── RealLifeScenarioHistoryStore.swift Recent Real Life scenarios (UserDefaults)
│       ├── SessionWeekCache.swift            In-memory cache for weekly session queries
│       ├── SocialService.swift               Friend graph, blocks, leaderboards, rank delta (Supabase)
│       ├── SoundService.swift                In-app sound effects (optional)
│       ├── SpeechAnalyzer.swift              Filler detection (scoring removed)
│       ├── SpeechTranscriber.swift           SFSpeechRecognizer → TranscriptionResult
│       ├── SubscriptionService.swift         StoreKit 2 (AppTransaction) + isPro gating
│       ├── SupabaseManager.swift             Configured SupabaseClient singleton
│       ├── SyncService.swift                 Local↔Supabase reconciliation + FIFO offline queue + idempotent inserts
│       └── UITestBootstrap.swift             DEBUG-only seeding for UI tests
├── Features/
│   ├── Auth/
│   │   ├── AccountDeletedSplashView.swift
│   │   ├── AuthProfileSetupView.swift        Display name, username, location, occupation
│   │   ├── AuthView.swift                    Sign in with Apple
│   │   ├── AuthViewModel.swift
│   │   ├── SamplePreviewView.swift           Pre-auth sample/teaser content
│   │   ├── WelcomeBackSplashView.swift
│   │   └── WelcomeSplashView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift               Session init, daily challenge logic
│   │   ├── DailyChallengeCard.swift
│   │   └── ModeGridView.swift
│   ├── League/
│   │   ├── LeagueView.swift                  Leaderboard + tier display
│   │   ├── LeagueViewModel.swift             Weekly XP, reset countdown
│   │   └── UserProfileDetailView.swift
│   ├── NoConnection/
│   │   └── NoConnectionView.swift            Full-screen offline gate
│   ├── Paywall/
│   │   └── PaywallView.swift                 Pro subscription purchase screen
│   ├── Profile/
│   │   ├── AvatarPickerSheet.swift           Photo + emoji avatar picker, uploads via AvatarService
│   │   ├── ProfileView.swift                 Level/XP badge, tappable rank card, avatar
│   │   ├── ProfileViewModel.swift
│   │   ├── ProfileEditSheet.swift            Name, username, avatar (uploads on save)
│   │   └── SettingsSheet.swift               Appearance, reminders, sound effects, sign out, delete account
│   ├── Progress/
│   │   ├── AllTimeStatsCard.swift
│   │   ├── CoachBriefView.swift              Weekly coach brief summary
│   │   ├── PeriodFilter.swift                Period scope enum (week/month/all)
│   │   ├── ProgressSegmentedControl.swift    Period selector
│   │   ├── ProgressView.swift
│   │   ├── ProgressViewModel.swift           Charts, skill trends, period-scoped methods
│   │   ├── RecentSessionRow.swift
│   │   ├── SkillCardView.swift
│   │   ├── SkillTrendChart.swift
│   │   ├── StandoutMomentCard.swift
│   │   └── StatsStripView.swift
│   ├── RealLife/
│   │   ├── RealLifeSetupView.swift           Scenario input + recent scenarios
│   │   └── RealLifeSetupViewModel.swift
│   ├── Resources/
│   │   ├── questions.json                    3,192 bundled questions (static, offline)
│   │   └── *.ttf                             Bundled fonts (Inter, Fraunces)
│   ├── Results/
│   │   ├── MetricCardView.swift              Score bar + tip card
│   │   ├── MomentCard.swift                  AIMomentCard + MomentCard (best/worst moment UI)
│   │   ├── ResultsView.swift                 Full results screen (decomposed into phase subviews)
│   │   ├── ResultsViewModel.swift            Retry feedback logic, transcript censor, failure-state routing
│   │   ├── ScoreRingView.swift
│   │   ├── SessionDetailView.swift           Per-session deep dive (from Progress / League)
│   │   ├── ToneAnalysisCard.swift            Emotion analysis display (Pro-only)
│   │   └── XPToastView.swift
│   ├── Session/
│   │   ├── CountdownView.swift
│   │   ├── LoadingView.swift
│   │   ├── RecordingView.swift
│   │   ├── RecordingViewModel.swift
│   │   └── SessionCoordinator.swift          Main session state machine
│   └── Setup/
│       └── FirstLaunchSetupView.swift
├── UI/
│   ├── Components/
│   │   ├── AnimatedWaveformView.swift
│   │   ├── AvatarView.swift                  Photo + emoji fallback, cache-busted URL
│   │   ├── LocationPickerField.swift         MapKit city autocomplete with country flag (used in auth + profile)
│   │   ├── PillBadge.swift                   CUSTOM / FOCUSED variants for Real Life + Explanation cards
│   │   ├── ProgressBar.swift
│   │   ├── SafariView.swift                  UIViewControllerRepresentable → SFSafariViewController
│   │   ├── SectionHeader.swift
│   │   └── XPProgressBar.swift
│   ├── Extensions/
│   │   ├── Color+Hex.swift
│   │   ├── Score+Color.swift
│   │   ├── View+CardStyle.swift
│   │   ├── View+DisableHorizontalScrollBounce.swift
│   │   └── View+Shimmer.swift                Shimmer loading animation modifier
│   └── Theme/
│       ├── AppColors.swift
│       ├── AppConstants.swift
│       ├── AppFonts.swift
│       └── AppTheme.swift
└── ParlanceApp.swift                         App entry point + @EnvironmentObject root

cloudflare-worker/                            (deployed separately)
├── src/
│   ├── index.js                              Router + /feedback (Gemini + OpenAI moderation) + /emotion[ /submit | /status ] + /delete-user
│   ├── realLifeTips.js                       /real-life/tips handler
│   ├── weeklyBrief.js                        /coach/weekly-brief handler (rate-limited)
│   └── briefSafety.js                        Shared moderation/safety helpers
└── wrangler.toml

_docs/
├── decisions/                                Architecture decision records
├── plans/                                    Implementation plans
├── specs/                                    Feature specs
└── guides/                                   This file + parlance-user-guide.md
```
