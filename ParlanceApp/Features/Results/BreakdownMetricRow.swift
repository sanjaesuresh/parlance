import SwiftUI

struct BreakdownMetricRow: View {
    enum Status { case strong, watch, focus }

    let name: String
    let score: Int
    let tip: String
    let status: Status

    static func status(forScore score: Int) -> Status {
        if score >= 8 { return .strong }
        if score >= 5 { return .watch }
        return .focus
    }

    private var statusColor: Color {
        switch status {
        case .strong: return AppColors.teal
        case .watch: return AppColors.gold
        case .focus: return AppColors.red
        }
    }

    private var statusLabel: String {
        switch status {
        case .strong: return "STRONG"
        case .watch: return "WATCH"
        case .focus: return "FOCUS"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(score * 10)")
                    .font(AppFonts.display(26))
                    .foregroundStyle(statusColor)
                    .minimumScaleFactor(1)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(name)
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Text(statusLabel)
                            .font(AppFonts.bodyBold(10))
                            .kerning(1)
                            .foregroundStyle(statusColor)
                    }

                    if status != .strong {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(AppColors.faint)
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(statusColor)
                                    .frame(width: geo.size.width * max(0, Double(score) / 10.0))
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 10)

                        if !tip.isEmpty {
                            Text(tip)
                                .font(AppFonts.body(12.5).italic())
                                .foregroundStyle(AppColors.sub)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                    }
                }
            }
            .padding(.vertical, 11)

            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
}
