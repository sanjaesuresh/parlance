import SwiftUI

struct ToneDetailSheet: View {
    let emotionResult: EmotionResult
    let sessionDuration: TimeInterval

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    arcSection
                    peaksAndDipsSection
                    if emotionResult.topEmotions?.isEmpty == false {
                        topEmotionsSection
                    }
                    if !notableShifts.isEmpty {
                        notableShiftsSection
                    }
                    if emotionResult.topEmotions == nil {
                        emotionBreakdownSection
                    }
                    explainerCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("Vocal Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.text)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hero

    private var hero: some View {
        let percent = Int((emotionResult.dominantScore * 100).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("STRONGEST SIGNAL")
                    .font(AppFonts.bodyBold(9.5))
                    .kerning(1.8)
                    .foregroundStyle(AppColors.purple)
                Spacer()
                proChip
            }
            Text(emotionResult.dominantEmotion)
                .font(AppFonts.display(34))
                .foregroundStyle(AppColors.text)
            (
                Text("\(percent)% ")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.text)
                + Text("· this is the tone that carried most of your delivery")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.purple.opacity(0.45), lineWidth: 1)
        )
    }

    private var proChip: some View {
        HStack(spacing: 5) {
            Text("✦").font(.system(size: 10))
            Text("PRO").font(AppFonts.bodyBold(9)).kerning(1)
        }
        .foregroundStyle(AppColors.gold)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppColors.gold.opacity(0.18))
        .clipShape(Capsule())
    }

    // MARK: - Arc

    private var arcSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TONE ARC OVER TIME")
            LargeToneArcView(
                arc: emotionResult.emotionArc,
                duration: sessionDuration
            )
            HStack(spacing: 14) {
                legendDot(color: AppColors.teal, label: "Tone strength")
                legendDot(color: AppColors.purple, label: "Peak")
                legendDot(color: AppColors.red, label: "Dip")
                Spacer()
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(AppFonts.body(10.5))
                .foregroundStyle(AppColors.sub)
        }
    }

    // MARK: - Peaks & Dips

    private var peaksAndDipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PEAKS & DIPS")
            HStack(spacing: 10) {
                if let peak = peakMoment {
                    momentCard(
                        title: "Strongest",
                        timestamp: peak.timestamp,
                        valuePct: peak.percent,
                        accent: AppColors.purple,
                        icon: "arrow.up.right",
                        subtitle: "Your tone landed hardest here."
                    )
                }
                if let dip = dipMoment {
                    momentCard(
                        title: "Quietest",
                        timestamp: dip.timestamp,
                        valuePct: dip.percent,
                        accent: AppColors.red,
                        icon: "arrow.down.right",
                        subtitle: "Energy thinned out around here."
                    )
                }
            }
            if peakMoment == nil && dipMoment == nil {
                Text("Not enough samples in this recording to surface peaks and dips.")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.dim)
            }
        }
    }

    private func momentCard(title: String, timestamp: String, valuePct: Int, accent: Color, icon: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(title.uppercased())
                    .font(AppFonts.bodyBold(10))
                    .kerning(1.2)
                    .foregroundStyle(accent)
            }
            Text(timestamp)
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.text)
            Text("\(valuePct)% intensity")
                .font(AppFonts.bodyMedium(11))
                .foregroundStyle(AppColors.sub)
            Text(subtitle)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Top emotions (full top-10 from Hume)

    private var topEmotionsSection: some View {
        let emotions = emotionResult.topEmotions ?? []
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TOP EMOTIONS DETECTED")
            VStack(spacing: 0) {
                ForEach(Array(emotions.enumerated()), id: \.offset) { idx, emotion in
                    topEmotionRow(rank: idx + 1, emotion: emotion, max: emotions.first?.score ?? 1)
                    if idx < emotions.count - 1 {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 0.5)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            Text("Ranked by how often each emotion came through across your delivery.")
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
        }
    }

    private func topEmotionRow(rank: Int, emotion: EmotionResult.TopEmotion, max: Double) -> some View {
        let pct = Int((emotion.score * 100).rounded())
        let widthFraction = max > 0 ? emotion.score / max : 0
        return HStack(spacing: 12) {
            Text(String(format: "%02d", rank))
                .font(AppFonts.bodyBold(11))
                .foregroundStyle(AppColors.dim)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(emotion.name)
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(pct)%")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.sub)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.faint.opacity(0.5))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(forRank: rank))
                            .frame(width: maxBar(geo.size.width, fraction: widthFraction))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func color(forRank rank: Int) -> Color {
        switch rank {
        case 1: return AppColors.purple
        case 2, 3: return AppColors.teal
        case 4, 5, 6: return AppColors.gold
        default: return AppColors.sub
        }
    }

    private func maxBar(_ width: CGFloat, fraction: Double) -> CGFloat {
        let clamped = min(max(fraction, 0), 1)
        return max(2, width * CGFloat(clamped))
    }

    // MARK: - Notable shifts

    private struct Shift {
        let name: String
        let delta: Double // last-third avg − first-third avg
        let startPct: Int
        let endPct: Int
    }

    private var notableShifts: [Shift] {
        guard let timelines = emotionResult.emotionTimelines else { return [] }
        let shifts: [Shift] = timelines.compactMap { name, arc in
            guard arc.count >= 3 else { return nil }
            let third = max(1, arc.count / 3)
            let firstAvg = arc.prefix(third).reduce(0, +) / Double(third)
            let lastAvg = arc.suffix(third).reduce(0, +) / Double(third)
            return Shift(
                name: name,
                delta: lastAvg - firstAvg,
                startPct: Int((firstAvg * 100).rounded()),
                endPct: Int((lastAvg * 100).rounded())
            )
        }
        let biggestRise = shifts.filter { $0.delta > 0.08 }.max(by: { $0.delta < $1.delta })
        let biggestDrop = shifts.filter { $0.delta < -0.08 }.min(by: { $0.delta < $1.delta })
        return [biggestRise, biggestDrop].compactMap { $0 }
    }

    private var notableShiftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("NOTABLE SHIFTS")
            VStack(spacing: 10) {
                ForEach(Array(notableShifts.enumerated()), id: \.offset) { _, shift in
                    shiftCard(shift)
                }
            }
        }
    }

    private func shiftCard(_ shift: Shift) -> some View {
        let isRise = shift.delta > 0
        let accent = isRise ? AppColors.teal : AppColors.red
        let arrow = isRise ? "arrow.up.right" : "arrow.down.right"
        let verb = isRise ? "grew" : "faded"
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                Image(systemName: arrow)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(shift.name) \(verb) over the recording")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.text)
                Text("\(shift.startPct)% at the start → \(shift.endPct)% by the end")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Emotion bars

    private var emotionBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("EMOTION BREAKDOWN")
            VStack(spacing: 10) {
                emotionRow(
                    label: "Enthusiasm",
                    score: emotionResult.enthusiasmScore,
                    color: AppColors.teal,
                    description: "Energy and forward momentum in your voice."
                )
                emotionRow(
                    label: "Determination",
                    score: emotionResult.confidenceScore,
                    color: AppColors.gold,
                    description: "Conviction and steadiness behind your words."
                )
                emotionRow(
                    label: "Nervousness",
                    score: emotionResult.nervousnessScore,
                    color: AppColors.red,
                    description: "Tightness or hesitation in your delivery."
                )
            }
        }
    }

    private func emotionRow(label: String, score: Double, color: Color, description: String) -> some View {
        let pct = Int((score * 100).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text("\(pct)%")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.faint.opacity(0.5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(score, 0), 1))))
                }
            }
            .frame(height: 6)
            Text(description)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
        }
        .padding(14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Explainer

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("HOW THIS IS MEASURED")
            Text("Tone is sampled every ~2 seconds by Hume AI from the pitch, energy, and rhythm of your voice, not the words themselves. Each point on the arc is how strongly your dominant emotion came through in that segment.")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.sub)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFonts.bodyBold(10))
            .kerning(1.6)
            .foregroundStyle(AppColors.dim)
    }

    private struct Moment {
        let timestamp: String
        let percent: Int
    }

    private var peakMoment: Moment? {
        moment(extreme: .max)
    }

    private var dipMoment: Moment? {
        moment(extreme: .min)
    }

    private enum Extreme { case min, max }

    private func moment(extreme: Extreme) -> Moment? {
        let arc = emotionResult.emotionArc
        guard arc.count >= 2 else { return nil }
        let indexed = arc.enumerated()
        let target: (offset: Int, element: Double)?
        switch extreme {
        case .max: target = indexed.max(by: { $0.element < $1.element })
        case .min: target = indexed.min(by: { $0.element < $1.element })
        }
        guard let t = target else { return nil }
        let position = Double(t.offset) / Double(max(arc.count - 1, 1))
        let secs = position * max(sessionDuration, 0)
        let minutes = Int(secs) / 60
        let seconds = Int(secs) % 60
        return Moment(
            timestamp: String(format: "%d:%02d", minutes, seconds),
            percent: Int((min(max(t.element, 0), 1) * 100).rounded())
        )
    }
}

