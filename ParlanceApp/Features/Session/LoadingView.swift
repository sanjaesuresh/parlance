import SwiftUI

struct LoadingView: View {
    let mode: SessionMode
    let level: Int
    let question: Question
    let onReady: () -> Void
    var onCancel: (() -> Void)?
    var currentTopicCategory: ExplanationCategory? = nil
    var onReshuffleTopic: ((ExplanationCategory) -> Void)? = nil
    var onPromptRewritten: ((String) -> Void)? = nil
    var onEditScenario: ((String) -> Void)? = nil
    var tipsClient: RealLifeTipsFetching = RealLifeTipsClient()

    enum TipsState: Equatable {
        case ready([String])
        case loading
        case refused(reason: String, kind: RealLifeRefusalKind)
        case failed
    }

    @State private var tipsState: TipsState
    @State private var displayedPrompt: String
    @State private var showTopicPicker = false

    init(
        mode: SessionMode,
        level: Int,
        question: Question,
        onReady: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        currentTopicCategory: ExplanationCategory? = nil,
        onReshuffleTopic: ((ExplanationCategory) -> Void)? = nil,
        onPromptRewritten: ((String) -> Void)? = nil,
        onEditScenario: ((String) -> Void)? = nil,
        tipsClient: RealLifeTipsFetching = RealLifeTipsClient()
    ) {
        self.mode = mode
        self.level = level
        self.question = question
        self.onReady = onReady
        self.onCancel = onCancel
        self.currentTopicCategory = currentTopicCategory
        self.onReshuffleTopic = onReshuffleTopic
        self.onPromptRewritten = onPromptRewritten
        self.onEditScenario = onEditScenario
        self.tipsClient = tipsClient
        _tipsState = State(initialValue: mode == .realLife ? .loading : .ready(question.tips))
        _displayedPrompt = State(initialValue: question.question)
    }

    var body: some View {
        VStack(spacing: 0) {
            SessionNavBar(
                leading: {
                    if let onCancel {
                        BackButton(action: onCancel)
                            .accessibilityLabel("Cancel")
                    }
                },
                center: {
                    HStack(spacing: 7) {
                        PillBadge(text: mode.displayName, emoji: mode.emoji, color: mode.accentColor, small: true)
                        Text("Lv \(level)")
                            .font(AppFonts.bodyMedium(10))
                            .foregroundStyle(AppColors.sub)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(AppColors.card)
                            .clipShape(Capsule())
                    }
                },
                trailing: { EmptyView() }
            )
            .padding(.bottom, 4)

            if mode == .explanation {
                let category = currentTopicCategory ?? .any
                Button {
                    showTopicPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Topic: \(category.displayName)")
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.gold)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.gold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppColors.gold.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppColors.gold.opacity(0.5), lineWidth: 1)
                    )
                }
                .accessibilityIdentifier("explain.topicChip")
                .padding(.bottom, 8)
            }

            ScrollView {
                VStack(spacing: 20) {
                    // One-liner instruction
                    Text("Read the prompt, then tap to begin recording.")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Prompt card
                    Group {
                        if mode == .realLife, case .refused(let reason, let kind) = tipsState {
                            recoverableRefusalCard(reason: reason, kind: kind)
                        } else if mode == .realLife, case .failed = tipsState {
                            recoverableRefusalCard(
                                reason: "Couldn't reach the coach. Try again.",
                                kind: .notASpeakingPrompt
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 7) {
                                    Text(DifficultyLevel.tier(for: level))
                                        .font(AppFonts.bodyMedium(10))
                                        .foregroundStyle(AppColors.dim)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 3)
                                        .background(AppColors.faint)
                                        .clipShape(Capsule())

                                    PillBadge(text: "\(question.targetDuration)s", emoji: "⏱", color: mode.accentColor, small: true)
                                }

                                if mode == .realLife, case .loading = tipsState {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.card2)
                                            .frame(height: 18)
                                            .shimmering()
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.card2)
                                            .frame(width: 220, height: 18)
                                            .shimmering()
                                    }
                                    .accessibilityLabel("Polishing your scenario…")
                                } else {
                                    Text("\"\(displayedPrompt)\"")
                                        .font(AppFonts.display(20))
                                        .foregroundStyle(AppColors.text)
                                        .lineSpacing(6)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(padding: 20, borderColor: mode.accentColor.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Coaching tips
                    Group {
                        switch tipsState {
                        case .ready(let tips) where !tips.isEmpty:
                            tipsBlock(tips: tips, shimmer: false)
                        case .loading:
                            tipsBlock(tips: ["", "", ""], shimmer: true)
                        case .refused, .failed:
                            EmptyView()
                        case .ready:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 140)
            }

            Spacer(minLength: 0)

            // Start recording button
            if !isUnrecoverable {
                PrimaryButton(title: "Start Recording", icon: "mic.fill", action: onReady)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .accessibilityLabel("Start recording")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg.ignoresSafeArea())
        .sheet(isPresented: $showTopicPicker) {
            TopicPickerSheet(
                selected: currentTopicCategory ?? .any,
                onPick: { newCategory in
                    onReshuffleTopic?(newCategory)
                }
            )
            .presentationDetents([.fraction(0.78)])
            .presentationBackground(AppColors.bg)
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
        }
        .onChange(of: question.id) { _, _ in
            if question.mode != .realLife { displayedPrompt = question.question }
        }
        .task {
            guard mode == .realLife, case .loading = tipsState else { return }
            let result = await tipsClient.fetchTips(
                scenario: question.question,
                level: level,
                durationSeconds: question.targetDuration
            )
            await MainActor.run {
                switch result {
                case .tips(let rewrittenPrompt, let tips):
                    displayedPrompt = rewrittenPrompt
                    onPromptRewritten?(rewrittenPrompt)
                    tipsState = .ready(tips)
                case .refused(let r, let k):
                    tipsState = .refused(reason: r, kind: k)
                case .failed:
                    tipsState = .failed
                }
            }
        }
    }

    private func tipsBlock(tips: [String], shimmer: Bool) -> some View {
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
                            .foregroundStyle(mode.accentColor)
                            .frame(width: 16, alignment: .leading)
                        if shimmer {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.card2)
                                .frame(height: 12)
                                .shimmering()
                                .padding(.top, 4)
                        } else {
                            Text(tip)
                                .font(AppFonts.body(13))
                                .foregroundStyle(AppColors.text.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private var isUnrecoverable: Bool {
        if case .refused = tipsState { return true }
        if case .failed = tipsState { return true }
        return false
    }

    private func recoverableRefusalCard(reason: String, kind: RealLifeRefusalKind) -> some View {
        let title = (kind == .notASpeakingPrompt) ? "Let's try again" : "Can't coach this one"
        return VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(AppFonts.bodyBold(9))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)
            Text(reason)
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.text.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            if kind == .notASpeakingPrompt {
                Button {
                    onEditScenario?(question.question)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Edit Scenario")
                            .font(AppFonts.bodyBold(14))
                    }
                    .foregroundStyle(AppColors.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("realLife.editScenario")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20, borderColor: mode.accentColor.opacity(0.3))
    }
}
