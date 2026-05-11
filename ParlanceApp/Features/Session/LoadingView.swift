import SwiftUI

struct LoadingView: View {
    let mode: SessionMode
    let level: Int
    let question: Question
    let onReady: () -> Void
    var onCancel: (() -> Void)?
    var currentTopicCategory: ExplanationCategory? = nil
    var onReshuffleTopic: ((ExplanationCategory) -> Void)? = nil
    var tipsClient: RealLifeTipsFetching = RealLifeTipsClient()

    enum TipsState: Equatable {
        case ready([String])
        case loading
        case refused(String)
        case failed
    }

    @State private var tipsState: TipsState
    @State private var showTopicPicker = false

    init(
        mode: SessionMode,
        level: Int,
        question: Question,
        onReady: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        currentTopicCategory: ExplanationCategory? = nil,
        onReshuffleTopic: ((ExplanationCategory) -> Void)? = nil,
        tipsClient: RealLifeTipsFetching = RealLifeTipsClient()
    ) {
        self.mode = mode
        self.level = level
        self.question = question
        self.onReady = onReady
        self.onCancel = onCancel
        self.currentTopicCategory = currentTopicCategory
        self.onReshuffleTopic = onReshuffleTopic
        self.tipsClient = tipsClient
        _tipsState = State(initialValue: mode == .realLife ? .loading : .ready(question.tips))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                if let onCancel {
                    Button(action: onCancel) {
                        Text("← Back")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Cancel")
                } else {
                    Spacer().frame(width: 72)
                }

                Spacer()

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

                Spacer()

                Spacer().frame(width: 72)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

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

                        Text("\"\(question.question)\"")
                            .font(AppFonts.display(20))
                            .foregroundStyle(AppColors.text)
                            .lineSpacing(6)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(mode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    // Coaching tips
                    Group {
                        switch tipsState {
                        case .ready(let tips) where !tips.isEmpty:
                            tipsBlock(tips: tips, shimmer: false)
                        case .loading:
                            tipsBlock(tips: ["", "", ""], shimmer: true)
                        case .refused(let reason):
                            refusedBlock(reason: reason)
                        case .ready, .failed:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 140)
            }

            Spacer(minLength: 0)

            // Start recording button
            Button(action: onReady) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Start Recording")
                        .font(AppFonts.bodyBold(16))
                }
                .foregroundStyle(AppColors.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .accessibilityLabel("Start recording")
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
        .task {
            guard mode == .realLife, case .loading = tipsState else { return }
            let result = await tipsClient.fetchTips(
                scenario: question.question,
                level: level,
                durationSeconds: question.targetDuration
            )
            await MainActor.run {
                switch result {
                case .tips(let tips):  tipsState = .ready(tips)
                case .refused(let r):  tipsState = .refused(r)
                case .failed:          tipsState = .failed
                }
            }
        }
    }

    private func tipsBlock(tips: [String], shimmer: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(AppColors.border).frame(height: 1)
                Text("FOCUS AREAS")
                    .font(AppFonts.bodyBold(9))
                    .foregroundStyle(AppColors.dim)
                    .kerning(1.3)
                    .fixedSize()
                Rectangle().fill(AppColors.border).frame(height: 1)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.custom("Fraunces72pt-Bold", size: 20))
                            .foregroundStyle(mode.accentColor)
                            .frame(width: 16, alignment: .leading)
                        if shimmer {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.card2)
                                .frame(height: 12)
                                .shimmering()
                        } else {
                            Text(tip)
                                .font(AppFonts.body(13))
                                .foregroundStyle(AppColors.text.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func refusedBlock(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAN'T COACH THIS ONE")
                .font(AppFonts.bodyBold(9))
                .kerning(1.3)
                .foregroundStyle(AppColors.dim)
            Text(reason)
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.text.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
    }
}