// MARK: - LargeToneArcView

private struct LargeToneArcView: View {
    let arc: [Double]
    let duration: TimeInterval

    private var clampedArc: [Double] {
        arc.map { min(max($0, 0), 1) }
    }

    private var peakIndex: Int? {
        clampedArc.enumerated().max(by: { $0.element < $1.element })?.offset
    }

    private var dipIndex: Int? {
        clampedArc.enumerated().min(by: { $0.element < $1.element })?.offset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pts = clampedArc
                let count = max(pts.count - 1, 1)
                ZStack {
                    ForEach(0..<5) { i in
                        let y = h * CGFloat(i) / 4.0
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(
                            AppColors.faint.opacity(i == 2 ? 0.6 : 0.25),
                            style: StrokeStyle(lineWidth: 0.5, dash: i == 2 ? [] : [2, 3])
                        )
                    }

                    if pts.count >= 2 {
                        Path { p in
                            for (i, v) in pts.enumerated() {
                                let x = CGFloat(i) / CGFloat(count) * w
                                let y = h - CGFloat(v) * h
                                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: 0, y: h))
                            p.closeSubpath()
                        }
                        .fill(AppColors.teal.opacity(0.14))

                        Path { p in
                            for (i, v) in pts.enumerated() {
                                let x = CGFloat(i) / CGFloat(count) * w
                                let y = h - CGFloat(v) * h
                                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(
                            AppColors.teal,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                        if let pi = peakIndex {
                            markerDot(x: CGFloat(pi) / CGFloat(count) * w,
                                      y: h - CGFloat(pts[pi]) * h,
                                      color: AppColors.purple)
                        }
                        if let di = dipIndex, di != peakIndex {
                            markerDot(x: CGFloat(di) / CGFloat(count) * w,
                                      y: h - CGFloat(pts[di]) * h,
                                      color: AppColors.red)
                        }
                    } else {
                        Text("Tone arc not available for this recording.")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 130)
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 6, trailing: 12))

            HStack {
                Text("0:00")
                Spacer()
                Text(formatDuration(duration / 2))
                Spacer()
                Text(formatDuration(duration))
            }
            .font(AppFonts.body(10))
            .foregroundStyle(AppColors.dim)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func markerDot(x: CGFloat, y: CGFloat, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(AppColors.bg, lineWidth: 1.5))
            .position(x: x, y: y)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let secs = max(t, 0)
        let minutes = Int(secs) / 60
        let seconds = Int(secs) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
