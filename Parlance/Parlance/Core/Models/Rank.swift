import Foundation

struct Rank {
    let level: Int
    let name: String
    let xpRequired: Int
    let xpForNextRank: Int?

    var isMaxRank: Bool { level == 10 }

    private static let thresholds: [(level: Int, name: String, xp: Int)] = [
        (1, "Newcomer", 0),
        (2, "Apprentice", 500),
        (3, "Practitioner", 1200),
        (4, "Communicator", 2500),
        (5, "Rhetorician", 4500),
        (6, "Debater", 7000),
        (7, "Presenter", 10500),
        (8, "Orator", 15000),
        (9, "Virtuoso", 21000),
        (10, "Master", 30000)
    ]

    static func forLevel(_ level: Int) -> Rank? {
        guard let entry = thresholds.first(where: { $0.level == level }) else { return nil }
        let nextXP = thresholds.first(where: { $0.level == level + 1 })?.xp
        return Rank(level: entry.level, name: entry.name, xpRequired: entry.xp, xpForNextRank: nextXP)
    }

    static func from(xp: Int) -> Rank {
        var current = thresholds[0]
        var nextXP: Int? = thresholds[1].xp

        for i in 0..<thresholds.count {
            if xp >= thresholds[i].xp {
                current = thresholds[i]
                nextXP = i + 1 < thresholds.count ? thresholds[i + 1].xp : nil
            }
        }

        return Rank(level: current.level, name: current.name, xpRequired: current.xp, xpForNextRank: nextXP)
    }
}
