import SwiftUI

struct RecentSessionRow: View {
    let session: Session
    let isLast: Bool

    var body: some View {
        NavigationLink {
            SessionDetailView(session: session)
        } label: {
            HStack(spacing: 14) {
                whenColumn
                bodyColumn
                Spacer(minLength: 8)
                scoreColumn
                chevronColumn
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.mode.displayName) session, score \(session.overallScore). Tap for full breakdown.")
    }

    // MARK: - Columns

    private var whenColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(dayString)
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
            Text(monthString)
                .font(AppFonts.body(9))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)
        }
        .frame(width: 42, alignment: .trailing)
    }

    private var bodyColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.mode.displayName)
                .font(AppFonts.body(10))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)
            Text(session.question)
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.text)
                .lineSpacing(2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 0)
            metaRow
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(durationString)
                .foregroundStyle(AppColors.sub)
            Text("\u{00B7}")
                .foregroundStyle(AppColors.dim)
            Text("\(session.fillerCount) filler\(session.fillerCount == 1 ? "" : "s")")
                .foregroundStyle(AppColors.sub)
            if let wpm = wpmString {
                Text("\u{00B7}")
                    .foregroundStyle(AppColors.dim)
                Text(wpm)
                    .foregroundStyle(wpmIsWarn ? AppColors.red : AppColors.sub)
            }
        }
        .font(AppFonts.body(10))
    }

    private var scoreColumn: some View {
        Text("\(session.overallScore)")
            .font(AppFonts.display(24))
            .foregroundStyle(AppColors.scoreColor(session.overallScore))
            .lineLimit(1)
            .padding(.top, 2)
    }

    private var chevronColumn: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColors.dim)
            .padding(.leading, -4)
            .padding(.top, 4)
    }

    // MARK: - Formatters

    private var dayString: String {
        session.date.formatted(.dateTime.day())
    }

    private var monthString: String {
        session.date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var durationString: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }

    private var wpmString: String? {
        guard session.duration > 0, !session.transcript.isEmpty else { return nil }
        let words = session.transcript.split(whereSeparator: \.isWhitespace).count
        let wpm = Int((Double(words) / session.duration) * 60)
        return "\(wpm) wpm"
    }

    private var wpmIsWarn: Bool {
        guard let wpmString else { return false }
        let n = wpmString.split(separator: " ").first.flatMap { Int($0) } ?? 0
        return n > 175
    }
}
