import Foundation

enum ProfanityFilter {
    /// Slurs — always block the recording when present (regardless of ratio).
    static let slurs: Set<String> = [
        "nigger", "nigga", "faggot", "fag", "retard", "tranny", "kike",
        "spic", "chink", "gook", "wetback", "tard", "raghead"
    ]

    /// General profanity — block only when ratio exceeds the gate threshold.
    static let profanity: Set<String> = [
        "fuck", "fucking", "fucked", "fucker", "motherfucker",
        "shit", "shitty", "bullshit",
        "cunt", "bitch", "bitches", "asshole", "ass", "arsehole",
        "dick", "dickhead", "cock", "prick", "piss", "pissed",
        "bastard", "whore", "slut", "skank",
        "wank", "wanker", "twat", "bollocks",
        "rape", "raping", "pedo", "pedophile",
        "nazi", "hitler"
    ]

    /// Used by the typed-scenario validator. Less strict (substring + word).
    static var typedScenarioDenylist: Set<String> { slurs.union(profanity) }

    /// Strict typed-input validator (existing behavior — substring match for
    /// short typed fields where false positives are acceptable).
    /// Returns nil if acceptable, or a user-facing error message if rejected.
    static func validate(_ input: String, fieldName: String) -> String? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let denyList = typedScenarioDenylist
        let words = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for word in words where denyList.contains(word) {
            return "\(fieldName) contains language that isn't allowed."
        }
        for entry in denyList where normalized.contains(entry) {
            return "\(fieldName) contains language that isn't allowed."
        }
        return nil
    }

    struct TranscriptScanResult: Equatable {
        let totalWords: Int
        let profaneWordCount: Int
        let containsSlur: Bool
        var ratio: Double {
            totalWords > 0 ? Double(profaneWordCount) / Double(totalWords) : 0
        }
        var hasAnyProfanity: Bool { profaneWordCount > 0 || containsSlur }
    }

    /// Word-boundary, case-insensitive scan of a transcribed recording.
    /// Counts slurs as profanity AND flags `containsSlur`.
    static func scanTranscript(_ transcript: String) -> TranscriptScanResult {
        let normalized = transcript.lowercased()
        let words = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.isEmpty else {
            return TranscriptScanResult(totalWords: 0, profaneWordCount: 0, containsSlur: false)
        }
        var profaneCount = 0
        var hasSlur = false
        let combined = slurs.union(profanity)
        for word in words {
            if combined.contains(word) {
                profaneCount += 1
                if slurs.contains(word) { hasSlur = true }
            }
        }
        return TranscriptScanResult(
            totalWords: words.count,
            profaneWordCount: profaneCount,
            containsSlur: hasSlur
        )
    }
}
