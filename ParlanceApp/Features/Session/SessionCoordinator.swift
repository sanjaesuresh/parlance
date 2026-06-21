import SwiftUI
import SwiftData
import AVFoundation

struct SessionCoordinator: View {
    let state: ActiveSessionState
    let currentUserID: String?
    let onReshuffleQuestion: ((ExplanationCategory) -> Question?)?
    let onDismiss: () -> Void
    var onEditScenario: ((String) -> Void)? = nil

    @State private var currentQuestion: Question
    @State private var currentTopicCategory: ExplanationCategory?
    @State private var phase: SessionPhase = .loading
    @StateObject private var recorder = AudioRecorder()
    @EnvironmentObject private var permissionsService: PermissionsService
    @EnvironmentObject private var subscription: SubscriptionService

    /// When non-nil, the coordinator jumps directly into `.processing` using
    /// the supplied audio file rather than entering loading → countdown →
    /// recording. Used by the cold-start recovery path.
    private let resumedAudioURL: URL?

    init(
        state: ActiveSessionState,
        currentUserID: String?,
        onReshuffleQuestion: ((ExplanationCategory) -> Question?)? = nil,
        onDismiss: @escaping () -> Void,
        onEditScenario: ((String) -> Void)? = nil,
        resumedAudioURL: URL? = nil
    ) {
        self.state = state
        self.currentUserID = currentUserID
        self.onReshuffleQuestion = onReshuffleQuestion
        self.onDismiss = onDismiss
        self.onEditScenario = onEditScenario
        self.resumedAudioURL = resumedAudioURL
        self._currentQuestion = State(initialValue: state.question)
        let seededUser = currentUserID.flatMap { PersistenceService.shared.getUser(uid: $0) }
        self._currentTopicCategory = State(
            initialValue: state.mode == .explanation
                ? (seededUser?.lastExplanationCategory ?? .any)
                : nil
        )
        self._phase = State(initialValue: resumedAudioURL == nil ? .loading : .processing)
    }

    enum SessionPhase: Equatable {
        case loading
        case countdown
        case recording
        case processing
        case cannotAnalyze(reason: CannotAnalyzeReason)
        case results(Session)

