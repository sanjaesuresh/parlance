// Parlance/Features/Progress/SkillCardView.swift
//
// One skill card (collapsed/expanded). Parent owns the `isOpen` state and
// passes it down with an `onTap` closure; only one card opens at a time.
// Spec: plan §4.5.3.

import SwiftUI

struct SkillCardView: View {
    let card: ProgressViewModel.SkillCardModel
    let isOpen: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                topRow
                Text(card.note)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .padding(.top, 4)

                if isOpen {
                    expandArea
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.98, anchor: .top)
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isOpen ? AppColors.gold.opacity(0.35) : AppColors.border,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(spacing: 0) {
            Text(card.displayName)
                .font(AppFonts.display(16))
                .foregroundStyle(AppColors.text)

            Spacer()

            HStack(spacing: 10) {
                Text(formattedScore(card.value))
                    .font(AppFonts.display(16))
                    .foregroundStyle(AppColors.text)

                if let delta = card.delta {
                    Text(formattedDelta(delta))
                        .font(AppFonts.bodyMedium(11))
                        .foregroundStyle(delta >= 0 ? AppColors.teal : AppColors.red)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(isOpen ? AppColors.gold : AppColors.dim)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isOpen)
            }
        }
    }

    // MARK: - Expand area

    private var expandArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.gold.opacity(0.2))
                .frame(height: 1)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("COACH'S TIP")
                    .font(AppFonts.bodyBold(9))
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.gold)

                Text(card.coachTip)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var cardBackground: some View {
        if isOpen {
            // Subtle 135° gradient from card to a card+gold tint, approximating
            // the mockup's oklch(0.30 0.030 84) gradient end.
            ZStack {
                AppColors.card
                LinearGradient(
                    colors: [
                        AppColors.gold.opacity(0.0),
                        AppColors.gold.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            AppColors.card
        }
    }

    // MARK: - Formatting

    private func formattedScore(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formattedDelta(_ delta: Double) -> String {
        let abs = String(format: "%.1f", Swift.abs(delta))
        let arrow = delta >= 0 ? "↑" : "↓"
        let sign = delta >= 0 ? "+" : "\u{2212}"
        return "\(arrow) \(sign)\(abs)"
    }
}
