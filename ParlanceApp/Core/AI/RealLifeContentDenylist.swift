import Foundation

/// Conservative pre-flight denylist for Real Life scenarios. Catches only
/// clear-cut abuse categories (named-target violence, sexualizing minors,
/// unambiguous slurs). The gray-zone scenarios (death, breakup, conflict,
/// firing, addiction, coming out, religion, politics) are explicitly
/// supported and must NOT match.
enum RealLifeContentDenylist {

    /// Returns true if the scenario contains denylisted content and should
    /// be hard-gated client-side before reaching the LLM.
    static func matches(_ scenario: String) -> Bool {
        let text = scenario.lowercased()
        guard !text.isEmpty else { return false }
        return patterns.contains(where: { text.range(of: $0, options: .regularExpression) != nil })
    }

    /// Patterns are lowercase-anchored regex strings. Keep this list small
    /// and conservative — extending it to "edgy" or "uncomfortable" content
    /// defeats the purpose of the Real Life mode.
    private static let patterns: [String] = [
        // Named-target violence: kill/murder/harm + a proper-name pattern
        #"\b(kill|murder|shoot|stab|attack|harm)\s+[a-z]+\s+[a-z]+\b"#,

        // Sexualizing minors: child/minor/<age 4-17> + sexual context
        #"\b(child|minor|kid|teen|teenager)\b[^.]{0,40}\b(sexual|sex|naked|nude|aroused?)\b"#,
        #"\bsexual\b[^.]{0,40}\b(child|minor|kid|\d{1,2}\s*year\s*old)\b"#,
        #"\b\d{1,2}\s*(year\s*old|yo|y/?o)\b[^.]{0,30}\b(sexual|sex|nude|naked)\b"#,

        // Slurs — leave this list deliberately empty here and populate via
        // a sealed internal helper in a follow-up PR. We do not want
        // canonical slurs checked into the public planning doc.
    ]
}
