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
                }
            }

            Button {
                showAllModes = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .medium))
                    Text("More Practice Modes")
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
        .sheet(isPresented: $showAllModes) {
            allModesSheet
        }
    }

    // MARK: - All Modes Sheet

    private var allModesSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(SessionMode.allCases, id: \.self) { mode in
                        let locked = mode.isProMode && !isPro
                        Button {
                            showAllModes = false
                            if locked { onSelectLocked(mode) } else { onSelect(mode) }
                        } label: {
                            modeCard(mode: mode, locked: locked)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("All Practice Modes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAllModes = false }
                        .foregroundStyle(AppColors.gold)
                }
            }
            .toolbarBackground(AppColors.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
    }

    // MARK: - Mode Card

    private func modeCard(mode: SessionMode, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode.emoji)
                .font(.system(size: 22))

            Text(mode.displayName)
                .font(AppFonts.bodyMedium(13))
                .foregroundStyle(locked ? AppColors.sub : AppColors.text)

            Text(mode.description)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(alignment: .topTrailing) {
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
                .padding(10)
            } else {
                Text(DifficultyLevel.tier(for: level))
                    .font(AppFonts.body(9))
                    .foregroundStyle(mode.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(mode.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(10)
            }
        }
        .background(locked ? AppColors.faint : AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(locked ? AppColors.border : mode.accentColor.opacity(0.28), lineWidth: 1)
        )
        .opacity(locked ? 0.7 : 1.0)
    }
}
