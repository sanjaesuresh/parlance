import SwiftUI

struct RealLifeSetupView: View {
    @StateObject private var vm = RealLifeSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    let level: Int
    let onStart: (ActiveSessionState) -> Void

    @State private var sliderValue: Double = 60
    @State private var startHaptic = false
    @State private var snapHaptic = false

    private let accent = Color(hex: "#D44A6F")

    var body: some View {
        VStack(spacing: 0) {
            topNav
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    eyebrow
                    title
                    sub
                    textField
                    counter
                    if vm.denylistTripped { denylistWarning }
                    durationCard
                    if !vm.recentScenarios.isEmpty { recentSection }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 140)
            }
            startButton
        }
        .background(AppColors.bg.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: startHaptic)
        .sensoryFeedback(.selection, trigger: snapHaptic)
    }

    // MARK: - Top nav

    private var topNav: some View {
        ZStack {
            HStack {
                Button(action: { dismiss() }) {
                    Text("← Back")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            modeChip
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var modeChip: some View {
        HStack(spacing: 5) {
            Text("🎯")
            Text("Real Life · L\(level)")
                .font(AppFonts.bodyMedium(11))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(accent.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Header

    private var eyebrow: some View {
        Text("NEW SCENARIO")
            .font(AppFonts.bodyBold(10))
            .kerning(1.6)
            .foregroundStyle(AppColors.dim)
    }

    private var title: some View {
        Text("What are you about to do?")
            .font(AppFonts.display(26))
            .foregroundStyle(AppColors.text)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sub: some View {
        Text("Describe the conversation in your own words. The AI uses this to coach you on what matters.")
            .font(AppFonts.body(13))
            .foregroundStyle(AppColors.sub)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Text field

    private var textField: some View {
        TextField(
            "I'm about to…",
            text: Binding(
                get: { vm.scenarioText },
                set: { vm.onScenarioChange($0) }
            ),
            axis: .vertical
        )
        .lineLimit(4...)
        .font(AppFonts.body(14))
        .foregroundStyle(AppColors.text)
        .padding(14)
        .frame(minHeight: 124, alignment: .topLeading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .accessibilityIdentifier("realLife.scenarioField")
    }

    private var counter: some View {
        HStack {
            Spacer()
            Text("\(vm.characterCount) / \(RealLifeSetupViewModel.maxLength)")
                .font(AppFonts.body(11))
                .foregroundStyle(vm.characterCountColor)
        }
    }

    private var denylistWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.red)
                .font(.system(size: 14))
            Text("This scenario contains language we can't coach on. Please rewrite it before continuing.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(AppColors.red.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.red.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Duration

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Session length")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(vm.durationDisplay)
                    .font(AppFonts.display(22))
                    .foregroundStyle(AppColors.gold)
            }
            Slider(
                value: $sliderValue,
                in: 0...Double(RealLifeSetupViewModel.maxDuration),
                step: Double(RealLifeSetupViewModel.durationStep)
            )
            .tint(AppColors.gold)
            .onChange(of: sliderValue) { _, newValue in
                let before = vm.durationSeconds
                vm.setDurationFromSlider(newValue)
                if before != vm.durationSeconds { snapHaptic.toggle() }
            }
            HStack {
                Text("0:00")
                Spacer()
                Text("3:00")
            }
            .font(AppFonts.body(10))
            .foregroundStyle(AppColors.dim)
        }
        .padding(14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        .padding(.top, 4)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(AppColors.border).frame(height: 1)
                Text("RECENT")
                    .font(AppFonts.bodyBold(9))
                    .kerning(1.6)
                    .foregroundStyle(AppColors.dim)
                    .fixedSize()
                Rectangle().fill(AppColors.border).frame(height: 1)
            }
            .padding(.top, 10)

            ForEach(vm.recentScenarios) { entry in
                Button { vm.loadFromRecent(entry) } label: {
                    HStack {
                        Text(entry.text)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.text.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
                .accessibilityIdentifier("realLife.recentChip")
            }
        }
    }

    // MARK: - Start CTA

    private var startButton: some View {
        Button {
            guard vm.canStart else { return }
            startHaptic.toggle()
            onStart(buildState())
        } label: {
            HStack(spacing: 10) {
                Text("Continue")
                    .font(AppFonts.bodyBold(16))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppColors.onGold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!vm.canStart)
        .opacity(vm.canStart ? 1.0 : 0.4)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .accessibilityIdentifier("realLife.startButton")
    }

    private func buildState() -> ActiveSessionState {
        let band = DifficultyLevel.band(for: level)
        let question = Question(
            id: UUID().uuidString,
            mode: .realLife,
            difficultyBand: band,
            question: vm.trimmedScenario,
            tips: [],
            targetDuration: vm.durationSeconds,
            difficultyNote: "User-supplied scenario · AI-coached severity",
            category: nil
        )
        return ActiveSessionState(
            mode: .realLife,
            difficultyLevel: level,
            question: question,
            wasDailyChallenge: false
        )
    }
}
