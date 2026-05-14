// Parlance/Features/Progress/AllTimeStatsCard.swift
// All-time stats card for the Progress tab rework. Plan 2026-05-13 §4.8.
import SwiftUI

struct AllTimeStatsCard: View {
    let stats: ProgressViewModel.AllTimeStats

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .leading),
        count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                cell(value: empty ? "—" : "\(stats.sessionCount)", label: "Sessions", gold: true)
                cell(value: empty ? "—" : "\(stats.avgScore)", label: "Avg score", gold: false)
                cell(value: empty ? "—" : "\(stats.bestScore)", label: "Best score", gold: false)
                cell(value: empty ? "—" : Self.formatSpokenDuration(stats.totalDuration), label: "Spoken", gold: false)
                cell(value: empty ? "—" : formattedXP, label: "Total XP", gold: true)
                cell(value: empty ? "—" : "\(stats.longestStreak)", label: "Longest streak", gold: false)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColors.card2, AppColors.card],
                startPoint: UnitPoint(x: 0.17, y: 0),
                endPoint: UnitPoint(x: 0.83, y: 1)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Header

    private var header: some View {
        Text("All-time")
            .font(AppFonts.display(18))
            .foregroundStyle(AppColors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cell

    private func cell(value: String, label: String, gold: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppFonts.display(24))
                .foregroundStyle(gold ? AppColors.gold : AppColors.text)
            Text(label)
                .font(AppFonts.body(9))
                .kerning(0.9)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatting

    private var formattedXP: String {
        stats.totalXP.formatted(.number.grouping(.automatic))
    }

    private var empty: Bool { stats.sessionCount == 0 }

    static func formatSpokenDuration(_ totalSeconds: TimeInterval) -> String {
        let s = totalSeconds
        if s < 60 {
            return "\(Int(s))s"
        } else if s < 3600 {
            return "\(Int(s / 60))m"
        } else if s > 23.9 * 3600 {
            return "\(Int(s / 86400))d"
        } else {
            let hours = Int(s / 3600)
            let minutes = Int((s - Double(hours) * 3600) / 60)
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}
