import Foundation
import SwiftData

@Model
final class SeenQuestion {
    var questionId: String
    var modeRaw: String
    var difficultyBand: String
    var seenAt: Date

    var mode: SessionMode {
        SessionMode(rawValue: modeRaw) ?? .interview
    }

    init(questionId: String, mode: SessionMode, difficultyBand: String) {
        self.questionId = questionId
        self.modeRaw = mode.rawValue
        self.difficultyBand = difficultyBand
        self.seenAt = .now
    }
}
