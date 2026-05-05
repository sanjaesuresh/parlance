import SwiftUI
import SwiftData

struct SessionCoordinator: View {
    let state: ActiveSessionState
    let onDismiss: () -> Void

    @State private var phase: SessionPhase = .loading
    @StateObject private var recorder = AudioRecorder()
    @EnvironmentObject private var permissionsService: PermissionsService
    @EnvironmentObject private var subscription: SubscriptionService

    enum SessionPhase {
        case loading
        case countdown
        case recording
        case processing
        case scoringFailed
        case results(Session)
    }

    @State private var autoStartRecording = false

    // Stored so scoringFailed can retry without re-transcribing
    @State private var pendingTranscript: String = ""
    @State private var pendingDuration: TimeInterval = 0
    @State private var pendingTimingStats: TimingStats = .empty
    @State private var pendingAudioFeatures: AudioFeatures = .empty
    @State private var pendingFillerCount: Int = 0
    @State private var pendingEmotionResult: EmotionResult? = nil

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            switch phase {
            case .loading:
                LoadingView(
                    mode: state.mode,
                    level: state.difficultyLevel,
                    question: state.question,
                    onReady: {
                        AnalyticsService.sessionStarted(mode: state.mode, level: state.difficultyLevel)
                        phase = .countdown
                    },
                    onCancel: { onDismiss() }
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
                    question: state.question,
                    mode: state.mode,
                    level: state.difficultyLevel,
                    recorder: recorder,
                    permissionsService: permissionsService,
                    autoStart: autoStartRecording,
                    onStop: {
                        phase = .processing
                        Task { await processSession() }
                    },
                    onCancel: { onDismiss() }
                )

            case .processing:
                VStack(spacing: 16) {
                    SwiftUI.ProgressView()
                        .tint(AppColors.gold)
                        .scaleEffect(1.5)
                    Text("Analyzing your performance…")
                        .font(AppFonts.body(16))
                        .foregroundStyle(AppColors.sub)
                }

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
                    question: state.question,
                    onTryAgain: { retrySession() },
                    onGoHome: { onDismiss() }
                )
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
        let isPro = subscription.isPro

        let transcriptionResult: TranscriptionResult?
        let audioFeatures: AudioFeatures
        let emotionResult: EmotionResult?

        if isPro {
            let apiURL = AppConstants.apiBaseURL
            async let transcriptionTask: TranscriptionResult? = {
                return try? await SpeechTranscriber.transcribe(url: audioURL)
            }()
            async let audioFeaturesTask: AudioFeatures = AudioFeatureExtractor.extract(from: audioURL)
            async let emotionTask: EmotionResult? = {
                return try? await HumeClient.analyzeEmotion(audioURL: audioURL, workerBaseURL: apiURL)
            }()
            (transcriptionResult, audioFeatures, emotionResult) = await (
                transcriptionTask,
                audioFeaturesTask,
                emotionTask
            )
        } else {
            async let transcriptionTask: TranscriptionResult? = {
                return try? await SpeechTranscriber.transcribe(url: audioURL)
            }()
            async let audioFeaturesTask: AudioFeatures = AudioFeatureExtractor.extract(from: audioURL)
            (transcriptionResult, audioFeatures) = await (transcriptionTask, audioFeaturesTask)
            emotionResult = nil
        }

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
                question: state.question.question,
                transcript: pendingTranscript,
                timingStats: pendingTimingStats,
                audioFeatures: pendingAudioFeatures,
                emotionResult: pendingEmotionResult
            )
        } catch {
            #if DEBUG
            print("[Scoring] Failed: \(error)")
            #endif
            phase = .scoringFailed
            return
        }

        let xpEarned = GamificationService.xpForSession(wasDailyChallenge: state.wasDailyChallenge)

        let session = Session(
            mode: state.mode,
            difficultyLevel: state.difficultyLevel,
            duration: pendingDuration,
            transcript: pendingTranscript,
            fillerCount: pendingFillerCount,
            question: state.question.question,
            scoringResult: scoringResult,
            xpEarned: xpEarned,
            wasDailyChallenge: state.wasDailyChallenge,
            emotionResult: pendingEmotionResult
        )

        // Analytics
        AnalyticsService.sessionCompleted(
            mode: state.mode, level: state.difficultyLevel,
            overallScore: session.overallScore, duration: pendingDuration,
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

    private func checkAchievements(user: User, session: Session, persistence: PersistenceService) {
        let totalSessions = persistence.totalSessionCount()

        if totalSessions >= 1 { persistence.unlockAchievement(id: "first_session") }

        persistence.updateAchievementProgress(id: "sessions_30", progress: totalSessions)

        if user.currentStreak >= 7 { persistence.unlockAchievement(id: "streak_7") }

        if session.overallScore >= 80 { persistence.unlockAchievement(id: "score_80") }

        if session.fillerCount == 0 && session.hasTranscript { persistence.unlockAchievement(id: "zero_fillers") }

        let interviewCount = persistence.interviewSessionCount()
        persistence.updateAchievementProgress(id: "interview_pro", progress: interviewCount)

        if user.rank.level >= 5 { persistence.unlockAchievement(id: "rank_5") }

        if user.rank.level >= 10 { persistence.unlockAchievement(id: "master") }
    }
}
