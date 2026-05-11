import SwiftUI

struct HomeGreeting: View {
    let user: User
    let hasSessionsEver: Bool
    let leveledUpRecently: Bool

    private enum Variant {
        case firstEver
        case brokenStreakReturned
        case challengeDoneToday
        case sevenDayStreak
        case leveledUp
        case standard
    }

    private var variant: Variant {
        if !hasSessionsEver { return .firstEver }
        if user.currentStreak == 1, let last = user.lastSessionDate,
           Calendar.current.isDateInToday(last) == false,
           Calendar.current.isDateInYesterday(last) == false {
            return .brokenStreakReturned
        }
        if user.hasDailyChallengeCompletedToday { return .challengeDoneToday }
        if leveledUpRecently { return .leveledUp }
        if user.currentStreak >= 7 { return .sevenDayStreak }
        return .standard
    }

    private var eyebrow: String {
        if variant == .firstEver { return "Welcome" }
        let weekday = Date.now.formatted(.dateTime.weekday(.wide))
        return "\(weekday) · Day \(max(user.currentStreak, 1))"
    }

    private var headline: String {
        switch variant {
        case .firstEver:              return "Time to begin."
        case .brokenStreakReturned:   return "The streak resets."
        case .challengeDoneToday:     return "Today's challenge done."
        case .sevenDayStreak:         return "Steady work this week."
        case .leveledUp:              return "Level \(user.rank.level) unlocked."
        case .standard:               return "Day \(max(user.currentStreak, 1))."
        }
    }

    private var imperative: String {
        switch variant {
        case .firstEver:              return "Let's go."
        case .brokenStreakReturned:   return "Start it again."
        case .challengeDoneToday:     return "Want another go?"
        case .sevenDayStreak:         return "Show up again."
        case .leveledUp:              return "Hold the line."
        case .standard:               return "One more."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(AppFonts.bodyBold(10))
                .kerning(1.6)
                .foregroundStyle(AppColors.dim)

            (Text(headline)
                .foregroundStyle(AppColors.text)
             + Text(" ")
             + Text(imperative)
                .italic()
                .foregroundStyle(AppColors.gold))
                .font(AppFonts.display(28))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline) \(imperative)")
    }
}
