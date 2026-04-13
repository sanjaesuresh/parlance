# Scoring & AI Feedback Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace local heuristic scoring with a single AI call that scores all mode-specific metrics, supplement the transcript with word timestamps and on-device audio features, and gate the entire app behind a network check.

**Architecture:** `SpeechTranscriber` captures per-word timestamps; a new `AudioFeatureExtractor` reads the saved audio file post-recording to extract pitch/energy stats; `FeedbackGenerator` assembles everything into one prompt and returns a fully structured `ScoringResult`; `Session` stores the new data alongside legacy fields so old sessions continue to display. `NetworkMonitor` blocks the entire app when offline.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation, Accelerate (vDSP), Speech framework, Network framework, Claude Haiku via Cloudflare Worker proxy.

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `Parlance/Core/Services/NetworkMonitor.swift` | NWPathMonitor wrapper |
| Create | `Parlance/Features/NoConnection/NoConnectionView.swift` | Full-screen network gate |
| Create | `Parlance/Core/Models/MetricKey.swift` | Metric enum + mode mapping + display strings |
| Create | `Parlance/Core/Models/ScoringResult.swift` | AI response model |
| Create | `Parlance/Core/Models/WordSegment.swift` | Per-word timestamp + duration |
| Create | `Parlance/Core/Models/TimingStats.swift` | Computed timing stats from word segments |
| Create | `Parlance/Core/Models/AudioFeatures.swift` | Pitch + energy summary stats |
| Create | `Parlance/Core/Services/AudioFeatureExtractor.swift` | Pitch/RMS extraction via vDSP |
| Modify | `Parlance/ContentView.swift` | Inject NetworkMonitor, show NoConnectionView |
| Modify | `Parlance/Core/Services/SpeechTranscriber.swift` | Return segments alongside transcript |
| Modify | `Parlance/Core/Models/Session.swift` | Add new fields, keep legacy for migration |
| Modify | `Parlance/Core/AI/FeedbackGenerator.swift` | New prompt builder + ScoringResult parsing |
| Modify | `Parlance/Core/AI/ClaudeClient.swift` | New `fetchScoring` method |
| Modify | `Parlance/Features/Session/SessionCoordinator.swift` | Updated processSession() |
| Modify | `Parlance/Features/Results/MetricCardView.swift` | Add description field |
| Modify | `Parlance/Features/Results/ResultsView.swift` | Variable metrics, new moments UI |
| Modify | `Parlance/Features/Results/ResultsViewModel.swift` | Remove local tips, update retry |
| Modify | `Parlance/Core/Services/SpeechAnalyzer.swift` | Remove scoring, keep fillerRanges + analyzeFillers |
| Modify | `Parlance/Features/Progress/ProgressViewModel.swift` | Update skillTrends for new storage |

---

## Task 1: NetworkMonitor + NoConnectionView

**Files:**
- Create: `Parlance/Core/Services/NetworkMonitor.swift`
- Create: `Parlance/Features/NoConnection/NoConnectionView.swift`
- Modify: `Parlance/ContentView.swift`

- [ ] **Step 1: Create NetworkMonitor**

```swift
// Parlance/Core/Services/NetworkMonitor.swift
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.parlance.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
```

- [ ] **Step 2: Create NoConnectionView**

```swift
// Parlance/Features/NoConnection/NoConnectionView.swift
import SwiftUI

struct NoConnectionView: View {
    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Branded illustration: signal bars with X
                ZStack {
                    Circle()
                        .fill(AppColors.card)
                        .frame(width: 120, height: 120)

                    VStack(spacing: 0) {
                        // Wifi-style arcs with strike-through
                        ZStack {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 52, weight: .light))
                                .foregroundStyle(AppColors.gold.opacity(0.9))
                        }
                    }
                }

                VStack(spacing: 12) {
                    Text("No Internet Connection")
                        .font(AppFonts.display(24))
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)

                    Text("Parlance requires an internet connection to work. Check your connection and try again.")
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Pulsing connection status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.red)
                        .frame(width: 8, height: 8)
                    Text("Offline")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.sub)
                }
                .padding(.bottom, 48)
            }
        }
    }
}
```

- [ ] **Step 3: Inject NetworkMonitor into ContentView and show overlay**

Read `Parlance/ContentView.swift`, then apply this change. Add `@StateObject private var networkMonitor = NetworkMonitor()` alongside the existing state properties, and add the overlay to the `ZStack` body:

```swift
// Add after existing @State properties:
@StateObject private var networkMonitor = NetworkMonitor()

// Wrap the existing ZStack body content with an additional overlay:
var body: some View {
    ZStack {
        // ... existing content unchanged ...
    }
    .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
    .environment(\.font, AppFonts.body(16))
    .environmentObject(permissionsService)
    .onAppear {
        PersistenceService.shared.seedAchievementsIfNeeded()
    }
    .overlay {
        if !networkMonitor.isConnected {
            NoConnectionView()
                .transition(.opacity)
                .zIndex(999)
                .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        }
    }
}
```

- [ ] **Step 4: Build the app and verify it compiles. No runtime test needed yet.**

- [ ] **Step 5: Commit**

```bash
git add Parlance/Core/Services/NetworkMonitor.swift Parlance/Features/NoConnection/NoConnectionView.swift Parlance/ContentView.swift
git commit -m "feat: add network gate — blocks entire app when offline with branded no-connection screen"
```

---

## Task 2: MetricKey enum

**Files:**
- Create: `Parlance/Core/Models/MetricKey.swift`

- [ ] **Step 1: Create MetricKey**

