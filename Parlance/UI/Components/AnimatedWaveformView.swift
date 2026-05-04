import SwiftUI

struct AnimatedWaveformView: View {
    let levels: [Float]
    let isActive: Bool
    let accentColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? accentColor : AppColors.sub.opacity(0.3))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: levels[index])
            }
        }
        .frame(height: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? "Microphone active, recording in progress" : "Microphone inactive")
        .accessibilityIgnoresInvertColors(true)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(levels[index])
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 60
        return isActive ? max(minHeight, level * maxHeight) : minHeight
    }
}
