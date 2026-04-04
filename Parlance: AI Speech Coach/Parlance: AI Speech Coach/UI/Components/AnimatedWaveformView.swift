import SwiftUI

struct AnimatedWaveformView: View {
    let levels: [Float]
    let isActive: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? accentColor : AppColors.sub.opacity(0.3))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
        .frame(height: 60)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(levels[index])
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 60
        return isActive ? max(minHeight, level * maxHeight) : minHeight
    }
}