```swift
// Parlance/Core/Models/MetricKey.swift
import Foundation

enum MetricKey: String, CaseIterable {
    case fillerWords       = "fillerWords"
    case pace              = "pace"
    case clarity           = "clarity"
    case structure         = "structure"
    case vocabulary        = "vocabulary"
    case relevance         = "relevance"
    case comprehensibility = "comprehensibility"
    case deliveryConfidence = "deliveryConfidence"
    case persuasiveness    = "persuasiveness"
    case engagement        = "engagement"

    var displayName: String {
        switch self {
        case .fillerWords:        return "Filler Words"
        case .pace:               return "Pace"
        case .clarity:            return "Clarity"
        case .structure:          return "Structure"
        case .vocabulary:         return "Vocabulary"
        case .relevance:          return "Relevance"
        case .comprehensibility:  return "Comprehensibility"
        case .deliveryConfidence: return "Delivery Confidence"
        case .persuasiveness:     return "Persuasiveness"
        case .engagement:         return "Engagement"
        }
    }

    /// Short description shown beneath metric name on the results screen.
    var metricDescription: String {
        switch self {
        case .fillerWords:        return "Ums, uhs, and verbal crutches"
        case .pace:               return "Speaking speed and rhythm"
        case .clarity:            return "How easy your words are to follow"
        case .structure:          return "Opening, body, and closing flow"
        case .vocabulary:         return "Word choice strength and variety"
        case .relevance:          return "Did you answer the question?"
        case .comprehensibility:  return "Could a listener follow your reasoning?"
        case .deliveryConfidence: return "Assertiveness without hedging"
        case .persuasiveness:     return "How compelling is your argument?"
        case .engagement:         return "Would a listener stay interested?"
        }
    }

    /// Universal metrics every mode receives.
    static let universal: [MetricKey] = [
        .fillerWords, .pace, .clarity, .structure, .vocabulary, .relevance, .comprehensibility
    ]

    /// Full ordered metric list for the given mode.
    static func metrics(for mode: SessionMode) -> [MetricKey] {
        var keys = universal
        switch mode {
        case .interview:   keys += [.deliveryConfidence]
        case .pitch:       keys += [.deliveryConfidence, .persuasiveness]
        case .keynote:     keys += [.deliveryConfidence, .persuasiveness, .engagement]
        case .casual:      keys += [.engagement]
        case .debate:      keys += [.deliveryConfidence, .persuasiveness]
        case .storytelling: keys += [.engagement]
        case .explanation: keys += [.engagement]
        case .negotiation: keys += [.deliveryConfidence, .persuasiveness]
        case .impromptu:   keys += [.deliveryConfidence]
        case .networking:  keys += [.engagement]
        }
        return keys
    }
}
```

- [ ] **Step 2: Build to verify it compiles.**

- [ ] **Step 3: Commit**

```bash
git add Parlance/Core/Models/MetricKey.swift
git commit -m "feat: add MetricKey enum with display names, descriptions, and mode mapping"
```

---

## Task 3: ScoringResult model

**Files:**
- Create: `Parlance/Core/Models/ScoringResult.swift`

- [ ] **Step 1: Create ScoringResult**

```swift
// Parlance/Core/Models/ScoringResult.swift
import Foundation

struct MetricScore: Codable {
    let score: Int  // 0-10
    let tip: String
}

struct ScoringMoment: Codable {
    let quote: String
    let reason: String
}

struct ScoringResult: Codable {
    let metrics: [String: MetricScore]
    let overallScore: Int  // 0-100
    let feedback: String
    let bestMoment: ScoringMoment
    let worstMoment: ScoringMoment
}
```

- [ ] **Step 2: Build to verify it compiles.**

- [ ] **Step 3: Commit**

```bash
git add Parlance/Core/Models/ScoringResult.swift
git commit -m "feat: add ScoringResult model for AI response"
```

---

## Task 4: WordSegment, TimingStats, AudioFeatures models

**Files:**
- Create: `Parlance/Core/Models/WordSegment.swift`
- Create: `Parlance/Core/Models/TimingStats.swift`
- Create: `Parlance/Core/Models/AudioFeatures.swift`

- [ ] **Step 1: Create WordSegment**

```swift
// Parlance/Core/Models/WordSegment.swift
import Foundation

struct WordSegment {
    let word: String
    let timestamp: TimeInterval   // seconds from recording start
    let duration: TimeInterval    // how long the word lasted
}
```

- [ ] **Step 2: Create TimingStats**

```swift
// Parlance/Core/Models/TimingStats.swift
import Foundation

struct TimingStats {
    let wordCount: Int
    let speechToSilenceRatio: Double    // 0-1, proportion of time spent speaking
    let longestPauseDuration: TimeInterval
    let longestPauseAfterWord: String   // word that preceded the longest pause
    let speakingRateStdDev: Double      // std dev of word count per 10s window

    static let empty = TimingStats(
        wordCount: 0,
        speechToSilenceRatio: 0,
        longestPauseDuration: 0,
        longestPauseAfterWord: "",
        speakingRateStdDev: 0
    )

    /// Compute timing stats from SFSpeechRecognizer word segments.
    static func compute(from segments: [WordSegment], totalDuration: TimeInterval) -> TimingStats {
        guard !segments.isEmpty, totalDuration > 0 else { return .empty }

        // Speech-to-silence ratio
        let speechTime = segments.map(\.duration).reduce(0, +)
        let ratio = min(1.0, speechTime / totalDuration)

        // Longest pause between consecutive words
        var longestPause: TimeInterval = 0
        var longestPauseWord = ""
        for i in 1..<segments.count {
            let gap = segments[i].timestamp - (segments[i-1].timestamp + segments[i-1].duration)
            if gap > longestPause {
                longestPause = gap
                longestPauseWord = segments[i-1].word
            }
        }

        // Speaking rate variance: words per 10-second window
        let windowSize: TimeInterval = 10
        var wordsPerWindow: [Double] = []
        var windowStart: TimeInterval = 0
        while windowStart < totalDuration {
            let windowEnd = windowStart + windowSize
            let count = segments.filter { $0.timestamp >= windowStart && $0.timestamp < windowEnd }.count
            wordsPerWindow.append(Double(count))
            windowStart += windowSize
        }
        let mean = wordsPerWindow.reduce(0, +) / Double(max(1, wordsPerWindow.count))
        let variance = wordsPerWindow.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(max(1, wordsPerWindow.count))

        return TimingStats(
            wordCount: segments.count,
            speechToSilenceRatio: ratio,
            longestPauseDuration: longestPause,
            longestPauseAfterWord: longestPauseWord,
            speakingRateStdDev: sqrt(variance)
        )
    }
}
```

- [ ] **Step 3: Create AudioFeatures**

```swift
// Parlance/Core/Models/AudioFeatures.swift
import Foundation

struct AudioFeatures {
    let pitchMeanHz: Double      // mean fundamental frequency (Hz)
    let pitchStdDevHz: Double    // std dev of pitch — high = dynamic delivery
    let energyMeanRMS: Double    // mean RMS energy — overall loudness
    let energyStdDevRMS: Double  // std dev of energy — high = varied energy

    static let empty = AudioFeatures(
        pitchMeanHz: 0, pitchStdDevHz: 0,
        energyMeanRMS: 0, energyStdDevRMS: 0
    )
}
```

