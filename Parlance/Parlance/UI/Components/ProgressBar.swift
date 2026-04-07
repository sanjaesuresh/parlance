import SwiftUI

struct ProgressBar: View {
    let pct: Double
    var color: Color = AppColors.gold
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 99)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: 99)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(pct / 100, 1.0)), height: height)
                    .animation(.easeOut(duration: 1.1), value: pct)
            }
        }
        .frame(height: height)
    }
}
