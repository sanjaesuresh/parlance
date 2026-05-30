// ParlanceApp/Features/Session/CannotAnalyzeView.swift
import SwiftUI

enum CannotAnalyzeReason: String, Equatable {
    case tooShort
    case inappropriateContent
    case modelRefused
    case offTopic
    case transcriptionFailed
    case interrupted

    var headline: String {
        switch self {
        case .tooShort:              return "We didn't catch that"
        case .inappropriateContent:  return "This recording can't be coached"
        case .modelRefused:          return "We couldn't analyze this recording"
        case .offTopic:              return "Off-topic recording"
        case .transcriptionFailed:   return "We couldn't transcribe your recording"
        case .interrupted:           return "Your recording was interrupted"
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
        case .transcriptionFailed:
            return "Speech recognition couldn't process the audio. Check your network and microphone, then try again."
        case .interrupted:
            return "A phone call or system audio cut your session short. Try again when you're ready."
        }
    }

    var systemImageName: String {
        switch self {
        case .tooShort:              return "mic.slash"
        case .inappropriateContent:  return "exclamationmark.shield"
        case .modelRefused:          return "exclamationmark.triangle"
        case .offTopic:              return "questionmark.bubble"
        case .transcriptionFailed:   return "waveform.slash"
        case .interrupted:           return "phone.down"
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
                SecondaryButton(title: "Discard", action: onDiscard)
                PrimaryButton(title: "Try Again", action: onRetry)
            }
        }
        .padding(32)
    }
}
