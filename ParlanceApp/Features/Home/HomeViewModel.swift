import SwiftUI
import SwiftData
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    private let questionBank: QuestionBankService
    @Published var showRateLimitAlert = false

    init() {
        self.questionBank = QuestionBankService()
    }

    init(questionBank: QuestionBankService) {
        self.questionBank = questionBank
    }

    func startSession(
        mode: SessionMode,
        user: User,
        persistence: PersistenceService,
        wasDailyChallenge: Bool,
        isPro: Bool = false
    ) -> ActiveSessionState? {
        let sessionLimit = isPro ? AppConstants.maxSessionsPerDay : AppConstants.freeSessionsPerDay
        guard user.dailySessionCount < sessionLimit else {
            showRateLimitAlert = true
            return nil
        }

        let level = effectiveDifficultyLevel(for: user, wasDailyChallenge: wasDailyChallenge)
        let band = DifficultyLevel.band(for: level)
        let seenIds = persistence.seenQuestionIds(mode: mode, band: band)

        let category: ExplanationCategory? = (mode == .explanation) ? user.lastExplanationCategory : nil

        guard let question = questionBank.selectQuestion(
            mode: mode,
            band: band,
            category: category,
            excludingIds: seenIds
        ) else {
            return nil
        }

        return ActiveSessionState(
            mode: mode,
            difficultyLevel: level,
            question: question,
            wasDailyChallenge: wasDailyChallenge
        )
    }

    func dailyChallengeMode() -> SessionMode {
        return SessionMode.dailyChallengeMode()
    }

    func lockDailyChallengeLevel(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let lockDate = user.dailyChallengeLockDate,
           calendar.startOfDay(for: lockDate) == today {
            return
        }

        user.dailyChallengeLevelLock = user.practiceLevel
        user.dailyChallengeLockDate = .now
    }

    private func effectiveDifficultyLevel(for user: User, wasDailyChallenge: Bool) -> Int {
        if wasDailyChallenge, let locked = user.dailyChallengeLevelLock {
            return locked
        }
        return user.practiceLevel
    }

    func weeklyStats(sessions: [Session]) -> (count: Int, avgScore: Int, bestScore: Int, fillerTotal: Int) {
        guard !sessions.isEmpty else { return (0, 0, 0, 0) }
        let count = sessions.count
        let avgScore = sessions.map(\.overallScore).reduce(0, +) / count
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let fillerTotal = sessions.map(\.fillerCount).reduce(0, +)
        return (count, avgScore, bestScore, fillerTotal)
    }
}
