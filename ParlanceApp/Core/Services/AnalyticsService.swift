import Foundation

enum AnalyticsService {
    static func initialize() {
        // TODO: Initialize TelemetryDeck once SPM package is added
        // let config = TelemetryDeck.Config(appID: "YOUR_TELEMETRYDECK_APP_ID")
        // TelemetryDeck.initialize(config: config)
    }

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

    static func dailyChallengeCompleted(mode: SessionMode, level: Int) {
        log("dailyChallengeCompleted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)"
        ])
    }

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

    private static func log(_ event: String, parameters: [String: String]) {
        #if DEBUG
        print("[Analytics] \(event): \(parameters)")
        #endif
        // TODO: Replace with TelemetryDeck.signal(event, parameters: parameters)
    }
}
