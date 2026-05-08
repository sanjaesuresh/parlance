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
        NavigationStack {
            List {
                Section {
                    row(.any)
                }
                Section("Industries") {
                    ForEach(industries, id: \.self) { row($0) }
                }
                Section("Knowledge") {
                    ForEach(knowledge, id: \.self) { row($0) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pick a topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("explain.topicPicker.close")
                }
            }
            .accessibilityIdentifier("explain.topicPicker")
        }
    }

    @ViewBuilder
    private func row(_ category: ExplanationCategory) -> some View {
        Button {
            onPick(category)
            dismiss()
        } label: {
            HStack {
                Text(category.displayName)
                    .foregroundStyle(AppColors.text)
                Spacer()
                if category == selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColors.gold)
                }
            }
        }
        .accessibilityIdentifier("explain.topicPicker.\(category.rawValue)")
    }
}

#Preview {
    TopicPickerSheet(selected: .tech, onPick: { _ in })
}
