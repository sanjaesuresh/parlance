import SwiftUI

/// Three-segment period picker (Week / 30 days / All time) that scopes the
/// Progress tab. Matches the mockup in `_docs/plans/2026-05-13-progress-tab-rework.md`
/// §4.2 — paddings, radii, colors and fonts are pinned by that spec.
struct ProgressSegmentedControl: View {
    @Binding var selection: PeriodFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PeriodFilter.allCases) { period in
                segment(for: period)
            }
        }
        .padding(3)
        .background(AppColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func segment(for period: PeriodFilter) -> some View {
        let isActive = selection == period
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = period
            }
        } label: {
            Text(period.label)
                .font(AppFonts.bodyMedium(12))
                .foregroundStyle(isActive ? AppColors.text : AppColors.sub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isActive {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(AppColors.card2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(AppColors.border, lineWidth: 1)
                                )
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("periodFilter.\(period.rawValue)")
    }
}

#Preview {
    StatefulPreviewWrapper(PeriodFilter.month) { binding in
        ProgressSegmentedControl(selection: binding)
            .padding()
            .background(AppColors.bg)
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
