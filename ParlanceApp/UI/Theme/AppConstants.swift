import Foundation

enum AppConstants {
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14
    static let maxRecordingDuration: TimeInterval = 180
    static let minRecordingDuration: TimeInterval = 5
    static let wrapUpWarningTime: TimeInterval = 165
    static let deliberateNudgeTime: TimeInterval = 8
    static let loadingMinDuration: TimeInterval = 0.5
    static let freeSessionsPerDay = 2
    static let maxNameLength = 30
    static let transcriptExcerptLength = 400
    static let seenQuestionWindow = 50
    static let waveformBarCount = 38
    static let baseXP = 120
    static let dailyChallengeXP = 200
    static let personalBestXPBonus = 100
    static let difficultyXPBonus = 20     // per difficulty tier above 5 (level 6–7: ×1, 8–9: ×2, 10: ×3)
    static let feedbackTimeout: TimeInterval = 8
    static let scoringTimeout: TimeInterval = 30
    static let humeTimeout: TimeInterval = 45
    static let humePollBudget: TimeInterval = 90
    // The app bundle ID is `org.Parlance` but the IAP product ID lives in the
    // `com.parlance.*` namespace. StoreKit keys subscriptions by the App Store
    // Connect record, not by bundle-ID prefix, so this works — leaving the
    // mismatch as a note rather than renaming the bundle (which would break
    // existing installs and provisioning).
    static let proProductID = "com.parlance.pro.monthly"
    nonisolated static var apiBaseURL: URL {
        let fallback = "https://parlance-api.parlance-app.workers.dev"
        let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String ?? fallback
        return URL(string: urlString) ?? URL(string: fallback)!
    }

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 14
        static let lg: CGFloat = 18  // matches AppConstants.cardRadius
        static let xl: CGFloat = 20
    }

    enum IconButton {
        static let size: CGFloat = 36
        static let glyph: CGFloat = 15
        // Apple HIG minimum tap target. Use as the .contentShape or outer frame
        // when the visual is smaller than 44pt so hit testing still meets HIG.
        static let hitTarget: CGFloat = 44
    }
}
