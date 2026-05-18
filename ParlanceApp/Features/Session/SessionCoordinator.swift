import SwiftUI
import SwiftData

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

    init(
        state: ActiveSessionState,
        currentUserID: String?,
        onReshuffleQuestion: ((ExplanationCategory) -> Question?)? = nil,
        onDismiss: @escaping () -> Void,
        onEditScenario: ((String) -> Void)? = nil
    ) {
        self.state = state
        self.currentUserID = currentUserID
        self.onReshuffleQuestion = onReshuffleQuestion
        self.onDismiss = onDismiss
        self.onEditScenario = onEditScenario
        self._currentQuestion = State(initialValue: state.question)
        let seededUser = currentUserID.flatMap { PersistenceService.shared.getUser(uid: $0) }
        self._currentTopicCategory = State(
            initialValue: state.mode == .explanation
                ? (seededUser?.lastExplanationCategory ?? .any)
                : nil
        )
    }

    enum SessionPhase: Equatable {
        case loading
        case countdown
        case recording
        case processing
        case scoringFailed
        case results(Session)

        static func == (lhs: SessionPhase, rhs: SessionPhase) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.countdown, .countdown): return true
            case (.recording, .recording): return true
            case (.processing, .processing): return true
            case (.scoringFailed, .scoringFailed): return true
            case let (.results(a), .results(b)): return a === b
            default: return false
            }
        }
    }

    @State private var autoStartRecording = false

    // Stored so scoringFailed can retry without re-transcribing
    @State private var pendingTranscript: String = ""
    @State private var pendingDuration: TimeInterval = 0
    @State private var pendingTimingStats: TimingStats = .empty
    @State private var pendingAudioFeatures: AudioFeatures = .empty
    @State private var pendingFillerCount: Int = 0
    @State private var pendingEmotionResult: EmotionResult? = nil
    @State private var pendingEmotionAnalysisFailed: Bool = false

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
                    onCancel: { onDismiss() },
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
                        Task { await processSession() }
                    },
                    onCancel: {
                        onDismiss()
                    }
                )

            case .processing:
                AnalyzingView()

            case .scoringFailed:
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.red)
                    Text("Scoring unavailable")
                        .font(AppFonts.display(20))
                        .foregroundStyle(AppColors.text)
                    Text("Couldn't reach the scoring service.\nCheck your connection and try again.")
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("Discard") { onDismiss() }
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.sub)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Retry") {
                            phase = .processing
                            Task { await scoreAndSave() }
                        }
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.bg)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(32)

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
        }
    }

    private func retrySession() {
        // Reset recorder state and go back to loading → recording flow
        recorder.deleteRecording()
        phase = .loading
    }

    @MainActor
    private func processSession() async {
        guard let audioURL = recorder.stopRecording() else {
            onDismiss()
            return
        }

        let duration = recorder.elapsedTime

        let transcriptionResult: TranscriptionResult?
        let audioFeatures: AudioFeatures
        let emotionResult: EmotionResult?
        let emotionFailed: Bool

        let shouldAnalyzeEmotion = subscription.isPro
        let apiURL = AppConstants.apiBaseURL

        async let transcriptionTask: TranscriptionResult? = {
            return try? await SpeechTranscriber.transcribe(url: audioURL)
        }()
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

        let emotionOutcome: (result: EmotionResult?, failed: Bool)
        (transcriptionResult, audioFeatures, emotionOutcome) = await (transcriptionTask, audioFeaturesTask, emotionTask)
        emotionResult = emotionOutcome.result
        emotionFailed = emotionOutcome.failed

        // Delete audio file — no longer needed
        recorder.deleteRecording()

        let transcript = transcriptionResult?.transcript ?? ""
        let segments = transcriptionResult?.segments ?? []
        let timingStats = TimingStats.compute(from: segments, totalDuration: duration)
        let fillerCount = transcript.isEmpty ? 0 : SpeechAnalyzer.analyzeFillers(in: transcript).count

        // Store for retry from scoringFailed state
        pendingTranscript = transcript
        pendingDuration = duration
        pendingTimingStats = timingStats
        pendingAudioFeatures = audioFeatures
        pendingFillerCount = fillerCount
        pendingEmotionResult = emotionResult
        pendingEmotionAnalysisFailed = emotionFailed

        await scoreAndSave()
    }

    @MainActor
    private func scoreAndSave() async {
        let client = ClaudeClient(baseURL: AppConstants.apiBaseURL)

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
        } catch {
            #if DEBUG
            print("[Scoring] AI unavailable, using local scoring: \(error)")
            #endif
            scoringResult = FeedbackGenerator.localScoringResult(
                fillerCount: pendingFillerCount,
                duration: pendingDuration,
                timingStats: pendingTimingStats,
                transcript: pendingTranscript,
                mode: state.mode
            )
        }

        // Fetch personal best once — used by both xpForSession and awardXP
        let social = SocialService()
        let previousBest = await social.fetchPersonalBest(mode: state.mode)

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

        // Persist
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
                score: session.overallScore,
                mode: state.mode,
                level: state.difficultyLevel
            )
        }

        phase = .results(session)
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
