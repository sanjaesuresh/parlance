// ParlanceApp/Core/Services/TranscriptCensor.swift
import Foundation

/// Replaces all but the first character of denylisted words with `*` of the
/// same length. Word-boundary, case-insensitive. Display-layer only —
/// the source transcript stored on `Session` is never mutated.
enum TranscriptCensor {
    /// Tier-1 list. Tier 2 will widen this via ProfanityFilter.
    static let denylist: [String] = [
        "fuck", "fucking", "fucked", "shit", "bitch", "cunt", "asshole",
        "dick", "piss", "bastard", "whore", "slut",
        "nigger", "faggot", "retard", "tranny", "kike", "spic", "chink"
    ]

    static func censor(_ transcript: String) -> String {
        guard !transcript.isEmpty else { return transcript }
        let pattern = "\\b(" + denylist.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return transcript
        }
        let ns = transcript as NSString
        let matches = regex.matches(in: transcript, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return transcript }

        var output = transcript
        // Replace in reverse so earlier ranges remain valid.
        for match in matches.reversed() {
            guard let range = Range(match.range, in: output) else { continue }
            let original = String(output[range])
            guard let first = original.first else { continue }
            let masked = String(first) + String(repeating: "*", count: original.count - 1)
            output.replaceSubrange(range, with: masked)
        }
        return output
    }
}
