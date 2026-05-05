// Parlance/Core/Services/FriendsService.swift
import Foundation
import Combine

/// Manages the local friends list. Friend relationships are persisted in UserDefaults.
/// The friend pool is currently mock data (SocialProfile.mockUsers); when a backend
/// ships, this service will be updated to fetch real profiles instead.
@MainActor
final class FriendsService: ObservableObject {
    @Published private(set) var friendIDs: Set<String> = []

    private let key = "parlance.friendIDs"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        friendIDs = Set(saved)
    }

    var friends: [SocialProfile] {
        SocialProfile.mockUsers.filter { friendIDs.contains($0.id) }
    }

    func isFriend(_ id: String) -> Bool {
        friendIDs.contains(id)
    }

    func addFriend(_ id: String) {
        friendIDs.insert(id)
        persist()
    }

    func removeFriend(_ id: String) {
        friendIDs.remove(id)
        persist()
    }

    func toggleFriend(_ id: String) {
        if isFriend(id) { removeFriend(id) } else { addFriend(id) }
    }

    private func persist() {
        UserDefaults.standard.set(Array(friendIDs), forKey: key)
    }
}
