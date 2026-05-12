import Foundation

/// Conservative pre-flight denylist for Real Life scenarios. Catches only
/// clear-cut abuse categories (named-target violence, sexualizing minors,
/// unambiguous slurs). The gray-zone scenarios (death, breakup, conflict,
/// firing, addiction, coming out, religion, politics) are explicitly
/// supported and must NOT match.
enum RealLifeContentDenylist {

    /// Returns true if the scenario contains denylisted content and should
    /// be hard-gated client-side before reaching the LLM.
    nonisolated static func matches(_ scenario: String) -> Bool {
        let text = scenario.lowercased()
        guard !text.isEmpty else { return false }
        return patterns.contains(where: { text.range(of: $0, options: .regularExpression) != nil })
    }

    /// Patterns are lowercase-anchored regex strings. Keep this list small
    /// and conservative — extending it to "edgy" or "uncomfortable" content
    /// defeats the purpose of the Real Life mode.
    nonisolated private static let patterns: [String] = [
        // Named-target violence: kill/murder/harm + a proper-name pattern
        #"\b(kill|murder|shoot|stab|attack|harm)\s+[a-z]+\s+[a-z]+\b"#,

        // Sexualizing minors: child/minor/<age 4-17> + sexual context
        #"\b(child|minor|kid|teen|teenager)\b[^.]{0,40}\b(sexual|sex|naked|nude|aroused?)\b"#,
        #"\bsexual\b[^.]{0,40}\b(child|minor|kid|\d{1,2}\s*year\s*old)\b"#,
        #"\b\d{1,2}\s*(year\s*old|yo|y/?o)\b[^.]{0,30}\b(sexual|sex|nude|naked)\b"#,

        // ---------------------------------------------------------------
        // SLURS — sealed list.
        //
        // Each entry below is an unambiguous slur with no legitimate
        // non-derogatory usage in modern English. Word-boundary anchored
        // so common words ("spice", "thinking", "Pakistan") do not
        // collide. Variant forms cover the most common 1337-substitutions
        // (0 for o, 1/! for i) but are not exhaustive — Claude's own
        // moderation handles bypasses.
        //
        // Do NOT extend this list to general profanity (fuck, shit,
        // damn, asshole) or to terms with legitimate non-derogatory
        // usage. The bar is: no reasonable speaker uses this word in a
        // non-attacking context.
        // ---------------------------------------------------------------
        #"\bn[i1!]gg(?:er|a)s?\b"#,           // racial slur, anti-Black
        #"\bfagg?(?:ot)?s?\b"#,                // anti-gay slur (fag + faggot)
        #"\btrann(?:y|ies)\b"#,                // anti-trans slur
        #"\bch[i1!]nks?\b"#,                   // anti-East-Asian racial slur
        #"\bsp[i1!]cs?\b"#,                    // anti-Latin racial slur
        #"\bk[i1!]kes?\b"#,                    // anti-Jewish slur
        #"\bret[a4]rd(?:ed|ing|s)?\b"#,        // ableist slur (incl. inflections)
    ]
}
