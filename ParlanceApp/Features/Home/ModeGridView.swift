import SwiftUI

struct ModeGridView: View {
    let level: Int
    let isPro: Bool
    let onSelect: (SessionMode) -> Void
    let onSelectLocked: (SessionMode) -> Void
    var displayModes: [SessionMode] = SessionMode.defaultModes

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var orderedModes: [SessionMode] {
        let free = displayModes
        let pro = SessionMode.allCases.filter { !free.contains($0) }
        return free + pro
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(orderedModes, id: \.self) { mode in
                let locked = mode.isProMode && !isPro
                Button {
                    if locked { onSelectLocked(mode) } else { onSelect(mode) }
                } label: {
                    modeCard(mode: mode, locked: locked)
                }
                .accessibilityLabel("\(mode.displayName) practice mode\(locked ? " — Pro required" : "")")
                .accessibilityHint(locked ? "Double-tap to view upgrade options" : "Double-tap to start a session")
                .accessibilityIdentifier("home.modeGrid.\(mode.rawValue)")
            }
        }
    }

    // MARK: - Mode Card

    private func modeCard(mode: SessionMode, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode.emoji)
                .font(.system(size: 22))
            Text(mode.displayName)
                .font(AppFonts.bodyMedium(14))
                .foregroundStyle(AppColors.text)
                .padding(.top, 8)
            Text(mode.description)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if locked {
                Text("PRO")
                    .font(AppFonts.bodyBold(9))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.gold.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
        .opacity(locked ? 0.7 : 1.0)
    }
}
