import SwiftUI

struct ActivityFeedRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.actorAvatarEmoji)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(AppColors.faint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                attributedText
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
                Text(timeAgo)
                    .font(AppFonts.body(10))
                    .foregroundStyle(AppColors.dim)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var attributedText: Text {
        let name = Text(event.actorDisplayName)
            .foregroundStyle(AppColors.text)
            .font(AppFonts.bodyMedium(13))

        switch event.kind {
        case .score(let value, let mode):
            return name + Text(" scored ")
                + Text("\(value)").foregroundStyle(AppColors.gold).font(AppFonts.bodyMedium(13))
                + Text(" in \(mode.displayName)")
        case .personalBest(let mode, _):
            return name + Text(" set a new ")
                + Text("personal best").foregroundStyle(AppColors.gold).font(AppFonts.bodyMedium(13))
                + Text(" in \(mode.displayName)")
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: event.occurredAt, relativeTo: .now)
    }
}
