import Foundation
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var selectedTab: Int = 0
    @Published var openFriendRequests: Bool = false

    private init() {}

    func route(type: String) {
        switch type {
        case "daily_reminder":
            selectedTab = 0
        case "friend_request":
            selectedTab = 2
            openFriendRequests = true
        case "league_reset":
            selectedTab = 2
        default:
            break
        }
    }
}
