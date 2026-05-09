// Parlance/Core/Services/SpeechAnalyzer.swift
import Foundation

enum SpeechAnalyzer {

    struct FillerResult {
        let count: Int
        let mostFrequent: String?
    }

    private static let fillerPatterns: [(pattern: String, label: String)] = [
        ("\\b(?:um|umm|ummm)\\b", "um"),
        ("\\b(?:uh|uhh|uhhh)\\b", "uh"),
        ("\\b(?:er|err)\\b", "er"),
        ("\\b(?:ah|ahh)\\b", "ah"),
        ("\\b(?:hmm|hm|hmmm)\\b", "hmm"),
        ("\\byou know\\b", "you know"),
        ("\\bi mean\\b", "I mean"),
        ("\\blike\\b", "like"),
        ("\\bsort of\\b", "sort of"),
        ("\\bkind of\\b", "kind of"),
        ("\\bbasically\\b", "basically"),
        ("\\bliterally\\b", "literally"),
        ("\\bactually\\b", "actually"),
        ("\\bhonestly\\b", "honestly"),
        ("\\bobviously\\b", "obviously"),
        ("\\byou see\\b", "you see"),
        ("\\bthe thing is\\b", "the thing is"),
        ("\\bto be honest\\b", "to be honest"),
        ("\\bi guess\\b", "I guess")
    ]

    // Compiled once at first use; NSRegularExpression is thread-safe after init.
    private static let compiledRegexes: [(regex: NSRegularExpression, label: String)] = {
        fillerPatterns.compactMap { (pattern, label) in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (regex, label)
        }
    }()

    /// Returns character ranges of filler words in the original text.
    /// Used by the transcript UI to highlight fillers inline.
    static func fillerRanges(in text: String) -> [Range<String.Index>] {
        let lower = text.lowercased()
        var ranges: [Range<String.Index>] = []
        let nsRange = NSRange(lower.startIndex..., in: lower)
        for (regex, _) in compiledRegexes {
            regex.enumerateMatches(in: lower, range: nsRange) { match, _, _ in
                guard let m = match, let r = Range(m.range, in: text) else { return }
                ranges.append(r)
            }
        }
        ranges.sort { $0.lowerBound < $1.lowerBound }
        return ranges
    }

    /// Counts filler words for display in the transcript card header.
    static func analyzeFillers(in text: String) -> FillerResult {
        let lower = text.lowercased()
        let nsRange = NSRange(lower.startIndex..., in: lower)
        var totalCount = 0
        var frequency: [String: Int] = [:]

        for (regex, label) in compiledRegexes {
            let matches = regex.numberOfMatches(in: lower, range: nsRange)
            totalCount += matches
            if matches > 0 { frequency[label, default: 0] += matches }
        }

        let mostFrequent = frequency.max(by: { $0.value < $1.value })?.key
        return FillerResult(count: totalCount, mostFrequent: mostFrequent)
    }
}
