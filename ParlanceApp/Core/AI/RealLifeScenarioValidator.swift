import Foundation

/// Pre-flight check that the user's Real Life scenario is plausibly a
/// speaking situation (a conversation or speech they are about to deliver
/// to another human). Runs locally on Continue tap in the setup screen —
/// no network, no state. The companion server-side classifier in the
/// Cloudflare worker handles edge cases that slip past these rules.
enum RealLifeScenarioValidator {

    enum Failure: Equatable {
        case tooShort
        case mostlyNonLetters
        case askingTheAI
        case noSpeechActOrAudience
    }

    /// Returns nil if the scenario passes all rules, else the first rule
    /// that failed. Rules are checked in order; first failure wins.
    static func validate(_ scenario: String) -> Failure? {
        let trimmed = scenario.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rule 1a: absolute length floor (uses UTF-8 byte count so multi-byte
        // scalars like emoji count as "content" rather than deflating the length).
        if trimmed.utf8.count < 12 {
            return .tooShort
        }

        // Rule 2: letter ratio. Among non-space scalars, ≥ 60% must be letters.
        // Checked before the word-count gate so junk strings (emoji, digits,
        // symbols) are rejected as mostlyNonLetters rather than tooShort.
        let nonSpace = trimmed.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        guard !nonSpace.isEmpty else { return .tooShort }
        let letters = nonSpace.filter { CharacterSet.letters.contains($0) }
        if Double(letters.count) / Double(nonSpace.count) < 0.60 {
            return .mostlyNonLetters
        }

        // Rule 1b: word count floor (after letter ratio so symbol blobs don't
        // masquerade as tooShort).
        let wordCount = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount < 3 {
            return .tooShort
        }

        let lower = trimmed.lowercased()

        // Rule 3: "ask the AI" patterns. Any match → failure.
        if askingAIPatterns.contains(where: { lower.range(of: $0, options: .regularExpression) != nil }) {
            return .askingTheAI
        }

        // Rule 4: must match at least one speech-act OR one audience pattern.
        let hasSpeechAct = speechActPatterns.contains(where: { lower.range(of: $0, options: .regularExpression) != nil })
        let hasAudience  = audiencePatterns.contains(where: { lower.range(of: $0, options: .regularExpression) != nil })
        if !hasSpeechAct && !hasAudience {
            return .noSpeechActOrAudience
        }

        return nil
    }

    // MARK: - Patterns

    private static let askingAIPatterns: [String] = [
        #"^(write|give|make|generate|draft|create|compose|produce) (me|us|a|an|the)\b"#,
        #"^(tell|read) me (a|an|the) (joke|story|recipe|poem|fact|secret|riddle)\b"#,
        #"^(what|who|where|when|why|how) (is|are|was|were|do|does|did|can|could|should|would)\b"#,
        #"^(explain|describe|define|summari[sz]e) .{0,80}\b(to me|for me)\b"#,
        #"\bignore (previous|prior|the above|all) (instructions?|prompts?)\b"#,
        #"^(act as|pretend to be|you are now|roleplay as)\b"#,
    ]

    private static let speechActPatterns: [String] = [
        #"\bi('m| am| have| gotta| need to| want to| got to| am going to| about to)\b.{0,40}\b(tell|talk|ask|pitch|present|explain|convince|sell|break up|interview|negotiate|propose|deliver|give|speak|call|confront|apologi[sz]e|come out|fire|quit|resign)\b"#,
        #"^(telling|asking|pitching|presenting|explaining|convincing|interviewing|negotiating|proposing|delivering|giving|speaking|calling|confronting|apologi[sz]ing|firing|quitting|resigning|breaking up|coming out)\b"#,
        #"\bi (have|got) (a|an) (meeting|call|interview|presentation|date|talk|speech|toast|pitch|conversation|chat|one[- ]on[- ]one|stand[- ]?up|review)\b"#,
        #"\bi'm about to\b"#,
    ]

    private static let audiencePatterns: [String] = [
        #"\bmy (boss|manager|partner|wife|husband|girlfriend|boyfriend|mom|dad|parents?|kids?|team|landlord|coworkers?|colleagues?|client|customer|professor|teacher|doctor|therapist|friend|investors?|cofounder|employees?|interviewer|recruiter|audience|family|sister|brother|son|daughter|report|in[- ]laws?|fianc[ée]e?)\b"#,
        #"\bthe (team|investors?|board|audience|interviewer|client|panel|jury|class|crowd|press|committee|group|hiring manager)\b"#,
        #"\b(to|with|at) (a |an |the )?(meeting|interview|wedding|funeral|panel|conference|stand[- ]?up|standup|board|investor|client|customer|audience|crowd|class|reunion)\b"#,
    ]
}