        static func == (lhs: SessionPhase, rhs: SessionPhase) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.countdown, .countdown): return true
            case (.recording, .recording): return true
            case (.processing, .processing): return true
            case let (.cannotAnalyze(a), .cannotAnalyze(b)): return a == b
            case let (.results(a), .results(b)): return a === b
            default: return false
            }
        }
    }

    @State private var autoStartRecording = false

    // Carries transcription output from processSession into scoreAndSave.
    @State private var pendingTranscript: String = ""
    @State private var pendingDuration: TimeInterval = 0
    @State private var pendingTimingStats: TimingStats = .empty
    @State private var pendingAudioFeatures: AudioFeatures = .empty
    @State private var pendingFillerCount: Int = 0
    @State private var pendingEmotionResult: EmotionResult? = nil
    @State private var pendingEmotionAnalysisFailed: Bool = false
    @State private var pendingTranscriptionFailed: Bool = false

    /// Holds the in-flight processing/scoring work so a user dismiss can
    /// cancel it. Without this, discarding during `.processing` left the
    /// Task running to completion and silently committed the session,
    /// awarded XP, and queued a sync — even though the user had walked
    /// away. Cancellation checks in `scoreAndSave` bail before any
    /// persistent write or external side-effect.
    @State private var scoringTask: Task<Void, Never>?

    /// Set once the session row + XP have been persisted, so a stray
    /// re-entry into scoreAndSave can't double-commit.
    @State private var hasCommitted: Bool = false

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            switch phase {
            case .loading:
                LoadingView(
                    mode: state.mode,
                    level: state.difficultyLevel,
                    question: currentQuestion,
                    onReady: {
                        phase = .countdown
                    },
                    onCancel: { dismiss() },
                    currentTopicCategory: currentTopicCategory,
                    onReshuffleTopic: { newCategory in
                        if let newQuestion = onReshuffleQuestion?(newCategory) {
                            currentQuestion = newQuestion
                            currentTopicCategory = newCategory
                        }
                    },
                    onPromptRewritten: { rewritten in
                        currentQuestion = Question(
                            id: currentQuestion.id,
                            mode: currentQuestion.mode,
                            difficultyBand: currentQuestion.difficultyBand,
                            question: rewritten,
                            tips: currentQuestion.tips,
                            targetDuration: currentQuestion.targetDuration,
                            difficultyNote: currentQuestion.difficultyNote,
                            category: currentQuestion.category
                        )
                    },
                    onEditScenario: { originalScenario in
                        onEditScenario?(originalScenario)
                    }
                )

            case .countdown:
                CountdownView(
                    accentColor: state.mode.accentColor,
                    onComplete: {
                        autoStartRecording = true
                        phase = .recording
                    }
                )

            case .recording:
                RecordingView(
                    question: currentQuestion,
                    mode: state.mode,
                    level: state.difficultyLevel,
                    recorder: recorder,
                    permissionsService: permissionsService,
                    autoStart: autoStartRecording,
                    onStop: {
                        phase = .processing
                        scoringTask?.cancel()
                        scoringTask = Task { await processSession() }
                    },
                    onCancel: {
                        dismiss()
                    },
                    onInterrupted: {
                        // Phone call / system interruption stopped the recorder
                        // mid-session. Surface explicitly rather than silently
                        // auto-processing a partial clip.
                        ActiveSessionPersistence.shared.clear()
                        recorder.deleteRecording()
                        phase = .cannotAnalyze(reason: .interrupted)
                    }
                )

            case .processing:
                AnalyzingView()

            case .cannotAnalyze(let reason):
                CannotAnalyzeView(
                    reason: reason,
                    onRetry: { retrySession() },
                    onDiscard: { dismiss() }
                )

            case .results(let session):
                ResultsView(
                    session: session,
                    question: currentQuestion,
                    toneAnalysisFailed: pendingEmotionAnalysisFailed,
                    onTryAgain: { retrySession() },
                    onGoHome: { onDismiss() }
                )
            }
        }
        .onChange(of: phase) { _, newPhase in
            if case .processing = newPhase, state.mode == .realLife {
                RealLifeScenarioHistoryStore.shared.record(state.question.question)
            }
            if case .processing = newPhase {
                ActiveSessionPersistence.shared.updatePhase(.processing)
            }
        }
        .onChange(of: recorder.isRecording) { oldValue, newValue in
            // Persist manifest the moment the file exists on disk — this is
            // the earliest point at which we have something worth recovering.
            if !oldValue, newValue, let url = recorder.recordingURL {
                ActiveSessionPersistence.shared.write(
                    audioURL: url,
                    state: state,
                    phase: .recording
                )
            }
        }
        .onAppear {
            if let url = resumedAudioURL {
                scoringTask = Task { await processResumedSession(audioURL: url) }
            }
        }
    }

    /// Wraps the throwing transcribe call so callers can distinguish "user
    /// stayed silent" (success with empty transcript) from "transcription
    /// blew up" (network/timeout/recognizer-unavailable). Previously these
    /// collapsed into the same `try? await` empty-string sentinel and the
    /// pre-flight word-count gate misreported the latter as `.tooShort`.
    private static func runTranscription(url: URL) async -> (result: TranscriptionResult?, failed: Bool) {
        do {
            let result = try await SpeechTranscriber.transcribe(url: url)
            return (result, false)
        } catch {
            return (nil, true)
        }
    }

    /// Recovery entry point: skip recorder lifecycle, drive the existing
    /// processing pipeline with audio that already exists on disk.
    @MainActor
    private func processResumedSession(audioURL: URL) async {
        let duration: TimeInterval = {
            guard let file = try? AVAudioFile(forReading: audioURL) else { return 0 }
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { return 0 }
            return Double(file.length) / sampleRate
        }()

        let shouldAnalyzeEmotion = subscription.isPro
        let apiURL = AppConstants.apiBaseURL

        async let transcriptionTask: (result: TranscriptionResult?, failed: Bool) = Self.runTranscription(url: audioURL)
        async let audioFeaturesTask: AudioFeatures = AudioFeatureExtractor.extract(from: audioURL)
        async let emotionTask: (result: EmotionResult?, failed: Bool) = {
            guard shouldAnalyzeEmotion else { return (nil, false) }
            do {
                let result = try await HumeClient.analyzeEmotion(audioURL: audioURL, workerBaseURL: apiURL)
                return (result, false)
            } catch {
                return (nil, true)
            }
        }()

        let (transcriptionOutcome, audioFeatures, emotionOutcome) = await (transcriptionTask, audioFeaturesTask, emotionTask)

        try? FileManager.default.removeItem(at: audioURL)

        if Task.isCancelled { return }

        let transcript = transcriptionOutcome.result?.transcript ?? ""
        let segments = transcriptionOutcome.result?.segments ?? []
        let timingStats = TimingStats.compute(from: segments, totalDuration: duration)
        let fillerCount = transcript.isEmpty ? 0 : SpeechAnalyzer.analyzeFillers(in: transcript).count

        pendingTranscript = transcript
        pendingDuration = duration
        pendingTimingStats = timingStats
        pendingAudioFeatures = audioFeatures
        pendingFillerCount = fillerCount
        pendingEmotionResult = emotionOutcome.result
        pendingEmotionAnalysisFailed = emotionOutcome.failed
        pendingTranscriptionFailed = transcriptionOutcome.failed && transcript.isEmpty

        await scoreAndSave()
    }

    private func retrySession() {
        // A fresh session — clear the prior commit guard so the next score
        // can commit, and drop the captured audio so the recorder starts
        // clean.
        scoringTask?.cancel()
        scoringTask = nil
        hasCommitted = false
        pendingTranscriptionFailed = false
        recorder.deleteRecording()
        phase = .loading
    }

    @MainActor
    private func processSession() async {
        guard let audioURL = recorder.stopRecording() else {
            dismiss()
            return
        }

        let duration = recorder.elapsedTime

        let transcriptionResult: TranscriptionResult?
        let audioFeatures: AudioFeatures
        let emotionResult: EmotionResult?
        let emotionFailed: Bool

        let shouldAnalyzeEmotion = subscription.isPro
        let apiURL = AppConstants.apiBaseURL

        async let transcriptionTask: (result: TranscriptionResult?, failed: Bool) = Self.runTranscription(url: audioURL)
        async let audioFeaturesTask: AudioFeatures = AudioFeatureExtractor.extract(from: audioURL)
        async let emotionTask: (result: EmotionResult?, failed: Bool) = {
            guard shouldAnalyzeEmotion else { return (nil, false) }
            do {
                let result = try await HumeClient.analyzeEmotion(audioURL: audioURL, workerBaseURL: apiURL)
                return (result, false)
            } catch {
                #if DEBUG
                print("[Hume] tone analysis failed: \(error)")
                #endif
                return (nil, true)
            }
        }()

        let transcriptionOutcome: (result: TranscriptionResult?, failed: Bool)
        let emotionOutcome: (result: EmotionResult?, failed: Bool)
        (transcriptionOutcome, audioFeatures, emotionOutcome) = await (transcriptionTask, audioFeaturesTask, emotionTask)
        transcriptionResult = transcriptionOutcome.result
        emotionResult = emotionOutcome.result
        emotionFailed = emotionOutcome.failed

        // Delete audio file — no longer needed
        recorder.deleteRecording()

        if Task.isCancelled { return }

        let transcript = transcriptionResult?.transcript ?? ""
        let segments = transcriptionResult?.segments ?? []
        let timingStats = TimingStats.compute(from: segments, totalDuration: duration)
        let fillerCount = transcript.isEmpty ? 0 : SpeechAnalyzer.analyzeFillers(in: transcript).count

        // Stash for scoreAndSave.
        pendingTranscript = transcript
        pendingDuration = duration
        pendingTimingStats = timingStats
        pendingAudioFeatures = audioFeatures
        pendingFillerCount = fillerCount
        pendingEmotionResult = emotionResult
        pendingEmotionAnalysisFailed = emotionFailed
        pendingTranscriptionFailed = transcriptionOutcome.failed && transcript.isEmpty

        await scoreAndSave()
    }

    @MainActor
    private func scoreAndSave() async {
        // Bail if we've already committed this session — guards against any
        // stray re-entry double-committing.
        if hasCommitted { return }
        if Task.isCancelled { return }

        let client = FeedbackClient(baseURL: AppConstants.apiBaseURL)

        // Pre-flight gate 0: transcription itself failed (network/timeout/
        // recognizer-unavailable). Distinct from "user stayed silent" — the
        // word-count gate below would have misreported it as `.tooShort`.
        if pendingTranscriptionFailed {
            #if DEBUG
            print("[Scoring] pre-flight: transcription failed")
            #endif
            ActiveSessionPersistence.shared.clear()
            phase = .cannotAnalyze(reason: .transcriptionFailed)
            return
        }

        // Pre-flight gate 1: transcript too short.
        let wordCount = pendingTranscript
            .split { !$0.isLetter && !$0.isNumber }
            .count
        if wordCount < 10 {
            #if DEBUG
            print("[Scoring] pre-flight: transcript too short (\(wordCount) words)")
            #endif
            ActiveSessionPersistence.shared.clear()
            phase = .cannotAnalyze(reason: .tooShort)
            return
        }

        // Pre-flight gate 2: profanity ratio / slurs.
        let scan = ProfanityFilter.scanTranscript(pendingTranscript)
        if scan.containsSlur || scan.ratio >= 0.20 {
            #if DEBUG
            print("[Scoring] pre-flight: profanity gate (slur=\(scan.containsSlur), ratio=\(scan.ratio))")
            #endif
            ActiveSessionPersistence.shared.clear()
            phase = .cannotAnalyze(reason: .inappropriateContent)
            return
        }

        if Task.isCancelled { return }

        let scoringResult: ScoringResult
        do {
            scoringResult = try await FeedbackGenerator.fetchScoring(
                client: client,
                mode: state.mode,
                level: state.difficultyLevel,
                question: currentQuestion.question,
                transcript: pendingTranscript,
                timingStats: pendingTimingStats,
                audioFeatures: pendingAudioFeatures,
                emotionResult: pendingEmotionResult
            )
        } catch let scoringError as ScoringError {
            switch scoringError {
            case .refused(let reason):
                #if DEBUG
                print("[Scoring] refused: \(reason)")
                #endif
                let mapped: CannotAnalyzeReason
                switch reason {
                case "inappropriate_content": mapped = .inappropriateContent
                default:                      mapped = .modelRefused
                }
                ActiveSessionPersistence.shared.clear()
                phase = .cannotAnalyze(reason: mapped)
                return
            case .parseFailure:
                #if DEBUG
                print("[Scoring] parse failure")
                #endif
                ActiveSessionPersistence.shared.clear()
                phase = .cannotAnalyze(reason: .modelRefused)
                return
            }
        } catch {
            // Network / upstream — fall back to a local heuristic score so
            // the user gets a result rather than a dead-end retry screen.
            // The Session is saved with `aiCoachFeedback == nil`, which is
            // the signal for ResultsView and `ResultsViewModel.retryFeedback`
            // to offer "Retry for full coach feedback" when the network
            // recovers.
            #if DEBUG
            print("[Scoring] network/upstream error — falling back to local score: \(error)")
            #endif
            scoringResult = FeedbackGenerator.localScoringResult(
                fillerCount: pendingFillerCount,
                duration: pendingDuration,
                timingStats: pendingTimingStats,
                transcript: pendingTranscript,
                mode: state.mode
            )
        }

        if let relevance = scoringResult.relevanceToPrompt, relevance < 12 {
            #if DEBUG
            print("[Scoring] off-topic: relevance=\(relevance)")
            #endif
            ActiveSessionPersistence.shared.clear()
            phase = .cannotAnalyze(reason: .offTopic)
            return
        }

        // Last chance to bail before any persistent write or external
        // side-effect. After this point, the session is committed.
        if Task.isCancelled { return }

        // Fetch personal best once — used by both xpForSession and awardXP
        let social = SocialService()
        let previousBest = await social.fetchPersonalBest(mode: state.mode)

        if Task.isCancelled { return }

        let xpEarned = GamificationService.xpForSession(
            wasDailyChallenge: state.wasDailyChallenge,
            score: scoringResult.overallScore,
            difficultyLevel: state.difficultyLevel,
            previousBest: previousBest,
            currentStreak: PersistenceService.shared.getUser(uid: currentUserID ?? "")?.currentStreak ?? 0
        )

        let session = Session(
            mode: state.mode,
            difficultyLevel: state.difficultyLevel,
            duration: pendingDuration,
            transcript: pendingTranscript,
            fillerCount: pendingFillerCount,
            question: currentQuestion.question,
            scoringResult: scoringResult,
            xpEarned: xpEarned,
            wasDailyChallenge: state.wasDailyChallenge,
            emotionResult: pendingEmotionResult
        )

        // Persist — from here on we treat the session as committed.
        hasCommitted = true
        let persistence = PersistenceService.shared
        persistence.saveSession(session)
        persistence.markQuestionSeen(
            questionId: currentQuestion.id,
            mode: state.mode,
            band: currentQuestion.difficultyBand
        )

        // Gamification
        if let uid = currentUserID, let user = persistence.getUser(uid: uid) {
            GamificationService.awardXP(
                to: user,
                wasDailyChallenge: state.wasDailyChallenge,
                score: session.overallScore,
                difficultyLevel: state.difficultyLevel,
                previousBest: previousBest,
                currentStreak: user.currentStreak
            )
            SoundService.play(.sessionComplete)
            GamificationService.updateStreak(for: user)
            GamificationService.incrementDailySessionCount(for: user)
            if state.wasDailyChallenge { user.dailyChallengeCompletedDate = .now }
            if previousBest == nil || session.overallScore > (previousBest ?? -1) {
                await social.recordPersonalBest(mode: state.mode, score: session.overallScore)
            }
            checkAchievements(user: user, session: session, persistence: persistence)
        }

        Task {
            await SyncService.shared.syncAfterSession(
                clientSessionId: session.id,
                score: session.overallScore,
                mode: state.mode,
                level: state.difficultyLevel
            )
        }

        ActiveSessionPersistence.shared.clear()
        phase = .results(session)
    }

    /// User-cancel from any phase. Cancels any in-flight processing/scoring
    /// Task so it stops before saving, awarding XP, or syncing; clears the
    /// recovery manifest so the next launch doesn't prompt about an aborted
    /// recording. Previously the spawned Task ran to completion regardless
    /// of dismiss, silently committing a session the user thought they
    /// discarded.
    private func dismiss() {
        scoringTask?.cancel()
        scoringTask = nil
        ActiveSessionPersistence.shared.clear()
        onDismiss()
    }

    // MARK: - Achievements

    private func checkAchievements(user: User, session: Session, persistence: PersistenceService) {
        let totalSessions = persistence.totalSessionCount()

        // --- Volume ---
        if totalSessions >= 1 { persistence.unlockAchievement(id: "first_session") }
        persistence.updateAchievementProgress(id: "sessions_30", progress: totalSessions)

        let totalSpoken = persistence.totalSpokenSeconds()
        persistence.updateAchievementProgress(id: "spoke_10h", progress: totalSpoken)

        // --- Streak ---
        persistence.updateAchievementProgress(id: "streak_3", progress: user.currentStreak)
        if user.currentStreak >= 7 { persistence.unlockAchievement(id: "streak_7") }
        persistence.updateAchievementProgress(id: "streak_30", progress: user.currentStreak)
        persistence.updateAchievementProgress(id: "streak_100", progress: user.currentStreak)

        // --- Score (single session) ---
        if session.overallScore >= 80  { persistence.unlockAchievement(id: "score_80") }
        if session.overallScore >= 90  { persistence.unlockAchievement(id: "score_90") }
        if session.overallScore >= 100 { persistence.unlockAchievement(id: "score_100") }

        // --- Quality ---
        if session.fillerCount == 0 && session.hasTranscript { persistence.unlockAchievement(id: "zero_fillers") }

        // --- Consistency (lifetime avg, gated on ≥10 sessions to avoid trivial unlocks) ---
        if totalSessions >= 10 {
            let avg = persistence.lifetimeAverageScore()
            if avg >= 80 { persistence.unlockAchievement(id: "avg_80") }
            if avg >= 90 { persistence.unlockAchievement(id: "avg_90") }
        }

        // --- Variety ---
        persistence.updateAchievementProgress(id: "tour_modes", progress: persistence.distinctFreeModesPracticed())
        let interviewCount = persistence.interviewSessionCount()
        persistence.updateAchievementProgress(id: "interview_pro", progress: interviewCount)

        // --- Mastery ---
        if user.rank.level >= 5  { persistence.unlockAchievement(id: "rank_5") }
        if user.rank.level >= 10 { persistence.unlockAchievement(id: "master") }
    }
}

