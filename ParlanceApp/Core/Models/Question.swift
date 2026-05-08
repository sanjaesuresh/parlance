import Foundation

struct Question: Codable, Identifiable {
    let id: String
    let mode: SessionMode
    let difficultyBand: String
    let question: String
    let tips: [String]
    let targetDuration: Int
    let difficultyNote: String
    let category: ExplanationCategory?
}
