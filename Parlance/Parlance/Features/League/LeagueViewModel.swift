import SwiftUI
import Combine

@MainActor
final class LeagueViewModel: ObservableObject {
    @Published var dailyReminderEnabled = false
    @Published var soundEffectsEnabled = true
    
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

    func weeklyBestScore(from sessions: [Session]) -> Int {
        sessions.map(\.overallScore).max() ?? 0
    }
}