// MARK: - Analyzing View

private struct AnalyzingView: View {
    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()
            VStack(spacing: 28) {
                HStack(alignment: .bottom, spacing: 0) {
                    Text("P")
                        .font(AppFonts.display(64))
                        .foregroundStyle(AppColors.text)
                    Text(".")
                        .font(AppFonts.display(64))
                        .foregroundStyle(AppColors.gold)
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Analyzing your performance")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.text)
                    HStack(spacing: 3) {
                        BouncingDot(delay: 0.00)
                        BouncingDot(delay: 0.20)
                        BouncingDot(delay: 0.40)
                    }
                    .padding(.leading, 3)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                    .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct BouncingDot: View {
    let delay: Double
    @State private var lifted = false

    var body: some View {
        Circle()
            .fill(AppColors.gold)
            .frame(width: 4, height: 4)
            .offset(y: lifted ? -6 : 0)
            .opacity(lifted ? 1 : 0.45)
            .task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                while !Task.isCancelled {
                    // Rise slowly — working against gravity
                    withAnimation(.easeOut(duration: 0.36)) { lifted = true }
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    // Fall fast — pulled by gravity
                    withAnimation(.easeIn(duration: 0.20)) { lifted = false }
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                }
            }
    }
}

#Preview("Analyzing") {
    AnalyzingView()
}
