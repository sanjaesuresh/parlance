import SwiftUI

struct GlobalLeaderboardSection: View {
    let snapshot: GlobalLeaderboardSnapshot
    var onTapEntry: ((GlobalLeaderboardEntry) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Global · This Week")

            ForEach(snapshot.top) { entry in
                let isMe = entry.id == snapshot.me?.id
                if isMe {
                    row(for: entry, isMe: true)
                } else {
                    Button {
                        onTapEntry?(entry)
                    } label: {
                        row(for: entry, isMe: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let me = snapshot.me, me.rank > snapshot.top.count {
                pinnedDivider
                row(for: me, isMe: true)
            }
        }
    }

    private var pinnedDivider: some View {
        VStack(spacing: 6) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.border)
            Text("Your rank")
                .font(AppFonts.bodyBold(11))
                .foregroundStyle(AppColors.sub)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }

    private func row(for entry: GlobalLeaderboardEntry, isMe: Bool) -> some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(AppFonts.bodyBold(14))
                .foregroundStyle(entry.rank <= 3 ? AppColors.gold : AppColors.text)
                .frame(width: 32, alignment: .leading)

            AvatarView(
                avatarUrl: entry.avatarUrl,
                avatarEmoji: entry.avatarEmoji,
                avatarUpdatedAt: entry.avatarUpdatedAt,
                size: 36,
                emojiFontSize: 18
            )

            HStack(spacing: 6) {
                Text("@\(entry.username)")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.text)
                if isMe {
                    PillBadge(text: "YOU", color: AppColors.gold, small: true)
                }
            }

            Spacer()

            Text("\(entry.weeklyXP) XP")
                .font(AppFonts.bodyMedium(12))
                .foregroundStyle(AppColors.dim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMe ? AppColors.gold.opacity(0.08) : AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMe ? AppColors.gold.opacity(0.35) : AppColors.border, lineWidth: 1)
        )
    }
}
