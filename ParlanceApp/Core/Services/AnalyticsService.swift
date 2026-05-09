import Foundation
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

enum AnalyticsService {
    static func initialize() {
        #if canImport(TelemetryDeck)
        TelemetryDeck.initialize(config: .init(appID: AnalyticsConfig.appID))
        #endif
    }

    // MARK: - Session events

    static func sessionStarted(mode: SessionMode, level: Int) {
        log("sessionStarted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)"
        ])
    }

    static func sessionCompleted(mode: SessionMode, level: Int, overallScore: Int, duration: TimeInterval, wasDailyChallenge: Bool) {
        log("sessionCompleted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)",
            "overallScore": "\(overallScore)",
            "duration": "\(Int(duration))",
            "wasDailyChallenge": "\(wasDailyChallenge)"
        ])
    }

    static func sessionAbandoned(mode: String, secondsElapsed: Int) {
        log("sessionAbandoned", parameters: [
            "mode": mode,
            "secondsElapsed": "\(secondsElapsed)"
        ])
    }

    static func dailyChallengeCompleted(mode: SessionMode, level: Int) {
        log("dailyChallengeCompleted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)"
        ])
    }

    // MARK: - Gamification events

    static func rankUp(newRank: Int, rankName: String) {
        log("rankUp", parameters: [
            "newRank": "\(newRank)",
            "rankName": rankName
        ])
    }

    static func achievementUnlocked(id: String, name: String) {
        log("achievementUnlocked", parameters: [
            "achievementId": id,
            "achievementName": name
        ])
    }

    // MARK: - Paywall events

    static func paywallShown(source: String) {
        log("paywallShown", parameters: ["source": source])
    }

    static func paywallConverted(productId: String) {
        log("paywallConverted", parameters: ["productId": productId])
    }

    // MARK: - Social events

    static func friendRequestSent() {
        log("friendRequestSent", parameters: [:])
    }

    static func friendRequestAccepted() {
        log("friendRequestAccepted", parameters: [:])
    }

    static func friendRequestDeclined() {
        log("friendRequestDeclined", parameters: [:])
    }

    // MARK: - Notification events

    static func notificationPermissionGranted() {
        log("notificationPermissionGranted", parameters: [:])
    }

    static func notificationPermissionDenied() {
        log("notificationPermissionDenied", parameters: [:])
    }

    static func notificationTapped(type: String) {
        log("notificationTapped", parameters: ["type": type])
    }

    // MARK: - Private

    private static func log(_ event: String, parameters: [String: String]) {
        #if DEBUG
        print("[Analytics] \(event): \(parameters)")
        #endif
        #if canImport(TelemetryDeck)
        TelemetryDeck.signal(event, parameters: parameters)
        #endif
    }
}