- [ ] **Step 4: Build to verify it compiles.**

- [ ] **Step 5: Commit**

```bash
git add Parlance/Core/Models/WordSegment.swift Parlance/Core/Models/TimingStats.swift Parlance/Core/Models/AudioFeatures.swift
git commit -m "feat: add WordSegment, TimingStats, AudioFeatures models for delivery analysis"
```

---

## Task 5: AudioFeatureExtractor

**Files:**
- Create: `Parlance/Core/Services/AudioFeatureExtractor.swift`

- [ ] **Step 1: Create AudioFeatureExtractor**

This reads the saved .m4a file after recording, extracts pitch and RMS per frame using vDSP, and returns summary statistics.

```swift
// Parlance/Core/Services/AudioFeatureExtractor.swift
import AVFoundation
import Accelerate

enum AudioFeatureExtractor {

    /// Extract pitch and energy features from a recorded audio file.
    /// Runs synchronously — call from a background context.
    static func extract(from url: URL) -> AudioFeatures {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return .empty
        }

        let processingFormat = audioFile.processingFormat
        let totalFrameCount = AVAudioFrameCount(audioFile.length)
        guard totalFrameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: totalFrameCount),
              (try? audioFile.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData else {
            return .empty
        }

        let samples = channelData[0]  // mono (channel 0)
        let totalFrames = Int(buffer.frameLength)
        let sampleRate = Float(processingFormat.sampleRate)
        let frameSize = 2048  // ~46ms at 44100Hz — good for pitch detection

        var rmsValues: [Double] = []
        var pitchValues: [Double] = []

        var offset = 0
        while offset + frameSize <= totalFrames {
            let framePtr = samples + offset

            // RMS energy for this frame
            var rms: Float = 0
            vDSP_rmsqv(framePtr, 1, &rms, vDSP_Length(frameSize))
            rmsValues.append(Double(rms))

            // Pitch estimation (only for voiced frames — skip silence)
            if rms > 0.01 {
                if let f0 = estimatePitch(samples: framePtr, count: frameSize, sampleRate: sampleRate) {
                    pitchValues.append(Double(f0))
                }
            }

            offset += frameSize
        }

        guard !rmsValues.isEmpty else { return .empty }

        return AudioFeatures(
            pitchMeanHz: pitchValues.isEmpty ? 0 : pitchValues.reduce(0, +) / Double(pitchValues.count),
            pitchStdDevHz: pitchValues.isEmpty ? 0 : stdDev(pitchValues),
            energyMeanRMS: rmsValues.reduce(0, +) / Double(rmsValues.count),
            energyStdDevRMS: stdDev(rmsValues)
        )
    }

    // MARK: - Pitch via autocorrelation

    /// Estimates fundamental frequency using normalized autocorrelation.
    /// Returns nil if no strong pitch peak is found (unvoiced frame).
    private static func estimatePitch(samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float? {
        let minLag = Int(sampleRate / 300)  // 300 Hz upper bound
        let maxLag = Int(sampleRate / 85)   // 85 Hz lower bound
        guard minLag > 0, maxLag < count, minLag < maxLag else { return nil }

        // Autocorrelation at lag 0 (normalization reference)
        var r0: Float = 0
        vDSP_dotpr(samples, 1, samples, 1, &r0, vDSP_Length(count))
        guard r0 > 0 else { return nil }

        // Find lag with highest normalized autocorrelation in [minLag, maxLag]
        var bestLag = minLag
        var bestCorr: Float = -1

        for lag in minLag...maxLag {
            let len = count - lag
            guard len > 0 else { break }
            var corr: Float = 0
            vDSP_dotpr(samples, 1, samples + lag, 1, &corr, vDSP_Length(len))
            corr /= r0
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }

        // Threshold: only return if correlation is strong (voiced speech)
        guard bestCorr > 0.4 else { return nil }
        return sampleRate / Float(bestLag)
    }

    // MARK: - Stats

    private static func stdDev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
```

- [ ] **Step 2: Build to verify it compiles. Pay attention to the `vDSP_dotpr` calls — the pointer arithmetic `samples + lag` requires `UnsafePointer<Float>`, which is what we declared.**

- [ ] **Step 3: Commit**

```bash
git add Parlance/Core/Services/AudioFeatureExtractor.swift
git commit -m "feat: add AudioFeatureExtractor — pitch and energy analysis via vDSP autocorrelation"
```

---

## Task 6: Update SpeechTranscriber to capture word timestamps

**Files:**
- Modify: `Parlance/Core/Services/SpeechTranscriber.swift`

- [ ] **Step 1: Read the current SpeechTranscriber**

File is at `Parlance/Core/Services/SpeechTranscriber.swift`. Current signature: `static func transcribe(url: URL) async throws -> String`.

- [ ] **Step 2: Replace the entire file**

```swift
// Parlance/Core/Services/SpeechTranscriber.swift
import Speech

struct TranscriptionResult {
    let transcript: String
    let segments: [WordSegment]
}

final class SpeechTranscriber {
    enum TranscriptionError: Error {
        case notAvailable
        case recognitionFailed(String)
    }

    static func transcribe(url: URL) async throws -> TranscriptionResult {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAvailable
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                if let error {
                    didResume = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal {
                    didResume = true
                    let segments: [WordSegment] = result.bestTranscription.segments.map {
                        WordSegment(
                            word: $0.substring,
                            timestamp: $0.timestamp,
                            duration: $0.duration
                        )
                    }
                    continuation.resume(returning: TranscriptionResult(
                        transcript: result.bestTranscription.formattedString,
                        segments: segments
                    ))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build. The compiler will flag the call site in SessionCoordinator — that will be fixed in Task 9. For now, expect one build error there. Verify SpeechTranscriber itself has no errors.**

- [ ] **Step 4: Commit**

```bash
git add Parlance/Core/Services/SpeechTranscriber.swift
git commit -m "feat: SpeechTranscriber now returns word-level timestamps via SFTranscriptionSegment"
```

---

## Task 7: Update Session model

**Files:**
- Modify: `Parlance/Core/Models/Session.swift`

- [ ] **Step 1: Read the current Session.swift**

File is at `Parlance/Core/Models/Session.swift`.

- [ ] **Step 2: Replace the entire file with the updated model**

Keep all legacy score fields (`paceScore`, `clarityScore`, `structureScore`, `vocabularyScore`) so existing sessions continue to display. Add new fields for the AI scoring pipeline.

```swift
// Parlance/Core/Models/Session.swift
import Foundation
import SwiftData

