import Foundation

struct PublicProfile: Identifiable {
    let id: String
    let username: String
    let avatarEmoji: String
    let weeklyXP: Int
    let tier: LeagueTier
}
