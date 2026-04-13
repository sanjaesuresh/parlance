import SwiftUI
import SwiftData

struct SessionCoordinator: View {
    let state: ActiveSessionState
    let onDismiss: () -> Void

    @State private var phase: SessionPhase = .loading
    @StateObject private var recorder = AudioRecorder()
    @EnvironmentObject private var permissionsService: PermissionsService

    enum SessionPhase {
        case loading
        case countdown
        case recording
        case processing
        case results(Session)
    }

    @State private var autoStartRecording = false

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
                    ProgressView()
                        .tint(AppColors.gold)
                        .scaleEffect(1.5)
                    Text("Analyzing your performance…")
                        .font(AppFonts.body(16))
                        .foregroundStyle(AppColors.sub)
                }

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

        // Fetch AI scoring — blocking call before showing results
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

        // Fall back to a zeroed result if AI fails
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