@Model
final class Session {
    // MARK: - Core identity
    var id: UUID
    var date: Date
    var modeRaw: String
    var difficultyLevel: Int
    var duration: TimeInterval
    var transcript: String
    var overallScore: Int
    var fillerCount: Int
    var question: String
    var xpEarned: Int
    var wasDailyChallenge: Bool
    var aiCoachFeedback: String?

    // MARK: - Legacy metric scores (kept for existing sessions)
    var paceScore: Int
    var clarityScore: Int
    var structureScore: Int
    var vocabularyScore: Int

    // MARK: - Legacy moments (kept for existing sessions)
    var bestMomentTimestamp: TimeInterval
    var bestMomentText: String
    var worstMomentTimestamp: TimeInterval
    var worstMomentText: String

    // MARK: - New: AI metric scores (JSON-encoded [String: Int])
    var metricScoresData: Data?
    // MARK: - New: AI metric tips (JSON-encoded [String: String])
    var metricTipsData: Data?

    // MARK: - New: AI moments
    var bestMomentQuote: String
    var bestMomentReason: String
    var worstMomentQuote: String
    var worstMomentReason: String

    // MARK: - Computed

    var mode: SessionMode {
        get { SessionMode(rawValue: modeRaw) ?? .interview }
        set { modeRaw = newValue.rawValue }
    }

    var hasTranscript: Bool { !transcript.isEmpty }

    /// True if this session was scored by the new AI pipeline (has metricScoresData).
    var isAIScored: Bool { metricScoresData != nil }

    var metricScores: [String: Int] {
        get {
            guard let data = metricScoresData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            metricScoresData = try? JSONEncoder().encode(newValue)
        }
    }

