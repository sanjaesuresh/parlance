import Foundation

enum AppConstants {
    static let cardRadius: CGFloat = 18
    static let maxRecordingDuration: TimeInterval = 180
    static let minRecordingDuration: TimeInterval = 5
    static let wrapUpWarningTime: TimeInterval = 165
    static let deliberateNudgeTime: TimeInterval = 8
    static let loadingMinDuration: TimeInterval = 0.5
    static let maxSessionsPerDay = 20
    static let freeSessionsPerDay = 5
    static let maxNameLength = 30
    static let transcriptExcerptLength = 400
    static let seenQuestionWindow = 50
    static let waveformBarCount = 38
    static let baseXP = 120
    static let dailyChallengeXP = 200
    static let feedbackTimeout: TimeInterval = 8
    static let scoringTimeout: TimeInterval = 30
    static let humeTimeout: TimeInterval = 45
    static let proProductID = "com.parlance.pro.monthly"

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
}
