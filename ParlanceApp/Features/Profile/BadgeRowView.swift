import SwiftUI

/// Horizontal scrolling badge row pinned near the top of the Profile tab.
/// GitHub-style: unlocked badges first (sorted by tier desc, then category),
/// then locked badges so the user sees how to earn more. Tap any badge to
/// open the detail sheet.
struct BadgeRowView: View {
    let achievements: [Achievement]

    /// SwiftData @Model classes can't reliably conform to Identifiable under
    /// Swift 6 actor-isolation rules, so wrap the selection in an inert
    /// struct that owns its own identity.
    private struct SelectedBadge: Identifiable {
        let achievement: Achievement
        var id: String { achievement.id }
    }

    @State private var selectedBadge: SelectedBadge?

    private var ordered: [Achievement] {
        let unlocked = achievements
            .filter(\.isUnlocked)
            .sorted { lhs, rhs in
                if lhs.tier != rhs.tier { return lhs.tier > rhs.tier }
                return categoryRank(lhs.category) < categoryRank(rhs.category)
            }
        let locked = achievements
            .filter { !$0.isUnlocked }
            .sorted { lhs, rhs in
                if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
                return categoryRank(lhs.category) < categoryRank(rhs.category)
            }
        return unlocked + locked
    }

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    private func categoryRank(_ category: String) -> Int {
        Achievement.categoryOrder[category] ?? 99
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ordered, id: \.id) { achievement in
                        Button {
                            selectedBadge = SelectedBadge(achievement: achievement)
                        } label: {
                            BadgeView(achievement: achievement, size: 56)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profile.badge.\(achievement.id)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -16)
        }
        .sheet(item: $selectedBadge) { selection in
            BadgeDetailSheet(achievement: selection.achievement)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Badges")
                .font(AppFonts.display(18))
                .foregroundStyle(AppColors.text)
            Spacer()
            Text("\(unlockedCount) / \(achievements.count)")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
        }
    }
}

