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
        let candidates = SessionMode.allCases.filter { $0 != .storytelling }
        let featured = displayModes.filter { candidates.contains($0) }
        let remaining = candidates.filter { !featured.contains($0) }
        let combined = featured + remaining
        return combined.filter { !$0.isProMode } + combined.filter { $0.isProMode }
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
                .accessibilityLabel("\(mode.displayName) practice mode\(locked ? ", Pro required" : "")")
                .accessibilityHint(locked ? "Double-tap to view upgrade options" : "Double-tap to start a session")
                .accessibilityIdentifier("home.modeGrid.\(mode.rawValue)")
            }
        }
    }

    // MARK: - Mode Card

    private func modeCard(mode: SessionMode, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: mode.systemImageName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(mode.accentColor)
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
            } else if let badge = badgeLabel(for: mode) {
                Text(badge)
                    .font(AppFonts.bodyBold(9))
                    .kerning(0.4)
                    .foregroundStyle(mode.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(mode.accentColor, lineWidth: 1))
                    .padding(12)
            }
        }
        .opacity(locked ? 0.7 : 1.0)
    }

    private func badgeLabel(for mode: SessionMode) -> String? {
        switch mode {
        case .realLife: "Custom"
        case .explanation: "Focused"
        default: nil
        }
    }
}
