import Foundation

enum ActivityEventKind {
    case score(value: Int, mode: SessionMode)
    case personalBest(mode: SessionMode, score: Int)
}

struct ActivityEvent: Identifiable {
    let id: UUID = UUID()
    let actorUsername: String
    let actorDisplayName: String
    let actorAvatarEmoji: String
    let occurredAt: Date
    let kind: ActivityEventKind
    let actorAvatarUrl: String?
    let actorAvatarUpdatedAt: Date?
}
