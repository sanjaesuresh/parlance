// Single registry for every UserDefaults key the app reads or writes.
// Previously the same string literals appeared in 11 files; a rename in
// one site was a silent runtime bug. New keys go here. Existing call sites
// can migrate incrementally without behavior change — the raw values are
// preserved exactly so on-disk state is compatible.
import Foundation

enum UserDefaultsKey: String {
    // Appearance
    case appTheme = "appTheme"

    // Notifications & sound
    case dailyReminderEnabled = "dailyReminderEnabled"
    case soundEffectsEnabled = "soundEffectsEnabled"

    // Onboarding / welcome routing
    case welcomeUID = "parlance.welcome_uid"
    case welcomeBackUID = "parlance.welcome_back_uid"
    case hasSeenTeach = "parlance.has_seen_teach"

    // Persistence
    case storeWiped = "parlance.store_wiped"
    case pendingSync = "parlance.pendingSync"

    // Local caches
    case friendsRankHistoryV1 = "parlance.friendsRankHistory.v1"
    case realLifeRecentScenarios = "realLife.recentScenarios"
}

extension UserDefaults {
    func bool(for key: UserDefaultsKey) -> Bool { bool(forKey: key.rawValue) }
    func string(for key: UserDefaultsKey) -> String? { string(forKey: key.rawValue) }
    func data(for key: UserDefaultsKey) -> Data? { data(forKey: key.rawValue) }
    func set(_ value: Any?, for key: UserDefaultsKey) { set(value, forKey: key.rawValue) }
    func removeObject(for key: UserDefaultsKey) { removeObject(forKey: key.rawValue) }
}
