import SwiftUI
import Combine
import UIKit

@MainActor
final class LeagueViewModel: ObservableObject {
    @Published var countdownText: String = ""

    private var countdownTimer: Timer?
    private var notificationTokens: [NSObjectProtocol] = []

    init() {
        startCountdownTimer()

        let resignToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopCountdownTimer() }
        }

        let activeToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.startCountdownTimer() }
        }

        notificationTokens = [resignToken, activeToken]
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownText = timeUntilReset()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.countdownText = self?.timeUntilReset() ?? "" }
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    func secondsUntilReset() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date.now
        guard let nextMonday = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, weekday: 2),
            matchingPolicy: .nextTime
        ) else { return 0 }
        return nextMonday.timeIntervalSince(now)
    }

    func timeUntilReset() -> String {
        let calendar = Calendar.current
        let now = Date.now

        guard let nextMonday = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, weekday: 2), matchingPolicy: .nextTime) else {
            return "—"
        }

        let diff = calendar.dateComponents([.day, .hour, .minute], from: now, to: nextMonday)
        let days = diff.day ?? 0
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0

        return "Resets in \(days)d \(hours)h \(minutes)m"
    }

    func weeklyXP(from sessions: [Session]) -> Int {
        sessions.map(\.xpEarned).reduce(0, +)
    }

    nonisolated static func promotionStatus(
        weeklyXP: Int,
        tier: LeagueTier,
        secondsToReset: TimeInterval
    ) -> PromotionStatus {
        guard let bandEnd = tier.xpForNextTier else { return .atTop }
        let bandStart = tier.minXP
        let bandWidth = max(1, bandEnd - bandStart)
        let progress = Double(weeklyXP - bandStart) / Double(bandWidth)

        let hoursToReset = secondsToReset / 3600

        if progress >= 0.70 {
            return .eligibleForPromotion(xpRemaining: max(0, bandEnd - weeklyXP))
        }
        if tier != .bronze, progress < 0.30, hoursToReset < 24 {
            return .atRiskOfDemotion
        }
        return .safe
    }

}
