import Foundation

enum DifficultyLevel {
    private static let names: [Int: String] = [
        1: "Nervous Novice", 2: "First-Timer",
        3: "Getting Warmed Up", 4: "Emerging Orator",
        5: "Confident Communicator", 6: "Polished Speaker",
        7: "Compelling Storyteller", 8: "Stage Commander",
        9: "Master Presenter", 10: "Elite Orator"
    ]

    static func name(for level: Int) -> String {
        names[level] ?? "Unknown"
    }

    static func tier(for level: Int) -> String {
        switch level {
        case 1...2: "Starter"
        case 3...4: "Challenging"
        case 5...6: "Intermediate"
        case 7...8: "Advanced"
        case 9...10: "Expert"
        default: "Unknown"
        }
    }

    static func band(for level: Int) -> String {
        switch level {
        case 1...2: "1-2"
        case 3...4: "3-4"
        case 5...6: "5-6"
        case 7...8: "7-8"
        case 9...10: "9-10"
        default: "1-2"
        }
    }
}
