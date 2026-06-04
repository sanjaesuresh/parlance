import SwiftUI

struct TopicPickerSheet: View {
    let selected: ExplanationCategory
    let onPick: (ExplanationCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    private var industries: [ExplanationCategory] {
        ExplanationCategory.allCases.filter { $0.tier == .industry }
    }

    private var knowledge: [ExplanationCategory] {
        ExplanationCategory.allCases.filter { $0.tier == .knowledge }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(label: nil, items: [.any])
                    section(label: "Industries", items: industries)
                    section(label: "Knowledge", items: knowledge)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .accessibilityIdentifier("explain.topicPicker")
    }

    private var header: some View {
        VStack(spacing: 0) {
            // Drag handle (mimics iOS native, but on our solid bg)
            Capsule()
                .fill(AppColors.dim.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 14)

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 0) {
                    Text("Pick a")
                        .font(AppFonts.display(22))
                        .foregroundStyle(AppColors.text)
                    Text(" topic")
                        .font(AppFonts.display(22))
                        .foregroundStyle(AppColors.gold)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.sub)
                        .frame(width: 28, height: 28)
                        .background(AppColors.card)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("explain.topicPicker.close")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func section(label: String?, items: [ExplanationCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                HStack(spacing: 8) {
                    Text(label)
                        .font(AppFonts.bodyBold(10))
                        .kerning(0.4)
                        .foregroundStyle(AppColors.dim)
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 1)
                }
                .padding(.top, 4)
            }

            VStack(spacing: 8) {
                ForEach(items, id: \.self) { row($0) }
            }
        }
    }

    private func row(_ category: ExplanationCategory) -> some View {
        let isSelected = category == selected
        return Button {
            onPick(category)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(category.displayName)
                    .font(AppFonts.bodyMedium(15))
                    .foregroundStyle(isSelected ? AppColors.text : AppColors.text.opacity(0.85))
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColors.gold.opacity(0.08) : AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppColors.gold.opacity(0.55) : AppColors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("explain.topicPicker.\(category.rawValue)")
    }
}

#Preview {
    TopicPickerSheet(selected: .tech, onPick: { _ in })
}
