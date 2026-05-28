import SwiftUI

// TODO: weekly rank delta requires user_stats.last_week_friend_rank column (deferred).

/// Pinned chip at the top of the Friends sub-tab showing the current user's
/// position among their friends for the current week.
///
/// Two render states:
/// - **Ranked** (`rank != nil`): shows "#N of M", the user's weekly XP, and avatar.
/// - **Empty** (`rank == nil`): prompts the user to add friends with a CTA that
///   focuses the search field.
struct FriendsRankChip: View {
    /// 1-indexed rank of the current user among friends + self.
    /// `nil` means the user has no friends yet (show empty state).
    let rank: Int?
    /// Total count of friends + self (denominator for the rank headline).
    let total: Int
    let weeklyXP: Int
    let avatarEmoji: String
    let avatarUrl: String?
    let avatarUpdatedAt: Date?
    let displayName: String
    /// Called when the user taps the "Add friends" CTA in the empty state.
    let onAddFriendsTapped: () -> Void
    /// Called when the user taps the chip in its ranked state to view the full
    /// ranked friends list. No-op default keeps existing call sites compiling.
    var onRankTapped: () -> Void = {}

    var body: some View {
        if let rank {
            Button(action: onRankTapped) {
                rankedView(rank: rank)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("friendsRankChip")
            .accessibilityHint("Shows the full ranked list of you and your friends.")
        } else {
            emptyView
        }
    }

    // MARK: - Ranked state

    private func rankedView(rank: Int) -> some View {
        HStack(spacing: 14) {
            AvatarView(
                avatarUrl: avatarUrl,
                avatarEmoji: avatarEmoji,
                avatarUpdatedAt: avatarUpdatedAt,
                size: 46,
                emojiFontSize: 22
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("#\(rank) of \(total)")
                    .font(AppFonts.display(22))
                    .foregroundStyle(AppColors.gold)
                HStack(spacing: 5) {
                    Text("YOU")
                        .font(AppFonts.bodyBold(8))
                        .foregroundStyle(AppColors.onGold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.gold)
                        .clipShape(Capsule())
                    Text("among friends this week")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.sub)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(weeklyXP)")
                    .font(AppFonts.display(20))
                    .foregroundStyle(AppColors.text)
                Text("XP")
                    .font(AppFonts.bodyMedium(11))
                    .foregroundStyle(AppColors.dim)
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.5), lineWidth: 1.5)
        )
    }

    // MARK: - Empty state

    private var emptyView: some View {
        HStack(spacing: 14) {
            Image(systemName: "trophy")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColors.gold.opacity(0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text("Add friends to compete.")
                    .font(AppFonts.bodyBold(15))
                    .foregroundStyle(AppColors.text)
                Text("See how you rank week to week.")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }

            Spacer()

            Button(action: onAddFriendsTapped) {
                HStack(spacing: 4) {
                    Text("Find")
                        .font(AppFonts.bodyMedium(13))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppColors.gold.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.gold.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
