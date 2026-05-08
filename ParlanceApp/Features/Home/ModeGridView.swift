import SwiftUI

struct ModeGridView: View {
    let level: Int
    let isPro: Bool
    let onSelect: (SessionMode) -> Void
    let onSelectLocked: (SessionMode) -> Void
    var displayModes: [SessionMode] = SessionMode.defaultModes

    @State private var showAllModes = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(displayModes, id: \.self) { mode in
                    let locked = mode.isProMode && !isPro
                    Button {
                        if locked { onSelectLocked(mode) } else { onSelect(mode) }
                    } label: {
                        modeCard(mode: mode, locked: locked)
                    }
                    .accessibilityLabel("\(mode.displayName) practice mode\(locked ? " — Pro required" : "")")
                    .accessibilityHint(locked ? "Double-tap to view upgrade options" : "Double-tap to start a session")
                }

                if showAllModes {
                    ForEach(SessionMode.allCases.filter { !displayModes.contains($0) }, id: \.self) { mode in
                        let locked = mode.isProMode && !isPro
                        Button {
                            if locked { onSelectLocked(mode) } else { onSelect(mode) }
                        } label: {
                            modeCard(mode: mode, locked: locked)
                        }
                        .accessibilityLabel("\(mode.displayName) practice mode\(locked ? " — Pro required" : "")")
                        .accessibilityHint(locked ? "Double-tap to view upgrade options" : "Double-tap to start a session")
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
            .animation(.easeOut(duration: 0.25), value: showAllModes)

            if SessionMode.allCases.count > displayModes.count {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showAllModes.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showAllModes ? "chevron.up" : "square.grid.2x2")
                            .font(.system(size: 13, weight: .medium))
                        Text(showAllModes ? "Show Less" : "More Practice Modes")
                            .font(AppFonts.bodyMedium(13))
                    }
                    .foregroundStyle(AppColors.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Mode Card

    private func modeCard(mode: SessionMode, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(mode.emoji)
                    .font(.system(size: 20))
                Spacer()
                if locked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .semibold))
                        Text("PRO")
                            .font(AppFonts.bodyBold(9))
                    }
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.gold.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(mode.accentColor.opacity(locked ? 0.05 : 0.18))
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.displayName)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(locked ? AppColors.sub : AppColors.text)

                Text(mode.description)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(
                    locked ? AppColors.border : mode.accentColor.opacity(0.45),
                    lineWidth: 1
                )
        )
        .opacity(locked ? 0.6 : 1.0)
    }
}
