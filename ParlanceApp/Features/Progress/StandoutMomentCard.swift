// Parlance/Features/Progress/StandoutMomentCard.swift
// Standout moment card for the Progress tab rework. Plan 2026-05-13 §4.4.
import SwiftUI

struct StandoutMomentCard: View {
    let session: Session
    let isExpanded: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Mirror HomeXPHero: deep cinnamon→cocoa in light, near-black warm wash in dark.
    private var gradientStart: Color {
        colorScheme == .dark ? Color(hex: "#181200") : Color(hex: "#C7813A")
    }
    private var gradientEnd: Color {
        colorScheme == .dark ? Color(hex: "#1F1700") : Color(hex: "#7A3F12")
    }

    private var onCardText: Color { Color(hex: "#FBF3E2") }
    private var onCardSub: Color { Color(hex: "#E8D3A6") }
    private var onCardAccent: Color { Color(hex: "#F5C45A") }
    private var onCardDim: Color { Color(hex: "#E8D3A6").opacity(0.7) }
    private var onCardCellBg: Color { Color.black.opacity(0.28) }
    private var onCardBorder: Color { Color(hex: "#F5C45A").opacity(0.35) }
    private var onCardDivider: Color { Color(hex: "#F5C45A").opacity(0.25) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                topRow
                footRow
                    .padding(.top, 12)
                if isExpanded {
                    expandedArea
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.12)),
                            removal: .opacity.animation(.easeIn(duration: 0.12))
                        ))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(onCardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("BEST SESSION · \(formattedDate)")
                    .font(AppFonts.bodyBold(10))
                    .kerning(1.4)
                    .foregroundStyle(onCardAccent)
                Text("\u{201C}\(session.question)\u{201D}")
                    .font(AppFonts.display(16))
                    .foregroundStyle(onCardText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(session.overallScore)")
                .font(AppFonts.display(28))
                .foregroundStyle(onCardAccent)
                .lineLimit(1)
        }
    }

    // MARK: - Foot row

    private var footRow: some View {
        HStack(spacing: 0) {
            Text("\(session.mode.displayName) · \(formattedDuration) · \(session.fillerCount) \(session.fillerCount == 1 ? "filler" : "fillers")")
                .font(AppFonts.body(11))
                .foregroundStyle(onCardSub)

            Spacer()

            HStack(spacing: 4) {
                Text(isExpanded ? "Hide breakdown" : "View breakdown")
                    .font(AppFonts.bodyMedium(11))
                    .foregroundStyle(onCardAccent)
                Text("\u{203A}")
                    .font(AppFonts.bodyMedium(11))
                    .foregroundStyle(onCardAccent)
            }
        }
    }

    // MARK: - Expanded area

    private var expandedArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(onCardDivider)
                .frame(height: 1)
                .padding(.top, 14)

            HStack(spacing: 6) {
                ForEach(metricCells, id: \.label) { cell in
                    metricCellView(cell)
                }
            }
            .padding(.top, 14)

            if let feedback = session.aiCoachFeedback, !feedback.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("AI COACH")
                        .font(AppFonts.bodyBold(9))
                        .kerning(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(onCardAccent)
                    Text(feedback)
                        .font(AppFonts.body(12))
                        .foregroundStyle(onCardSub)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .padding(.top, 14)
            }
        }
    }

    private func metricCellView(_ cell: MetricCell) -> some View {
        VStack(spacing: 0) {
            Text(cell.value)
                .font(AppFonts.display(13))
                .foregroundStyle(cell.color)
            Text(cell.label)
                .font(AppFonts.body(8))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(onCardDim)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(onCardCellBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private struct MetricCell {
        let label: String
        let value: String
        let color: Color
    }

    private var metricCells: [MetricCell] {
        let aiScored = session.isAIScored
        let scores = session.metricScores

        func score(_ key: MetricKey, legacy: Int) -> Int {
            if aiScored, let s = scores[key.rawValue] { return s }
            return legacy
        }

        let fillerCount = session.fillerCount
        let pace = score(.pace, legacy: session.paceScore)
        let clarity = score(.clarity, legacy: session.clarityScore)
        let structure = score(.structure, legacy: session.structureScore)
        let vocab = score(.vocabulary, legacy: session.vocabularyScore)

        return [
            MetricCell(label: "Filler", value: "\(fillerCount)", color: fillerColor(fillerCount)),
            MetricCell(label: "Pace", value: "\(pace)/10", color: scoreColor(pace)),
            MetricCell(label: "Clarity", value: "\(clarity)/10", color: scoreColor(clarity)),
            MetricCell(label: "Structure", value: "\(structure)/10", color: scoreColor(structure)),
            MetricCell(label: "Vocab", value: "\(vocab)/10", color: scoreColor(vocab)),
        ]
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 7 { return AppColors.teal }
        if score >= 5 { return AppColors.gold }
        return AppColors.red
    }

    private func fillerColor(_ count: Int) -> Color {
        if count <= 2 { return AppColors.teal }
        if count <= 4 { return AppColors.gold }
        return AppColors.red
    }

    private var formattedDate: String {
        session.date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var formattedDuration: String {
        let d = session.duration
        let mins = Int(d) / 60
        let secs = Int(d) % 60
        return "\(mins)m \(secs)s"
    }
}
