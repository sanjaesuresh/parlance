import SwiftUI

struct SessionCoordinator: View {
    let state: ActiveSessionState
    let onDismiss: () -> Void

    @State private var phase: SessionPhase = .loading
    @StateObject private var recorder = AudioRecorder()
    @EnvironmentObject private var permissionsService: PermissionsService

    enum SessionPhase {
        case loading
        case recording
        case processing
        case results(Session)
    }

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            switch phase {
            case .loading:
                LoadingView(
                    mode: state.mode,
                    levelName: DifficultyLevel.name(for: state.difficultyLevel),
                    tier: DifficultyLevel.tier(for: state.difficultyLevel)
                ) {
                    phase = .recording
                }

            case .recording:
                RecordingView(
                    question: state.question,
                    mode: state.mode,
                    level: state.difficultyLevel,
                    recorder: recorder,
                    permissionsService: permissionsService
                ) {
                    phase = .processing
                    Task { await processSession() }
                }

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
                    onTryAgain: { onDismiss() },
                    onGoHome: { onDismiss() }
                )
            }
        }
    }

    @MainActor
    private func processSession() async {
        guard let audioURL = recorder.stopRecording() else {
            onDismiss()
            return
        }

        let duration = recorder.elapsedTime

        // Transcribe
        var transcript = ""
        do {
            transcript = try await SpeechTranscriber.transcribe(url: audioURL)
        } catch {
            // Transcription failed — continue with empty transcript
        }

        // Delete audio file immediately
        recorder.deleteRecording()

        // Analyze metrics
        let metrics: SpeechAnalyzer.Metrics
        if transcript.isEmpty {
            metrics = SpeechAnalyzer.Metrics(
                fillerScore: -1, fillerCount: -1,
                paceScore: -1, wpm: 0,
                clarityScore: -1, structureScore: -1, vocabularyScore: -1
            )
        } else {
            metrics = SpeechAnalyzer.analyze(transcript: transcript, duration: duration, mode: state.mode)
        }

        let overallScore = transcript.isEmpty ? 0 : metrics.overallScore

        // Best/worst moments
        let moments = transcript.isEmpty
            ? SpeechAnalyzer.Moments(bestTimestamp: 0, bestText: "", worstTimestamp: 0, worstText: "")
            : SpeechAnalyzer.detectMoments(in: transcript, duration: duration)

        // Calculate XP
        let xpEarned = GamificationService.xpForSession(wasDailyChallenge: state.wasDailyChallenge)

        // Create session record
        let session = Session(
            mode: state.mode,
            difficultyLevel: state.difficultyLevel,
            duration: duration,
            transcript: transcript,
            overallScore: overallScore,
            fillerCount: metrics.fillerCount,
            paceScore: metrics.paceScore,
            clarityScore: metrics.clarityScore,
            structureScore: metrics.structureScore,
            vocabularyScore: metrics.vocabularyScore,
            question: state.question.question,
            bestMomentTimestamp: moments.bestTimestamp,
            bestMomentText: moments.bestText,
            worstMomentTimestamp: moments.worstTimestamp,
            worstMomentText: moments.worstText,
            xpEarned: xpEarned,
            wasDailyChallenge: state.wasDailyChallenge
        )

        // Persist
        let persistence = PersistenceService.shared
        persistence.saveSession(session)

        // Mark question seen
        persistence.markQuestionSeen(
            questionId: state.question.id,
            mode: state.mode,
            band: state.question.difficultyBand
        )

        // Update user gamification
        if let user = persistence.getUser() {
            GamificationService.awardXP(to: user, wasDailyChallenge: state.wasDailyChallenge)
            GamificationService.updateStreak(for: user)
            GamificationService.incrementDailySessionCount(for: user)

            // Mark daily challenge completed
            if state.wasDailyChallenge {
                user.dailyChallengeCompletedDate = .now
            }

            // Check achievements
            checkAchievements(user: user, session: session, persistence: persistence)
        }

        // Fire AI feedback async (non-blocking)
        if !transcript.isEmpty {
            Task {
                // Use baseURL init to avoid fatalError if Info.plist key missing
                let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String ?? ""
                guard let url = URL(string: urlString) else { return }
                let client = ClaudeClient(baseURL: url)

                let feedback = await FeedbackGenerator.fetchFeedback(
                    client: client,
                    mode: state.mode,
                    level: state.difficultyLevel,
                    question: state.question.question,
                    duration: duration,
                    overallScore: overallScore,
                    fillerCount: metrics.fillerCount,
                    paceScore: metrics.paceScore,
                    clarityScore: metrics.clarityScore,
                    structureScore: metrics.structureScore,
                    vocabularyScore: metrics.vocabularyScore,
                    transcript: transcript
                )
                await MainActor.run {
                    session.aiCoachFeedback = feedback
                    try? PersistenceService.shared.context.save()
                }
            }
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
