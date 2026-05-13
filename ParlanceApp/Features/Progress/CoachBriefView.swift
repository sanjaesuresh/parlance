// Parlance/Features/Progress/CoachBriefView.swift
// Coach brief block for the Progress tab rework. Plan 2026-05-13 §4.7.
import SwiftUI

struct CoachBriefView: View {
    let brief: ProgressViewModel.CoachBrief

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)

            Text("FROM YOUR COACH")
                .font(AppFonts.bodyMedium(10))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.dim)
                .padding(.top, 22)

            Text(paragraph)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

            if let signature = brief.signature {
                Text(signature)
                    .font(AppFonts.body(11))
                    .kerning(0.4)
                    .foregroundStyle(AppColors.dim)
                    .padding(.top, 16)
            }

            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
                .padding(.top, 26)
        }
    }

    // MARK: - Attributed paragraph

    private var paragraph: AttributedString {
        var attr = AttributedString(brief.body)
        attr.font = AppFonts.body(17)
        attr.foregroundColor = AppColors.text
        attr.kern = -0.17

        for phrase in brief.positiveHighlights {
            applyHighlight(&attr, phrase: phrase, color: AppColors.gold)
        }
        for phrase in brief.negativeHighlights {
            applyHighlight(&attr, phrase: phrase, color: AppColors.redSoft)
        }

        return attr
    }

    private func applyHighlight(_ attr: inout AttributedString, phrase: String, color: Color) {
        guard !phrase.isEmpty else { return }
        var searchRange = attr.startIndex..<attr.endIndex
        while let range = attr[searchRange].range(of: phrase) {
            attr[range].font = AppFonts.body(17).italic()
            attr[range].foregroundColor = color
            searchRange = range.upperBound..<attr.endIndex
        }
    }
}