    var metricTips: [String: String] {
        get {
            guard let data = metricTipsData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            metricTipsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Init for new AI-scored sessions

    init(
        mode: SessionMode,
        difficultyLevel: Int,
        duration: TimeInterval,
        transcript: String,
        fillerCount: Int,
        question: String,
        scoringResult: ScoringResult,
        xpEarned: Int,
        wasDailyChallenge: Bool
    ) {
        self.id = UUID()
        self.date = .now
        self.modeRaw = mode.rawValue
        self.difficultyLevel = difficultyLevel
        self.duration = duration
        self.transcript = transcript
        self.fillerCount = fillerCount
        self.question = question
        self.xpEarned = xpEarned
        self.wasDailyChallenge = wasDailyChallenge

        self.overallScore = scoringResult.overallScore
        self.aiCoachFeedback = scoringResult.feedback

        // New AI fields
        let scores = scoringResult.metrics.mapValues(\.score)
        let tips = scoringResult.metrics.mapValues(\.tip)
        self.metricScoresData = try? JSONEncoder().encode(scores)
        self.metricTipsData = try? JSONEncoder().encode(tips)
        self.bestMomentQuote = scoringResult.bestMoment.quote
        self.bestMomentReason = scoringResult.bestMoment.reason
        self.worstMomentQuote = scoringResult.worstMoment.quote
        self.worstMomentReason = scoringResult.worstMoment.reason

        // Legacy fields — zero for new sessions
        self.paceScore = 0
        self.clarityScore = 0
        self.structureScore = 0
        self.vocabularyScore = 0
        self.bestMomentTimestamp = 0
        self.bestMomentText = ""
        self.worstMomentTimestamp = 0
        self.worstMomentText = ""
    }

    // MARK: - Legacy init (kept so existing code that creates sessions still compiles during migration)

    init(
        mode: SessionMode,
        difficultyLevel: Int,
        duration: TimeInterval,
        transcript: String,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        question: String,
        aiCoachFeedback: String? = nil,
        bestMomentTimestamp: TimeInterval = 0,
        bestMomentText: String = "",
        worstMomentTimestamp: TimeInterval = 0,
        worstMomentText: String = "",
        xpEarned: Int,
        wasDailyChallenge: Bool
    ) {
        self.id = UUID()
        self.date = .now
        self.modeRaw = mode.rawValue
        self.difficultyLevel = difficultyLevel
        self.duration = duration
        self.transcript = transcript
        self.overallScore = overallScore
        self.fillerCount = fillerCount
        self.paceScore = paceScore
        self.clarityScore = clarityScore
        self.structureScore = structureScore
        self.vocabularyScore = vocabularyScore
        self.question = question
        self.aiCoachFeedback = aiCoachFeedback
        self.bestMomentTimestamp = bestMomentTimestamp
        self.bestMomentText = bestMomentText
        self.worstMomentTimestamp = worstMomentTimestamp
        self.worstMomentText = worstMomentText
        self.xpEarned = xpEarned
        self.wasDailyChallenge = wasDailyChallenge
        self.metricScoresData = nil
        self.metricTipsData = nil
        self.bestMomentQuote = ""
        self.bestMomentReason = ""
        self.worstMomentQuote = ""
        self.worstMomentReason = ""
    }
}
```

- [ ] **Step 3: Build. Expect errors in SessionCoordinator and ProgressViewModel — those are fixed in later tasks.**

- [ ] **Step 4: Commit**

```bash
git add Parlance/Core/Models/Session.swift
git commit -m "feat: update Session model — add AI metric storage, keep legacy fields for migration"
```

---

## Task 8: Update FeedbackGenerator and ClaudeClient

**Files:**
- Modify: `Parlance/Core/AI/FeedbackGenerator.swift`
- Modify: `Parlance/Core/AI/ClaudeClient.swift`

- [ ] **Step 1: Replace FeedbackGenerator entirely**

```swift
// Parlance/Core/AI/FeedbackGenerator.swift
import Foundation

enum FeedbackGenerator {

    static func buildPrompt(
        mode: SessionMode,
        level: Int,
        question: String,
        transcript: String,
        timingStats: TimingStats,
        audioFeatures: AudioFeatures
    ) -> String {
        let levelName = DifficultyLevel.name(for: level)
        let metrics = MetricKey.metrics(for: mode)
        let levelTone: String
        switch level {
        case 1...4: levelTone = "be constructive — acknowledge effort and point to one clear improvement"
        case 5...6: levelTone = "be direct and specific — name what worked and what to fix"
        default:    levelTone = "be rigorous — hold them to a high standard, be exacting"
        }

        let metricList = metrics.map {
            "- \($0.rawValue) (\($0.displayName)): \($0.metricDescription)"
        }.joined(separator: "\n")

        let metricsJsonTemplate = metrics.map {
            "    \"\($0.rawValue)\": { \"score\": <0-10 int>, \"tip\": \"<one specific actionable sentence>\" }"
        }.joined(separator: ",\n")

        let transcriptSection = transcript.isEmpty
            ? "(No transcript available — user did not speak or speech recognition failed)"
            : "\"\(transcript)\""

        return """
        You are a direct, no-nonsense speech coach evaluating a \(mode.displayName) session.
        Level: \(level) (\(levelName))
        Tone for this level: \(levelTone)

        Question asked:
        "\(question)"

        Transcript:
        \(transcriptSection)

        Session data:
        - Duration: \(Int(timingStats.wordCount > 0 ? 0 : 0)) words in the transcript
        - Word count: \(timingStats.wordCount)
        - Speech-to-silence ratio: \(Int(timingStats.speechToSilenceRatio * 100))% (time actually speaking)
        - Longest pause: \(String(format: "%.1f", timingStats.longestPauseDuration))s (after "\(timingStats.longestPauseAfterWord)")
        - Speaking rate variation: \(String(format: "%.1f", timingStats.speakingRateStdDev)) words/10s std dev (higher = more varied pace)

        Audio delivery:
        - Pitch mean: \(String(format: "%.0f", audioFeatures.pitchMeanHz))Hz, std dev: \(String(format: "%.0f", audioFeatures.pitchStdDevHz))Hz (higher std dev = more dynamic, less monotone)
        - Energy mean RMS: \(String(format: "%.3f", audioFeatures.energyMeanRMS)), std dev: \(String(format: "%.3f", audioFeatures.energyStdDevRMS)) (higher std dev = more energy variation)

        Score these metrics for this \(mode.displayName) session:
        \(metricList)

        Return ONLY valid JSON — no markdown, no extra text, no code fences:
        {
          "metrics": {
        \(metricsJsonTemplate)
          },
          "overallScore": <0-100 int, your holistic judgment — NOT an average>,
          "feedback": "<one paragraph, direct coaching: reference the question, name one strength and the most important thing to fix>",
          "bestMoment": { "quote": "<exact phrase from transcript, or empty string if no transcript>", "reason": "<why it worked>" },
          "worstMoment": { "quote": "<exact phrase from transcript, or empty string if no transcript>", "reason": "<what to fix>" }
        }

        Rules:
        - overallScore is YOUR judgment of overall quality, not a formula
        - A long speech-to-silence ratio (>80%) with low word count = the speaker paused excessively — penalize pace and delivery
        - A high pitch std dev means dynamic, engaging delivery — reward it
        - A low pitch std dev means monotone delivery — penalize engagement/delivery confidence
        - Tips must reference what they actually said, not generic advice
        - If transcript is empty or fewer than 10 words, score all metrics 1-2 and explain in feedback
        """
    }

    static func fetchScoring(
        client: ClaudeClient,
        mode: SessionMode,
        level: Int,
        question: String,
        transcript: String,
        timingStats: TimingStats,
        audioFeatures: AudioFeatures
    ) async -> ScoringResult? {
        let prompt = buildPrompt(
            mode: mode, level: level, question: question,
            transcript: transcript, timingStats: timingStats, audioFeatures: audioFeatures
        )
        return try? await client.fetchScoring(prompt: prompt)
    }
}
```

- [ ] **Step 2: Update ClaudeClient — add fetchScoring, keep fetchFeedback for backward compat**

Read `Parlance/Core/AI/ClaudeClient.swift`, then replace the file:

```swift
// Parlance/Core/AI/ClaudeClient.swift
import Foundation

final class ClaudeClient {
    private let baseURL: URL

    init() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String,
              let url = URL(string: urlString) else {
            fatalError("ParlanceAPIBaseURL not set in Info.plist")
        }
        self.baseURL = url
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // MARK: - New: full scoring response

    func fetchScoring(prompt: String) async throws -> ScoringResult {
        let data = try await post(prompt: prompt)

        // Try decoding as ScoringResult directly (worker returns raw Claude JSON)
        if let result = try? JSONDecoder().decode(ScoringResult.self, from: data) {
            return result
        }

        // Fallback: worker wraps in {"feedback": "..."}
        struct Wrapped: Decodable { let feedback: String }
        if let wrapped = try? JSONDecoder().decode(Wrapped.self, from: data),
           let jsonData = wrapped.feedback.data(using: .utf8),
           let result = try? JSONDecoder().decode(ScoringResult.self, from: jsonData) {
            return result
        }

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Legacy: plain feedback string (kept for ResultsViewModel.retryFeedback)

    struct FeedbackResponse: Decodable {
        let feedback: String
    }

    func fetchFeedback(prompt: String) async throws -> String {
        let data = try await post(prompt: prompt)
        let decoded = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return decoded.feedback
    }

    // MARK: - Shared transport

    private func post(prompt: String) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("feedback")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.feedbackTimeout

        let body: [String: Any] = [
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
```

- [ ] **Step 3: Build. Expect errors in SessionCoordinator — fixed in the next task.**

- [ ] **Step 4: Commit**

```bash
git add Parlance/Core/AI/FeedbackGenerator.swift Parlance/Core/AI/ClaudeClient.swift
git commit -m "feat: FeedbackGenerator and ClaudeClient updated for full AI scoring with delivery data"
```

---

## Task 9: Update SessionCoordinator.processSession()

**Files:**
- Modify: `Parlance/Features/Session/SessionCoordinator.swift`

- [ ] **Step 1: Read the current SessionCoordinator.swift**

File is at `Parlance/Features/Session/SessionCoordinator.swift`. The method to replace is `processSession()`.

- [ ] **Step 2: Replace the `processSession()` method and its imports**

Replace the entire `processSession()` private method. The rest of the file (view body, `retrySession()`, `checkAchievements()`) stays unchanged. Also update the `processSession` call that references `SpeechAnalyzer.Metrics` to no longer need it.

The full updated `processSession()`:

```swift
@MainActor
private func processSession() async {
    guard let audioURL = recorder.stopRecording() else {
        onDismiss()
        return
    }

    let duration = recorder.elapsedTime

    // Transcribe + extract audio features in parallel
    async let transcriptionTask: TranscriptionResult? = {
        return try? await SpeechTranscriber.transcribe(url: audioURL)
    }()
    async let audioFeaturesTask: AudioFeatures = AudioFeatureExtractor.extract(from: audioURL)

    let (transcriptionResult, audioFeatures) = await (transcriptionTask, audioFeaturesTask)

    // Delete audio file — no longer needed
    recorder.deleteRecording()

    let transcript = transcriptionResult?.transcript ?? ""
    let segments = transcriptionResult?.segments ?? []

    // Compute timing stats from word segments
    let timingStats = TimingStats.compute(from: segments, totalDuration: duration)

    // Filler count for transcript display (local, fast)
    let fillerCount = transcript.isEmpty ? 0 : SpeechAnalyzer.analyzeFillers(in: transcript).count

    // Calculate XP
    let xpEarned = GamificationService.xpForSession(wasDailyChallenge: state.wasDailyChallenge)

    // Fetch AI scoring — this is the blocking call before showing results
    let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String ?? ""
    guard let url = URL(string: urlString) else {
        onDismiss()
        return
    }
    let client = ClaudeClient(baseURL: url)

    let scoringResult = await FeedbackGenerator.fetchScoring(
        client: client,
        mode: state.mode,
        level: state.difficultyLevel,
        question: state.question.question,
        transcript: transcript,
        timingStats: timingStats,
        audioFeatures: audioFeatures
    )

    // Fall back to a zeroed result if AI fails (network error, timeout)
    let finalResult = scoringResult ?? ScoringResult(
        metrics: [:],
        overallScore: 0,
        feedback: nil,
        bestMoment: ScoringMoment(quote: "", reason: ""),
        worstMoment: ScoringMoment(quote: "", reason: "")
    )

    // Create session record
    let session = Session(
        mode: state.mode,
        difficultyLevel: state.difficultyLevel,
        duration: duration,
        transcript: transcript,
        fillerCount: fillerCount,
        question: state.question.question,
        scoringResult: finalResult,
        xpEarned: xpEarned,
        wasDailyChallenge: state.wasDailyChallenge
    )

    // Analytics
    AnalyticsService.sessionCompleted(
        mode: state.mode, level: state.difficultyLevel,
        overallScore: session.overallScore, duration: duration,
        wasDailyChallenge: state.wasDailyChallenge
    )
    if state.wasDailyChallenge {
        AnalyticsService.dailyChallengeCompleted(mode: state.mode, level: state.difficultyLevel)
    }

    // Persist
    let persistence = PersistenceService.shared
    persistence.saveSession(session)
    persistence.markQuestionSeen(
        questionId: state.question.id,
        mode: state.mode,
        band: state.question.difficultyBand
    )

    // Gamification
    if let user = persistence.getUser() {
        GamificationService.awardXP(to: user, wasDailyChallenge: state.wasDailyChallenge)
        GamificationService.updateStreak(for: user)
        GamificationService.incrementDailySessionCount(for: user)
        if state.wasDailyChallenge { user.dailyChallengeCompletedDate = .now }
        checkAchievements(user: user, session: session, persistence: persistence)
    }

    phase = .results(session)
}
```

Note: `ScoringResult.feedback` in the Session init takes `String?` — `ScoringResult.feedback` is a `String`, so you pass it directly. The `ScoringResult` fallback above sets `feedback: nil` which requires making `ScoringResult.feedback` optional. 

- [ ] **Step 3: Update ScoringResult to make feedback optional**

Read `Parlance/Core/Models/ScoringResult.swift` and change `let feedback: String` to `let feedback: String?`. Also update `Session.init(scoringResult:)` to assign `self.aiCoachFeedback = scoringResult.feedback`.

- [ ] **Step 4: Build. Fix any remaining compilation errors.**

- [ ] **Step 5: Commit**

```bash
git add Parlance/Features/Session/SessionCoordinator.swift Parlance/Core/Models/ScoringResult.swift
git commit -m "feat: SessionCoordinator uses AI scoring pipeline with word timestamps and audio features"
```

---

## Task 10: Update MetricCardView and ResultsView

**Files:**
- Modify: `Parlance/Features/Results/MetricCardView.swift`
- Modify: `Parlance/Features/Results/ResultsView.swift`
- Modify: `Parlance/Features/Results/ResultsViewModel.swift`

- [ ] **Step 1: Update MetricCardView to show a description**

Read `Parlance/Features/Results/MetricCardView.swift`, then replace the file:

```swift
// Parlance/Features/Results/MetricCardView.swift
import SwiftUI

struct MetricCardView: View {
    let name: String
    let description: String   // short metric description
    let score: Int            // 0-10, or -1 if unavailable
    let tip: String

    private var scoreColor: Color {
        if score < 0 { return AppColors.sub }
        if score >= 8 { return AppColors.teal }
        if score >= 5 { return AppColors.gold }
        return AppColors.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: name + score
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.text)
                    Text(description)
                        .font(AppFonts.body(10))
                        .foregroundStyle(AppColors.dim)
                }

                Spacer()

                if score >= 0 {
                    Text("\(score * 10)%")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(scoreColor)
                } else {
                    Text("—")
                        .font(AppFonts.bodyBold(12))
                        .foregroundStyle(AppColors.sub)
                }
            }

            // Progress bar
            if score >= 0 {
                ProgressBar(
                    pct: Double(score) / 10.0 * 100.0,
                    color: score < 5 ? AppColors.red : AppColors.gold,
                    height: 4
                )
                .padding(.top, 8)
            }

            // Tip
            if !tip.isEmpty {
                Text(tip)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .lineLimit(2)
                    .padding(.top, 7)
            }
        }
        .padding(15)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Update ResultsViewModel — remove local tip methods, update retry**

Read `Parlance/Features/Results/ResultsViewModel.swift`, then replace the file:

```swift
// Parlance/Features/Results/ResultsViewModel.swift
import SwiftUI
import Combine
import SwiftData

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var isRetryingFeedback = false

    func retryFeedback(for session: Session, question: Question) async {
        isRetryingFeedback = true
        defer { isRetryingFeedback = false }

        let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String ?? ""
        guard let url = URL(string: urlString) else { return }
        let client = ClaudeClient(baseURL: url)

        let timingStats = TimingStats.empty
        let audioFeatures = AudioFeatures.empty

        guard let result = await FeedbackGenerator.fetchScoring(
            client: client,
            mode: session.mode,
            level: session.difficultyLevel,
            question: Question(id: session.question, question: session.question, coachingTips: [], targetDuration: 60, difficultyNote: "", mode: session.mode, difficultyBand: session.difficultyLevel),
            transcript: session.transcript,
            timingStats: timingStats,
            audioFeatures: audioFeatures
        ) else { return }

        session.metricScores = result.metrics.mapValues(\.score)
        session.metricTips = result.metrics.mapValues(\.tip)
        session.overallScore = result.overallScore
        session.aiCoachFeedback = result.feedback
        session.bestMomentQuote = result.bestMoment.quote
        session.bestMomentReason = result.bestMoment.reason
        session.worstMomentQuote = result.worstMoment.quote
        session.worstMomentReason = result.worstMoment.reason
        try? PersistenceService.shared.context.save()
    }
}
```

Note: `retryFeedback` requires a `Question` object but `Session` only stores the question string. Since we only have the string, construct a minimal `Question`. Check the `Question` model's initializer signature first and adjust if needed.

- [ ] **Step 3: Update ResultsView — breakdownSection and momentsSection**

Read `Parlance/Features/Results/ResultsView.swift`. Replace the `breakdownSection`, `momentsSection`, and `momentCard` methods. Everything else stays unchanged.

Replace `breakdownSection`:

```swift
private var breakdownSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        SectionHeader(title: "Breakdown")

        if session.isAIScored {
            // New AI-scored sessions: render metrics from metricScores dict
            let metrics = MetricKey.metrics(for: session.mode)
            ForEach(metrics, id: \.rawValue) { key in
                let score = session.metricScores[key.rawValue] ?? -1
                let tip = session.metricTips[key.rawValue] ?? ""
                MetricCardView(
                    name: key.displayName,
                    description: key.metricDescription,
                    score: score,
                    tip: tip
                )
            }
        } else {
            // Legacy sessions: render old fixed 5 metrics
            let fillerScore = session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1
            MetricCardView(name: "Filler Words", description: "Ums, uhs, and verbal crutches", score: fillerScore, tip: "")
            MetricCardView(name: "Pace", description: "Speaking speed and rhythm", score: session.paceScore, tip: "")
            MetricCardView(name: "Clarity", description: "How easy your words are to follow", score: session.clarityScore, tip: "")
            MetricCardView(name: "Structure", description: "Opening, body, and closing flow", score: session.structureScore, tip: "")
            MetricCardView(name: "Vocabulary", description: "Word choice strength and variety", score: session.vocabularyScore, tip: "")
        }
    }
}
```

Replace `momentsSection`:

```swift
private var momentsSection: some View {
    Group {
        if session.isAIScored {
            // New sessions: show AI quote + reason
            if !session.bestMomentQuote.isEmpty || !session.worstMomentQuote.isEmpty {
                HStack(spacing: 10) {
                    if !session.bestMomentQuote.isEmpty {
                        aiMomentCard(
                            label: "✅ BEST MOMENT",
                            quote: session.bestMomentQuote,
                            reason: session.bestMomentReason,
                            labelColor: AppColors.teal,
                            bgColor: Color(red: 0.055, green: 0.102, blue: 0.078),
                            borderColor: AppColors.teal.opacity(0.3)
                        )
                    }
                    if !session.worstMomentQuote.isEmpty {
                        aiMomentCard(
                            label: "⚠️ WEAKEST MOMENT",
                            quote: session.worstMomentQuote,
                            reason: session.worstMomentReason,
                            labelColor: AppColors.red,
                            bgColor: Color(red: 0.102, green: 0.055, blue: 0.055),
                            borderColor: AppColors.red.opacity(0.3)
                        )
                    }
                }
            }
        } else {
            // Legacy sessions: show timestamp-based moments
            HStack(spacing: 10) {
                if !session.bestMomentText.isEmpty {
                    momentCard(
                        label: "✅ BEST MOMENT",
                        timestamp: formatTimestamp(session.bestMomentTimestamp),
                        text: session.bestMomentText,
                        labelColor: AppColors.teal,
                        bgColor: Color(red: 0.055, green: 0.102, blue: 0.078),
                        borderColor: AppColors.teal.opacity(0.3)
                    )
                }
                if !session.worstMomentText.isEmpty {
                    momentCard(
                        label: "⚠️ WEAKEST MOMENT",
                        timestamp: formatTimestamp(session.worstMomentTimestamp),
                        text: session.worstMomentText,
                        labelColor: AppColors.red,
                        bgColor: Color(red: 0.102, green: 0.055, blue: 0.055),
                        borderColor: AppColors.red.opacity(0.3)
                    )
                }
            }
        }
    }
}
```

Add the `aiMomentCard` method alongside the existing `momentCard`:

```swift
private func aiMomentCard(
    label: String,
    quote: String,
    reason: String,
    labelColor: Color,
    bgColor: Color,
    borderColor: Color
) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label)
            .font(AppFonts.bodyBold(10))
            .foregroundStyle(labelColor)
            .kerning(0.5)

        Text(""\(quote)"")
            .font(AppFonts.body(11))
            .italic()
            .foregroundStyle(Color(red: 0.73, green: 0.73, blue: 0.73))
            .lineLimit(3)
            .lineSpacing(2)

        if !reason.isEmpty {
            Text(reason)
                .font(AppFonts.body(10))
                .foregroundStyle(AppColors.dim)
                .lineLimit(2)
                .lineSpacing(2)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(13)
    .background(bgColor)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(borderColor, lineWidth: 1)
    )
}
```

- [ ] **Step 4: Build and fix any compilation errors.**

- [ ] **Step 5: Commit**

```bash
git add Parlance/Features/Results/MetricCardView.swift Parlance/Features/Results/ResultsView.swift Parlance/Features/Results/ResultsViewModel.swift
git commit -m "feat: results screen shows AI-scored metrics with descriptions, AI quote moments, legacy compat"
```

---

## Task 11: Slim down SpeechAnalyzer

**Files:**
- Modify: `Parlance/Core/Services/SpeechAnalyzer.swift`

- [ ] **Step 1: Read the current SpeechAnalyzer.swift**

- [ ] **Step 2: Replace the entire file — keep only fillerRanges and analyzeFillers**

```swift
// Parlance/Core/Services/SpeechAnalyzer.swift
import Foundation

enum SpeechAnalyzer {

    struct FillerResult {
        let count: Int
        let mostFrequent: String?
    }

    private static let fillerPatterns: [(pattern: String, label: String)] = [
        ("\\b(?:um|umm|ummm)\\b", "um"),
        ("\\b(?:uh|uhh|uhhh)\\b", "uh"),
        ("\\b(?:er|err)\\b", "er"),
        ("\\b(?:ah|ahh)\\b", "ah"),
        ("\\b(?:hmm|hm|hmmm)\\b", "hmm"),
        ("\\byou know\\b", "you know"),
        ("\\bi mean\\b", "I mean"),
        ("\\blike\\b", "like"),
        ("\\bsort of\\b", "sort of"),
        ("\\bkind of\\b", "kind of"),
        ("\\bbasically\\b", "basically"),
        ("\\bliterally\\b", "literally"),
        ("\\bactually\\b", "actually"),
        ("\\bhonestly\\b", "honestly"),
        ("\\bobviously\\b", "obviously"),
        ("\\byou see\\b", "you see"),
        ("\\bthe thing is\\b", "the thing is"),
        ("\\bto be honest\\b", "to be honest"),
        ("\\bi guess\\b", "I guess")
    ]

    /// Returns character ranges of filler words in the original text.
    /// Used by the transcript UI to highlight fillers inline.
    static func fillerRanges(in text: String) -> [Range<String.Index>] {
        let lower = text.lowercased()
        var ranges: [Range<String.Index>] = []
        for (pattern, _) in fillerPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(lower.startIndex..., in: lower)
            regex.enumerateMatches(in: lower, range: nsRange) { match, _, _ in
                guard let m = match, let r = Range(m.range, in: text) else { return }
                ranges.append(r)
            }
        }
        ranges.sort { $0.lowerBound < $1.lowerBound }
        return ranges
    }

    /// Counts filler words for display in the transcript card header.
    static func analyzeFillers(in text: String) -> FillerResult {
        let lower = text.lowercased()
        var totalCount = 0
        var frequency: [String: Int] = [:]

        for (pattern, label) in fillerPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let matches = regex?.numberOfMatches(in: lower, range: NSRange(lower.startIndex..., in: lower)) ?? 0
            totalCount += matches
            if matches > 0 { frequency[label, default: 0] += matches }
        }

        let mostFrequent = frequency.max(by: { $0.value < $1.value })?.key
        return FillerResult(count: totalCount, mostFrequent: mostFrequent)
    }
}
```

- [ ] **Step 3: Build. Fix any remaining references to removed SpeechAnalyzer functions.**

Common places to check:
- `Parlance/Features/Results/ResultsViewModel.swift` — already updated in Task 10
- `Parlance/Features/Session/SessionCoordinator.swift` — already updated in Task 9
- Any other file that calls `SpeechAnalyzer.analyze()`, `SpeechAnalyzer.analyzePace()`, etc.

Run a grep to be sure: search for `SpeechAnalyzer.analyze` across the project.

- [ ] **Step 4: Commit**

```bash
git add Parlance/Core/Services/SpeechAnalyzer.swift
git commit -m "refactor: SpeechAnalyzer slimmed to filler detection only — scoring moved to AI"
```

---

## Task 12: Update ProgressViewModel.skillTrends

**Files:**
- Modify: `Parlance/Features/Progress/ProgressViewModel.swift`

- [ ] **Step 1: Read ProgressViewModel.swift**

- [ ] **Step 2: Replace the `skillTrends` method**

The current method uses `KeyPath` references to old score fields. Replace it to support both new (AI-scored) and legacy sessions:

```swift
func skillTrends(currentWeek: [Session], previousWeek: [Session]) -> [SkillTrend] {
    // Show trends for the 7 universal metrics
    let keys: [MetricKey] = MetricKey.universal

    return keys.compactMap { key in
        func avgScore(_ sessions: [Session]) -> Double {
            let scores: [Int] = sessions.compactMap { s in
                // New AI-scored sessions
                if let score = s.metricScores[key.rawValue] { return score }
                // Legacy fallback for old sessions
                switch key {
                case .pace:        return s.paceScore >= 0 ? s.paceScore : nil
                case .clarity:     return s.clarityScore >= 0 ? s.clarityScore : nil
                case .structure:   return s.structureScore >= 0 ? s.structureScore : nil
                case .vocabulary:  return s.vocabularyScore >= 0 ? s.vocabularyScore : nil
                case .fillerWords: return s.fillerCount >= 0 ? max(0, 10 - s.fillerCount) : nil
                default:           return nil
                }
            }
            guard !scores.isEmpty else { return 0 }
            return Double(scores.reduce(0, +)) / Double(scores.count)
        }

        let curr = avgScore(currentWeek)
        let prev = avgScore(previousWeek)
        guard curr > 0 || prev > 0 else { return nil }
        return SkillTrend(name: key.displayName, current: curr, previous: prev)
    }
}
```

- [ ] **Step 3: Build and verify the full project compiles cleanly.**

- [ ] **Step 4: Commit**

```bash
git add Parlance/Features/Progress/ProgressViewModel.swift
git commit -m "feat: ProgressViewModel.skillTrends supports new AI metric storage with legacy fallback"
```

---

## Task 13: Final build verification

- [ ] **Step 1: Clean build**

In Xcode: Product → Clean Build Folder (⇧⌘K), then build (⌘B). Resolve any remaining errors.

- [ ] **Step 2: Check for any remaining references to removed APIs**

Search for these patterns and confirm each is handled:
- `SpeechAnalyzer.analyze(` — should have zero results
- `SpeechAnalyzer.analyzePace(` — should have zero results
- `SpeechAnalyzer.analyzeClarity(` — should have zero results
- `SpeechAnalyzer.analyzeStructure(` — should have zero results
- `SpeechAnalyzer.analyzeVocabulary(` — should have zero results
- `SpeechAnalyzer.analyzeSubstance(` — should have zero results
- `SpeechAnalyzer.detectMoments(` — should have zero results
- `metrics.paceScore` / `metrics.clarityScore` etc. on `SpeechAnalyzer.Metrics` — should have zero results

- [ ] **Step 3: Test the session flow manually on a device or simulator**

1. Launch app — confirm it shows the no-connection screen when offline (toggle airplane mode)
2. Reconnect — confirm no-connection screen dismisses automatically
3. Complete a session — confirm the processing screen appears, AI call completes, results show
4. Check results screen: variable metrics render, moments show quotes, metric cards have descriptions
5. Check progress tab: skill trends display without crashing

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: scoring rework complete — AI scoring, delivery analysis, network gate"
```
