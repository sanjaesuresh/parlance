import SwiftUI

enum SessionMode: String, CaseIterable, Codable {
    case realLife
    case interview
    case pitch
    case keynote
    case casual
    case debate
    case storytelling
    case explanation
    case negotiation
    case impromptu
    case networking

    var displayName: String {
        switch self {
        case .realLife: "Real Life"
        case .interview: "Job Interview"
        case .pitch: "Pitch / Sales"
        case .keynote: "Keynote / Talk"
        case .casual: "Daily Convo"
        case .debate: "Debate / Argue"
        case .storytelling: "Storytelling"
        case .explanation: "Explain a Topic"
        case .negotiation: "Negotiation"
        case .impromptu: "Impromptu"
        case .networking: "Networking"
        }
    }

    var emoji: String {
        switch self {
        case .realLife: "\u{1F3AF}"
        case .interview: "\u{1F4BC}"
        case .pitch: "\u{1F680}"
        case .keynote: "\u{1F3A4}"
        case .casual: "\u{1F4AC}"
        case .debate: "\u{1F5E3}"
        case .storytelling: "\u{1F4D6}"
        case .explanation: "\u{1F9E0}"
        case .negotiation: "\u{1F91D}"
        case .impromptu: "\u{26A1}"
        case .networking: "\u{1F310}"
        }
    }

    var systemImageName: String {
        switch self {
        case .realLife: "target"
        case .interview: "briefcase.fill"
        case .pitch: "chart.line.uptrend.xyaxis"
        case .keynote: "mic.fill"
        case .casual: "bubble.left.and.bubble.right.fill"
        case .debate: "figure.2.arms.open"
        case .storytelling: "text.book.closed.fill"
        case .explanation: "book.fill"
        case .negotiation: "arrow.left.and.right.circle.fill"
        case .impromptu: "bolt.fill"
        case .networking: "person.2.fill"
        }
    }

    /// Modes map to one of four brand-derived family colors:
    /// gold = career, teal = communication, purple = performance, red = high stakes.
    var accentColor: Color {
        switch self {
        case .interview, .pitch: AppColors.gold
        case .casual, .explanation, .networking: AppColors.teal
        case .keynote, .debate, .storytelling, .impromptu: AppColors.purple
        case .realLife, .negotiation: AppColors.red
        }
    }

    var description: String {
        switch self {
        case .realLife: "Practice your actual conversation."
        case .interview: "Answer with confidence. No rambling."
        case .pitch: "Hooks, urgency, persuasion."
        case .keynote: "Structure, flow, and presence."
        case .casual: "Clear, natural, engaging."
        case .debate: "Build arguments. Hold your ground."
        case .storytelling: "Captivate with narrative and detail."
        case .explanation: "Break down complex ideas simply."
        case .negotiation: "Persuade, compromise, close."
        case .impromptu: "Think fast. No prep, just speak."
        case .networking: "Introduce yourself. Make connections."
        }
    }

    /// The default 4 modes shown on the home screen grid (all free modes)
    static let defaultModes: [SessionMode] = [.interview, .casual, .impromptu, .explanation]

    static func dailyChallengeMode(dayOfYear: Int) -> SessionMode {
        let pool = SessionMode.allCases.filter { $0 != .realLife }
        return pool[dayOfYear % pool.count]
    }

    static func dailyChallengeMode() -> SessionMode {
        let pool = SessionMode.allCases.filter { $0 != .realLife }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return pool[dayOfYear % pool.count]
    }

    /// Modes available on the free tier. All others require Pro.
    static let freeModes: Set<SessionMode> = [.interview, .casual, .impromptu, .explanation, .networking]

    var isProMode: Bool { !Self.freeModes.contains(self) }
}
