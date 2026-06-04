import SwiftUI

/// Sheet listing the current user and all their friends ranked by weekly XP.
/// Each row shows a 24h rank-delta arrow when local history is available.
struct FriendsRankSheet: View {
    struct Entry: Identifiable {
        let id: String
        let rank: Int
        let displayName: String
        let username: String
        let avatarEmoji: String
        let avatarUrl: String?
        let avatarUpdatedAt: Date?
        let weeklyXP: Int
        let isMe: Bool
        let delta: Int?
    }

    let entries: [Entry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        row(entry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(AppColors.bg)
            .navigationTitle("Friends Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.gold)
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("friendsRankSheet")
    }

    private func row(_ e: Entry) -> some View {
        HStack(spacing: 12) {
            Text("#\(e.rank)")
                .font(AppFonts.display(16))
                .foregroundStyle(e.rank <= 3 ? AppColors.gold : AppColors.sub)
                .frame(width: 38, alignment: .leading)

            AvatarView(
                avatarUrl: e.avatarUrl,
                avatarEmoji: e.avatarEmoji,
                avatarUpdatedAt: e.avatarUpdatedAt,
                size: 40,
                emojiFontSize: 19
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(e.displayName)
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                    if e.isMe {
                        PillBadge(text: "YOU", color: AppColors.gold, small: true)
                    }
                }
                Text("@\(e.username)")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            deltaBadge(for: e.delta)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(e.weeklyXP)")
                    .font(AppFonts.display(16))
                    .foregroundStyle(AppColors.text)
                Text("XP")
                    .font(AppFonts.bodyMedium(10))
                    .foregroundStyle(AppColors.dim)
            }
            .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(e.isMe ? AppColors.gold.opacity(0.08) : AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(e.isMe ? AppColors.gold.opacity(0.35) : AppColors.border,
                        lineWidth: 1)
        )
        .accessibilityIdentifier("friendsRankRow_\(e.username)")
    }

    @ViewBuilder
    private func deltaBadge(for delta: Int?) -> some View {
        switch delta {
        case .some(let d) where d > 0:
            badge(symbol: "arrow.up", value: d, color: AppColors.gold)
        case .some(let d) where d < 0:
            badge(symbol: "arrow.down", value: -d, color: AppColors.red)
        case .some:
            Image(systemName: "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppColors.dim)
                .frame(width: 28)
        case .none:
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private func badge(symbol: String, value: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text("\(value)")
                .font(AppFonts.bodyBold(11))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
