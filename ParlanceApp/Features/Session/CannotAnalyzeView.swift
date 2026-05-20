// ParlanceApp/Features/Session/CannotAnalyzeView.swift
import SwiftUI

enum CannotAnalyzeReason: String, Equatable {
    case tooShort
    case inappropriateContent
    case modelRefused
    case offTopic

    var headline: String {
        switch self {
        case .tooShort:              return "We didn't catch that"
        case .inappropriateContent:  return "This recording can't be coached"
        case .modelRefused:          return "We couldn't analyze this recording"
        case .offTopic:              return "Off-topic recording"
        }
    }

    var body: String {
        switch self {
        case .tooShort:
            return "Your recording was too short to analyze. Try again — speak for at least a few seconds."
        case .inappropriateContent:
            return "We can't analyze recordings with profanity or slurs. Try again with content suited for coaching."
        case .modelRefused:
            return "Something about this recording prevented analysis. Please try again."
        case .offTopic:
            return "Your response didn't address the prompt. Try again — the coach can't help if you're not answering the question."
        }
    }

    var systemImageName: String {
        switch self {
        case .tooShort:              return "mic.slash"
        case .inappropriateContent:  return "exclamationmark.shield"
        case .modelRefused:          return "exclamationmark.triangle"
        case .offTopic:              return "questionmark.bubble"
        }
    }
}

struct CannotAnalyzeView: View {
    let reason: CannotAnalyzeReason
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: reason.systemImageName)
                .font(.system(size: 40))
                .foregroundStyle(AppColors.gold)
            Text(reason.headline)
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)
            Text(reason.body)
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.sub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 12) {
                Button("Discard", action: onDiscard)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.sub)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Try Again", action: onRetry)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.bg)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(32)
    }
}
