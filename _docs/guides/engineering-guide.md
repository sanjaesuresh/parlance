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
17. [Known Issues & Gotchas](#17-known-issues--gotchas)
18. [Key Constants](#18-key-constants)
19. [File Map](#19-file-map)

---

## 1. Architecture Overview

**Platform:** iOS 17+ (SwiftUI, portrait-only, no UIKit)  
**Persistence:** SwiftData (on-device SQLite, no cloud sync)  
**AI:** Gemini via a Cloudflare Worker proxy (one scoring call per session; Pro users also get an emotion analysis call via Hume AI)  
**Audio:** AVFoundation (recording) + Speech framework (transcription) + Accelerate/vDSP (audio feature extraction)  
**Backend:** A single Cloudflare Worker at `ParlanceAPIBaseURL` (set in Info.plist). No other server infrastructure. Two endpoints: `POST /feedback` (Gemini scoring) and `POST /emotion` (Hume AI emotion analysis, Pro-only).  
**Questions:** Pre-generated static JSON bundled in the app. Zero network calls for questions.  
**Social:** Mock data only. No backend for leaderboards yet.  
**Subscriptions:** `SubscriptionService` manages StoreKit 2 purchases. `isPro` is the gating flag throughout the app.

**Navigation model:** TabView (Home / Progress / League / Profile) as the root. Sessions take over full-screen via `SessionCoordinator`, hiding the tab bar until the user returns home.

**State management:** SwiftUI-native (`@State`, `@StateObject`, `@Published`, `@EnvironmentObject`). No Redux, TCA, or third-party state library. ViewModels are `@MainActor ObservableObject`.

---

## 2. Session Flow — End to End

The session lifecycle is managed entirely by `SessionCoordinator.swift` (a SwiftUI view that acts as a state machine). Entry point is `HomeViewModel.startSession()` which builds an `ActiveSessionState` and passes it in.

### State machine phases

```
.loading → .countdown → .recording → .processing → .results(Session)
```

**`.loading`** — `LoadingView` shows for a minimum of 500ms (cosmetic). The question is already selected before this screen appears. Fires `AnalyticsService.sessionStarted`.

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

---

## 3. Audio Recording

**File:** `Parlance/Core/Services/AudioRecorder.swift`

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

Claude returns raw JSON (no markdown fences):

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
iOS app → POST /emotion → Cloudflare Worker → Hume AI batch API
```

`HumeClient.analyzeEmotion(audioURL:workerBaseURL:)` uploads the `.m4a` audio file directly to the `/emotion` endpoint. The worker submits it to Hume's batch inference API, polls until complete, and returns the result. The `EmotionResult` model contains:
- `dominantEmotion: String`
- `confidenceScore: Double`
- `nervousnessScore: Double`
- `enthusiasmScore: Double`
- `emotionArc: [String]` — emotion labels over time

This result is passed into `FeedbackGenerator.fetchScoring()` to enrich the AI prompt and is stored on the `Session` model for display in `ToneAnalysisCard`.

---

## 6. The Cloudflare Worker

**File:** `cloudflare-worker/src/index.js` (gitignored — deployed separately)  
**Deployed to:** URL stored in `Info.plist` as `ParlanceAPIBaseURL`  
**Config:** `cloudflare-worker/wrangler.toml`

Two endpoints:

### `POST /feedback` — AI scoring

The worker receives:
```json
{ "messages": [{ "role": "user", "content": "<prompt>" }] }
```

Proxies to Gemini's REST API with:
- Model: `gemini-3-flash-preview`
- `maxOutputTokens: 2048`
- Auth: `GEMINI_API_KEY` (Cloudflare Worker secret)

Returns the raw Gemini JSON response. `ClaudeClient.fetchScoring()` decodes it — it tries two paths: raw decode as `ScoringResult`, then unwrapping a `"feedback"` field (legacy compatibility).

### `POST /emotion` — Hume AI emotion analysis (Pro only)

Receives multipart form data with the `.m4a` audio file. Submits it to Hume AI's batch inference API (prosody model), polls until the job completes, then returns:
```json
{
  "dominantEmotion": "Enthusiasm",
  "confidenceScore": 0.72,
  "nervousnessScore": 0.31,
  "enthusiasmScore": 0.68,
  "emotionArc": ["Calm", "Enthusiasm", "Joy", "Enthusiasm"]
}
```
Auth: `HUME_API_KEY` (Cloudflare Worker secret).

**Secrets:** Set via `wrangler secret put GEMINI_API_KEY` and `wrangler secret put HUME_API_KEY`.

---

## 7. Session Model & Data Storage

**File:** `Parlance/Core/Models/Session.swift`

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

**File:** `Parlance/Core/Services/GamificationService.swift`

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

**Files:** `Parlance/Core/Models/LeagueTier.swift`, `Parlance/Features/League/LeagueViewModel.swift`

The league system is **entirely local**. There is no backend. The leaderboard data is mock `SocialProfile` objects in `SocialProfile.swift`.

### Tier thresholds (weekly XP)

| Tier | Min weekly XP |
|------|--------------|
| Bronze | 0 |
| Silver | 600 |
| Gold | 1,500 |
| Platinum | 3,000 |
| Diamond | 6,000 |

`LeagueTier.from(weeklyXP:)` computes the user's current tier. Weekly XP is calculated by summing `session.xpEarned` for all sessions in the current calendar week (Monday–Sunday reset).

`LeagueViewModel.weeklyXP(from sessions:)` does this sum. The sessions are fetched from SwiftData by `PersistenceService.sessionsThisWeek()`, which queries sessions with `date >= weekStart` (start of the current ISO week).

### Reset

League resets every Monday at midnight. `LeagueViewModel.timeUntilReset()` computes time until next Monday using `Calendar.nextDate(after:matching:)`.

There is no server-side reset. The tier computation is recalculated live from local session data each time the League tab opens.

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

---

## 11. Question Bank

**Service:** `QuestionBankService` (not shown above but referenced in `HomeViewModel`)  
**Data:** `Parlance/Resources/questions.json` — static JSON bundled in the app binary  
**Format:**

```swift
struct Question: Codable, Identifiable {
    let id: String
    let mode: SessionMode
    let difficultyBand: String  // "1-2", "3-4", "5-6", "7-8", "9-10"
    let question: String
    let tips: [String]          // 3 coaching tips shown during recording
    let targetDuration: Int     // suggested duration in seconds
    let difficultyNote: String  // e.g. "This is a Starter-level prompt"
}
```

**Selection logic:**
1. Map `user.practiceLevel` → difficulty band (levels 1-2 → "1-2", 3-4 → "3-4", etc.)
2. Fetch seen question IDs for this mode + band from SwiftData (last 50, via `SeenQuestion` model)
3. Filter questions for this mode + band, excluding seen IDs
4. Pick randomly from unseen questions. If all seen, fall back to any question in the band.

Questions are never fetched from the network. Zero latency, works fully offline (the network gate blocks the app, but once online all question selection is local).

---

## 12. Progress & Skill Trends

**File:** `Parlance/Features/Progress/ProgressViewModel.swift`

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

**File:** `Parlance/Core/Models/Achievement.swift`

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

**Current state: entirely mocked.**

`SocialProfile.swift` contains a static array of 12 hardcoded users with fake names, XP, scores, and avatars. These are displayed in the League tab as "other users."

The user's own entry in the leaderboard is built live from `User` and their session history.

**There is no backend for social.** Friend connections, real leaderboards, and real weekly rankings are planned features but not built. The league tab currently shows the local user ranked against mock profiles.

**When real social is built,** the likely integration points are:
- `LeagueViewModel` — replace mock profiles with API-fetched `SocialProfile` objects
- `User.username` — already a stored optional field, ready for a handle-based system
- `User.xp` / weekly XP — computed locally, would need to be synced to a backend on session completion

---

## 15. Network Gate

**File:** `Parlance/Core/Services/NetworkMonitor.swift`  
**File:** `Parlance/Features/NoConnection/NoConnectionView.swift`

`NetworkMonitor` wraps `NWPathMonitor` (Apple's Network framework) as an `@MainActor ObservableObject`. It publishes `isConnected: Bool` (defaults to `true`). The monitor starts when `ContentView` initializes (app launch) and runs for the app's lifetime via `deinit { monitor.cancel() }`.

Connectivity changes fire on a background dispatch queue; the update is hopped to the main thread via `DispatchQueue.main.async`.

`ContentView` holds a `@StateObject private var networkMonitor = NetworkMonitor()` and overlays `NoConnectionView()` with a fade transition when `!networkMonitor.isConnected`. The overlay covers all content including tab navigation — the entire app is blocked offline.

Auto-dismisses when connectivity is restored (no "Try Again" button needed).

---

## 16. Persistence Layer (SwiftData)

**File:** `Parlance/Core/Services/PersistenceService.swift`

Singleton `@MainActor` class. All database operations run on the main context (`container.mainContext`).

**Schema:** 4 models: `User`, `Session`, `Achievement`, `SeenQuestion`

**One user per app instance.** `getUser()` fetches the first (and only) `User`. There are no guards — if there are somehow two users, the first one wins.

**`SeenQuestion` model:** Tracks which questions the user has seen to prevent repeats. Stores `questionId`, `modeRaw`, `difficultyBand`, and `seenAt`. Queries are capped to `seenQuestionWindow = 50` most recent per mode+band. This means after 50 questions in a mode+band, the oldest are "forgotten" and can repeat — by design.

**`try? context.save()`** is used everywhere. Errors are silently swallowed. In practice, SwiftData on iOS rarely fails to save, but this means data loss on failure is undetected. A future improvement would be to log save errors.

**`resetAllData()`** deletes all models from all tables. Used in dev/testing, exposed in the Profile settings debug section.

---

## 17. Known Issues & Gotchas

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

## 18. Key Constants

Defined in `Parlance/UI/Theme/AppConstants.swift`:

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

## 19. File Map

```
Parlance/
├── App/
│   ├── ActiveSessionState.swift      Session context (mode, level, question, isChallenge)
│   ├── ContentView.swift             Root TabView + NetworkMonitor overlay
│   └── SplashView.swift
├── Core/
│   ├── AI/
│   │   ├── ClaudeClient.swift        HTTP client → Cloudflare Worker /feedback
│   │   ├── FeedbackGenerator.swift   Prompt builder + fetchScoring()
│   │   └── HumeClient.swift          Emotion analysis → Cloudflare Worker /emotion (Pro)
│   ├── Models/
│   │   ├── Achievement.swift         8 achievement definitions + SwiftData model
│   │   ├── AudioFeatures.swift       Pitch/energy summary stats (transient)
│   │   ├── DifficultyLevel.swift     Level names, tiers, bands
│   │   ├── EmotionResult.swift       Hume AI response model (Pro-only)
│   │   ├── LeagueTier.swift          Bronze–Diamond tiers with XP thresholds
│   │   ├── MetricKey.swift           10 metric keys with mode mapping
│   │   ├── Question.swift            Question struct (from JSON bank)
│   │   ├── Rank.swift                10 rank levels with XP thresholds
│   │   ├── ScoringResult.swift       AI response model (Codable)
│   │   ├── SeenQuestion.swift        Question deduplication (SwiftData)
│   │   ├── Session.swift             Session record (SwiftData, ~20 fields)
│   │   ├── SessionMode.swift         10 practice mode enum
│   │   ├── SocialProfile.swift       Mock leaderboard profiles
│   │   ├── TimingStats.swift         Computed timing stats from word segments
│   │   ├── User.swift                User profile (SwiftData)
│   │   └── WordSegment.swift         Per-word timestamp + duration
│   └── Services/
│       ├── AnalyticsService.swift    Event tracking (stub)
│       ├── AudioFeatureExtractor.swift  vDSP pitch/RMS extraction
│       ├── AudioRecorder.swift       AVAudioRecorder wrapper
│       ├── FriendsService.swift      Friends/social data (stub)
│       ├── GamificationService.swift XP, streaks, daily limits
│       ├── NetworkMonitor.swift      NWPathMonitor wrapper
│       ├── PermissionsService.swift  Mic + speech recognition permissions
│       ├── PersistenceService.swift  SwiftData singleton
│       ├── QuestionBankService.swift Loads + filters questions.json
│       ├── SessionWeekCache.swift    In-memory cache for weekly session queries
│       ├── SpeechAnalyzer.swift      Filler detection only (scoring removed)
│       ├── SpeechTranscriber.swift   SFSpeechRecognizer → TranscriptionResult
│       └── SubscriptionService.swift StoreKit 2 purchase + isPro gating
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift       Session init, daily challenge logic
│   │   ├── DailyChallengeCard.swift
│   │   └── ModeGridView.swift
│   ├── League/
│   │   ├── LeagueView.swift          Leaderboard + tier display
│   │   ├── LeagueViewModel.swift     Weekly XP, reset countdown
│   │   └── UserProfileDetailView.swift
│   ├── NoConnection/
│   │   └── NoConnectionView.swift    Full-screen offline gate
│   ├── Paywall/
│   │   └── PaywallView.swift         Pro subscription purchase screen
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── ProfileViewModel.swift
│   │   ├── ProfileEditSheet.swift
│   │   └── SettingsSheet.swift       Settings sheet (appearance, reminders, sound effects)
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ProgressViewModel.swift   Charts, skill trends, mode breakdown
│   ├── Results/
│   │   ├── MetricCardView.swift      Score bar + tip card
│   │   ├── MomentCard.swift          AIMomentCard + MomentCard (best/worst moment UI)
│   │   ├── ResultsView.swift         Full results screen (AI + legacy paths)
│   │   ├── ResultsViewModel.swift    Retry feedback logic
│   │   ├── ScoreRingView.swift
│   │   ├── ToneAnalysisCard.swift    Emotion analysis display (Pro-only)
│   │   └── XPToastView.swift
│   ├── Session/
│   │   ├── CountdownView.swift
│   │   ├── LoadingView.swift
│   │   ├── RecordingView.swift
│   │   ├── RecordingViewModel.swift
│   │   └── SessionCoordinator.swift  Main session state machine
│   └── Setup/
│       └── FirstLaunchSetupView.swift
├── UI/
│   ├── Components/
│   │   ├── AnimatedWaveformView.swift
│   │   ├── PillBadge.swift
│   │   ├── ProgressBar.swift
│   │   ├── SafariView.swift          UIViewControllerRepresentable → SFSafariViewController
│   │   ├── SectionHeader.swift
│   │   └── XPProgressBar.swift
│   ├── Extensions/
│   │   ├── Color+Hex.swift
│   │   ├── Score+Color.swift
│   │   ├── View+CardStyle.swift
│   │   └── View+Shimmer.swift        Shimmer loading animation modifier
│   └── Theme/
│       ├── AppColors.swift
│       ├── AppConstants.swift
│       ├── AppFonts.swift
│       └── AppTheme.swift
├── Resources/
│   └── questions.json               400+ bundled questions (static, offline)
└── ParlanceApp.swift                App entry point

cloudflare-worker/                   (gitignored — deployed separately)
├── src/index.js                     POST /feedback (Gemini scoring) + POST /emotion (Hume AI)
└── wrangler.toml

_docs/
├── decisions/                       Architecture decision records
├── plans/                           Implementation plans
└── specs/                           Feature specs
```
