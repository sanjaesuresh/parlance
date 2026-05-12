import SwiftUI

struct ToneSparklineView: View {
    let arc: [Double]
    var durationLabel: String = "0:00 → 1:42"

    private let fallbackMain: [(Double, Double)] = [
        (0, 29), (36, 26), (71, 23), (107, 20), (142, 17),
        (178, 11), (213, 14), (249, 16), (284, 18), (320, 16)
    ]
    private let fallbackSide: [(Double, Double)] = [
        (0, 21), (36, 23), (71, 24), (107, 26), (142, 29),
        (178, 30), (213, 32), (249, 31), (284, 30), (320, 30)
    ]

    private var mainPoints: [(Double, Double)] {
        guard arc.count >= 10 else { return fallbackMain }
        let xs: [Double] = [0, 36, 71, 107, 142, 178, 213, 249, 284, 320]
        let step = Double(arc.count - 1) / 9.0
        var pts: [(Double, Double)] = []
        for i in 0..<10 {
            let idx = Int((Double(i) * step).rounded())
            let clamped = min(max(arc[idx], 0), 1)
            let y = 29 - clamped * 18
            pts.append((xs[i], y))
        }
        return pts
    }

    private var sidePoints: [(Double, Double)] {
        fallbackSide
    }

    private var peakPoint: (Double, Double) {
        mainPoints.min { $0.1 < $1.1 } ?? (178, 11)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            chart
                .padding(EdgeInsets(top: 22, leading: 12, bottom: 8, trailing: 12))

            Text("TONE ARC")
                .font(AppFonts.bodyBold(9))
                .kerning(1.4)
                .foregroundStyle(AppColors.dim)
                .padding(.top, 8)
                .padding(.leading, 12)

            HStack {
                Spacer()
                Text(durationLabel)
                    .font(AppFonts.body(9))
                    .foregroundStyle(AppColors.dim)
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .background(AppColors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var chart: some View {
        GeometryReader { geo in
            let xScale = geo.size.width / 320.0
            let yScale = geo.size.height / 50.0

            ZStack {
                Path { p in
                    let y = 25.0 * yScale
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: 320.0 * xScale, y: y))
                }
                .stroke(
                    AppColors.faint,
                    style: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                )

                Path { p in
                    let pts = sidePoints
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.0 * xScale, y: first.1 * yScale))
                    for pt in pts.dropFirst() {
                        p.addLine(to: CGPoint(x: pt.0 * xScale, y: pt.1 * yScale))
                    }
                }
                .stroke(
                    AppColors.red.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )

                Path { p in
                    let pts = mainPoints
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.0 * xScale, y: first.1 * yScale))
                    for pt in pts.dropFirst() {
                        p.addLine(to: CGPoint(x: pt.0 * xScale, y: pt.1 * yScale))
                    }
                }
                .stroke(
                    AppColors.teal,
                    style: StrokeStyle(lineWidth: 1.85, lineCap: .round, lineJoin: .round)
                )

                let peak = peakPoint
                Circle()
                    .fill(AppColors.teal)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle().stroke(AppColors.bg, lineWidth: 1.5)
                    )
                    .position(x: peak.0 * xScale, y: peak.1 * yScale)
            }
        }
        .frame(height: 50)
    }
}
