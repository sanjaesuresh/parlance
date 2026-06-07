import SwiftUI
import AVFoundation
import UIKit

// Three-step teach flow shown once before FirstLaunchSetupView. Teaches modes,
// the session shape (and primes mic permission), and a starting difficulty.
struct OnboardingTeachView: View {
    @EnvironmentObject private var permissions: PermissionsService

    let onComplete: (_ practiceLevel: Int) -> Void

    enum TeachStep: Int, CaseIterable {
        case modes, session, difficulty
    }

    @State private var step: TeachStep = .modes
    @State private var practiceLevel: Int = 5

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                ZStack {
                    switch step {
                    case .modes:
                        OnboardingTeachModesStep(onContinue: { advance(to: .session) })
                            .transition(stepTransition)
                    case .session:
                        OnboardingTeachSessionStep(onContinue: { advance(to: .difficulty) })
                            .transition(stepTransition)
                    case .difficulty:
                        OnboardingTeachDifficultyStep(
                            selectedLevel: $practiceLevel,
                            onContinue: { onComplete(practiceLevel) }
                        )
                        .transition(stepTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance(to next: TeachStep) {
        withAnimation(.easeOut(duration: 0.28)) {
            step = next
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(TeachStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? AppColors.gold : AppColors.border)
                    .frame(height: 3)
                    .animation(.easeOut(duration: 0.25), value: step)
            }
        }
    }
}

// MARK: - Step 1: Four modes

private struct OnboardingTeachModesStep: View {
    let onContinue: () -> Void

    @State private var expandedID: String? = nil

    private struct ModePreview: Identifiable {
        let id: String
        let title: String
        let blurb: String
        let example: String
    }

    private let modes: [ModePreview] = [
        .init(id: "interview", title: "Job Interview",
              blurb: "Behavioral questions, STAR structure.",
              example: "Tell me about a time you led under pressure."),
        .init(id: "daily", title: "Daily Convo",
              blurb: "Impromptu clarity. Hold attention.",
              example: "Pitch a friend on a weekend trip in 60 seconds."),
        .init(id: "impromptu", title: "Impromptu",
              blurb: "Think on your feet.",
              example: "Defend the unpopular opinion of your choice."),
        .init(id: "explain", title: "Explain a Topic",
              blurb: "Break down complex ideas simply.",
              example: "Explain compound interest to a 10-year-old.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 12)

                    OnboardingTeachHeader(title: "Four ways to practice.",
                                          meta: "Step 1 of 3")
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(modes) { mode in
                            modeCard(mode)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                }
                .padding(.bottom, 24)
            }

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    private func modeCard(_ mode: ModePreview) -> some View {
        let isExpanded = expandedID == mode.id
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                expandedID = isExpanded ? nil : mode.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode.title)
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.text)
                Text(mode.blurb)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.sub)
                if isExpanded {
                    Text(mode.example)
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.text.opacity(0.85))
                        .italic()
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(isExpanded ? AppColors.selected : AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke(isExpanded ? AppColors.gold : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: How a session feels

private struct OnboardingTeachSessionStep: View {
    @EnvironmentObject private var permissions: PermissionsService
    let onContinue: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var didAnimate = false
    @State private var didRequestMic = false

    private let tips: [String] = [
        "Open with one clear sentence.",
        "Anchor the middle with a concrete example.",
        "Close with the takeaway, not a hedge."
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 12)

                    OnboardingTeachHeader(title: "A session is 60 to 120 seconds.",
                                          meta: "Step 2 of 3")
                        .padding(.horizontal, 24)

                    // Static mock of the recording UI
                    VStack(spacing: 18) {
                        Text("Tell me about a time you led under pressure.")
                            .font(AppFonts.display(20))
                            .foregroundStyle(AppColors.text)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )

                        ZStack {
                            Circle()
                                .stroke(AppColors.border, lineWidth: 6)
                                .frame(width: 132, height: 132)
                            Circle()
                                .trim(from: 0, to: ringProgress)
                                .stroke(AppColors.gold,
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 132, height: 132)
                            VStack(spacing: 2) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(AppColors.gold)
                                Text("Tap mic when ready")
                                    .font(AppFonts.bodyMedium(11))
                                    .foregroundStyle(AppColors.sub)
                            }
                        }

                        // Coaching tips
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Rectangle().fill(AppColors.border).frame(height: 1)
                                Text("Focus areas")
                                    .font(AppFonts.bodyBold(9))
                                    .foregroundStyle(AppColors.dim)
                                    .kerning(0.4)
                                    .fixedSize()
                                Rectangle().fill(AppColors.border).frame(height: 1)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.custom("Fraunces72pt-Bold", size: 18))
                                            .foregroundStyle(AppColors.gold)
                                            .frame(width: 16, alignment: .leading)
                                        Text(tip)
                                            .font(AppFonts.body(13))
                                            .foregroundStyle(AppColors.text.opacity(0.88))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                        }

                        Text("We transcribe locally. Audio is deleted after the session.")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.dim)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)

                    micPermissionBlock
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .onAppear {
            guard !didAnimate else { return }
            didAnimate = true
            withAnimation(.easeOut(duration: 1.2)) {
                ringProgress = 0.7
            }
        }
        .task {
            guard !didRequestMic,
                  permissions.microphoneStatus == .undetermined else { return }
            didRequestMic = true
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard permissions.microphoneStatus == .undetermined else { return }
            _ = await permissions.requestMicrophone()
        }
    }

    @ViewBuilder
    private var micPermissionBlock: some View {
        switch permissions.microphoneStatus {
        case .granted:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                Text("Microphone ready")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .denied:
            SecondaryButton(title: "You can change this in Settings") {
                permissions.openSettings()
            }
        case .undetermined:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

// MARK: - Step 3: Pick difficulty

private struct OnboardingTeachDifficultyStep: View {
    @Binding var selectedLevel: Int
    let onContinue: () -> Void

    private struct Band: Identifiable {
        let id: Int
        let level: Int
        let title: String
        let blurb: String
        let proLocked: Bool
    }

    private let bands: [Band] = [
        .init(id: 1, level: 1, title: "Band 1 to 2", blurb: "Starter. Short, low pressure.", proLocked: false),
        .init(id: 3, level: 3, title: "Band 3 to 4", blurb: "Developing. Real prompts, gentle stakes.", proLocked: false),
        .init(id: 5, level: 5, title: "Band 5 to 6", blurb: "Confident. Default for most.", proLocked: false),
        .init(id: 7, level: 7, title: "Band 7 to 8", blurb: "Advanced. Pro.", proLocked: true),
        .init(id: 9, level: 9, title: "Band 9 to 10", blurb: "Expert. Pro.", proLocked: true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    Spacer().frame(height: 12)

                    OnboardingTeachHeader(title: "Where do you want to start?",
                                          meta: "Step 3 of 3")
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(bands) { band in
                            bandCard(band)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                    Text("You can change this any time from Home.")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 24)
            }

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    private func bandCard(_ band: Band) -> some View {
        let isSelected = selectedLevel == band.level
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedLevel = band.level
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(band.title)
                            .font(AppFonts.bodyBold(15))
                            .foregroundStyle(AppColors.text)
                        if band.proLocked {
                            Text("PRO")
                                .font(AppFonts.bodyBold(9))
                                .kerning(1.0)
                                .foregroundStyle(AppColors.onGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AppColors.gold)
                                .clipShape(Capsule())
                        }
                    }
                    Text(band.blurb)
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.gold)
                        .font(.system(size: 20))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColors.selected : AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke(isSelected ? AppColors.gold : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared editorial header

private struct OnboardingTeachHeader: View {
    let title: String
    let meta: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
                .padding(.bottom, 12)
            Text(meta)
                .font(AppFonts.bodyBold(10))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)
                .padding(.bottom, 10)
            Text(title)
                .font(AppFonts.display(28))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
