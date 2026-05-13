import SwiftUI

/// Three-cell summary strip rendered above the standout moment on the Progress tab.
/// Spec: `_docs/plans/2026-05-13-progress-tab-rework.md` §4.3.
///
/// Layout: 3 equal-width cells in a single row, separated by 1pt hairline borders,
/// the whole strip clipped to a 14pt corner radius with a 1pt border overlay.
struct StatsStripView: View {
    let aggregate: ProgressViewModel.PeriodAggregate

    var body: some View {
        HStack(spacing: 0) {
            cell(
                value: formattedAvgScore,
                valueColor: AppColors.gold,
                label: "Avg score",
                deltaText: scoreDeltaText,
                deltaPositive: scoreDeltaPositive,
                showDelta: aggregate.sessionCount > 0 && aggregate.avgScoreDelta != nil
            )
            divider
            cell(
                value: formattedSessionCount,
                valueColor: AppColors.text,
                label: "Sessions",
                deltaText: sessionDeltaText,
                deltaPositive: sessionDeltaPositive,
                showDelta: aggregate.sessionCount > 0 && aggregate.sessionCountDelta != nil
            )
            divider
            cell(
                value: formattedSpoken,
                valueColor: AppColors.text,
                label: "Spoken",
                deltaText: spokenDeltaText,
                deltaPositive: spokenDeltaPositive,
                showDelta: aggregate.sessionCount > 0 && aggregate.totalDurationDelta != nil
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Cell

    private func cell(
        value: String,
        valueColor: Color,
        label: String,
        deltaText: String?,
        deltaPositive: Bool,
        showDelta: Bool
    ) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(AppFonts.display(24))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label.uppercased())
                .font(AppFonts.body(9))
                .kerning(0.9)
                .foregroundStyle(AppColors.dim)
                .padding(.top, 6)

            if showDelta, let deltaText {
                Text(deltaText)
                    .font(AppFonts.body(10))
                    .foregroundStyle(deltaPositive ? AppColors.teal : AppColors.red)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(AppColors.card2)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(width: 1)
    }

    // MARK: - Formatted values

    private var formattedAvgScore: String {
        aggregate.sessionCount == 0 ? "—" : String(aggregate.avgScore)
    }

    private var formattedSessionCount: String {
        aggregate.sessionCount == 0 ? "—" : String(aggregate.sessionCount)
    }

    private var formattedSpoken: String {
        aggregate.sessionCount == 0 ? "—" : Self.formatDuration(aggregate.totalDuration)
    }

    // MARK: - Deltas

    private var scoreDeltaText: String? {
        guard let delta = aggregate.avgScoreDelta else { return nil }
        let arrow = delta >= 0 ? "↑" : "↓"
        let sign = delta >= 0 ? "+" : "−"
        return "\(arrow) \(sign)\(abs(delta))"
    }
    private var scoreDeltaPositive: Bool { (aggregate.avgScoreDelta ?? 0) >= 0 }

    private var sessionDeltaText: String? {
        guard let delta = aggregate.sessionCountDelta else { return nil }
        let arrow = delta >= 0 ? "↑" : "↓"
        let sign = delta >= 0 ? "+" : "−"
        return "\(arrow) \(sign)\(abs(delta))"
    }
    private var sessionDeltaPositive: Bool { (aggregate.sessionCountDelta ?? 0) >= 0 }

    private var spokenDeltaText: String? {
        guard let delta = aggregate.totalDurationDelta else { return nil }
        let arrow = delta >= 0 ? "↑" : "↓"
        let sign = delta >= 0 ? "+" : "−"
        return "\(arrow) \(sign)\(Self.formatDuration(abs(delta)))"
    }
    private var spokenDeltaPositive: Bool { (aggregate.totalDurationDelta ?? 0) >= 0 }

    // MARK: - Duration helper

    /// Formats a TimeInterval into a compact string for the "Spoken" cell.
    /// `<60s` → `"Ns"`, `<60m` → `"Nm"`, `<60h` → `"Nh Nm"`, otherwise `"Nd"`.
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 {
            return "\(total)s"
        } else if total < 3600 {
            return "\(total / 60)m"
        } else if total < 3600 * 60 {
            let h = total / 3600
            let m = (total % 3600) / 60
            return "\(h)h \(m)m"
        } else {
            return "\(total / 86_400)d"
        }
    }
}

#Preview("Has data") {
    StatsStripView(
        aggregate: .init(
            avgScore: 78,
            avgScoreDelta: 5,
            sessionCount: 12,
            sessionCountDelta: -2,
            totalDuration: 8_880,
            totalDurationDelta: 18 * 60
        )
    )
    .padding()
    .background(AppColors.bg)
}

#Preview("Empty") {
    StatsStripView(
        aggregate: .init(
            avgScore: 0,
            avgScoreDelta: nil,
            sessionCount: 0,
            sessionCountDelta: nil,
            totalDuration: 0,
            totalDurationDelta: nil
        )
    )
    .padding()
    .background(AppColors.bg)
}
