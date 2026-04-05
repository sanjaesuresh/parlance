import Foundation

enum SpeechAnalyzer {

    struct FillerResult {
        let count: Int
        let score: Int
        let mostFrequent: String?
    }

    struct PaceResult {
        let score: Int
        let wpm: Int
        let tip: String
    }

    struct ClarityResult {
        let score: Int
        let tip: String
    }

    struct StructureResult {
        let score: Int
        let tip: String
    }

    struct VocabularyResult {
        let score: Int
        let tip: String
    }

    struct Metrics {
        let fillerScore: Int
        let fillerCount: Int
        let paceScore: Int
        let wpm: Int
        let clarityScore: Int
        let structureScore: Int
        let vocabularyScore: Int

        var overallScore: Int {
            let mean = Double(fillerScore + paceScore + clarityScore + structureScore + vocabularyScore) / 5.0
            return Int((mean * 10).rounded())
        }
    }

    struct Moments {
        let bestTimestamp: TimeInterval
        let bestText: String
        let worstTimestamp: TimeInterval
        let worstText: String
    }

    // MARK: - Filler Words

    private static let fillerPatterns: [(pattern: String, label: String)] = [
        ("\\byou know\\b", "you know"),
        ("\\bsort of\\b", "sort of"),
        ("\\bkind of\\b", "kind of"),
        ("\\bbasically\\b", "basically"),
        ("\\bliterally\\b", "literally"),
        ("\\b(?:um|umm)\\b", "um"),
        ("\\b(?:uh|uhh)\\b", "uh"),
        ("\\blike\\b", "like")
    ]

    static func analyzeFillers(in text: String) -> FillerResult {
        let lower = text.lowercased()
        var totalCount = 0
        var frequency: [String: Int] = [:]

        for (pattern, label) in fillerPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let matches = regex?.numberOfMatches(in: lower, range: NSRange(lower.startIndex..., in: lower)) ?? 0
            totalCount += matches
            if matches > 0 {
                frequency[label, default: 0] += matches
            }
        }

        let score = max(0, 10 - totalCount)
        let mostFrequent = frequency.max(by: { $0.value < $1.value })?.key
        return FillerResult(count: totalCount, score: score, mostFrequent: mostFrequent)
    }

    // MARK: - Pace

    static func analyzePace(wordCount: Int, duration: TimeInterval) -> PaceResult {
        guard duration > 0 else { return PaceResult(score: 0, wpm: 0, tip: "No recording detected.") }
        let wpm = Int(Double(wordCount) / (duration / 60.0))
        let score: Int
        let tip: String

        switch wpm {
        case 130...160:
            score = 10
            tip = "Great pace — natural and easy to follow."
        case 110..<130:
            score = 7
            tip = "Slightly slow — increase energy and vary your pace."
        case 161...185:
            score = 7
            tip = "Slightly fast — slow down and let your points land."
        case ..<110:
            score = 4
            tip = "Too slow — increase energy and vary your pace."
        default:
            score = 4
            tip = "Too fast — slow down and breathe between points."
        }

        return PaceResult(score: score, wpm: wpm, tip: tip)
    }

    // MARK: - Clarity

    static func analyzeClarity(in text: String) -> ClarityResult {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var longPenalty = 0
        var fragmentPenalty: Double = 0

        for sentence in sentences {
            let wordCount = sentence.split(separator: " ").count
            if wordCount > 25 { longPenalty += 1 }
            if wordCount < 5 { fragmentPenalty += 0.5 }
        }

        let score = max(0, 10 - longPenalty - Int(fragmentPenalty))
        let tip: String
        if longPenalty > Int(fragmentPenalty) {
            tip = "Your sentences are running long — aim for under 20 words per idea."
        } else if fragmentPenalty > 0 {
            tip = "Some of your responses were cut short — try developing each point fully."
        } else {
            tip = "Clear and well-paced sentences — easy to follow."
        }

        return ClarityResult(score: score, tip: tip)
    }

    // MARK: - Structure

    private static let openingSignals = [
        "the key thing", "what i'd say", "to answer that", "let me start",
        "the short answer", "first and foremost", "to begin"
    ]

    private static let closingSignals = [
        "so in summary", "the bottom line", "to wrap up", "in conclusion",
        "overall", "to summarize", "the takeaway"
    ]

    private static let starPatterns: [String: [String]] = [
        "situation": ["when i", "at my previous", "in that role", "at my company", "at the time"],
        "task": ["i was responsible for", "my goal was", "i needed to", "i had to"],
        "action": ["i decided", "i then", "what i did", "i reached out", "i built", "i led"],
        "result": ["as a result", "this led to", "the outcome was", "we achieved", "it resulted in", "by the end"]
    ]

    static func analyzeStructure(in text: String, mode: SessionMode) -> StructureResult {
        let lower = text.lowercased()
        var score = 10

        let hasOpening = openingSignals.contains { lower.contains($0) }
        let hasClosing = closingSignals.contains { lower.contains($0) }

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bodyWords = sentences.dropFirst().joined(separator: " ").split(separator: " ").count
        let hasMidBody = bodyWords >= 30

        if !hasOpening { score -= 3 }
        if !hasClosing { score -= 3 }
        if !hasMidBody { score -= 2 }

        if mode == .interview {
            var starComponents = 0
            for (_, signals) in starPatterns {
                if signals.contains(where: { lower.contains($0) }) {
                    starComponents += 1
                }
            }
            if starComponents == 4 {
                score += 1
            }
        }

        score = min(10, max(0, score))

        var tip = ""
        if !hasOpening { tip = "Start with a clear framing statement to orient your listener." }
        else if !hasClosing { tip = "Wrap up with a summary — leave them with a clear takeaway." }
        else if !hasMidBody { tip = "Develop your middle section more — add examples or detail." }
        else { tip = "Well-structured response with a clear beginning, middle, and end." }

        return StructureResult(score: score, tip: tip)
    }

    // MARK: - Vocabulary Strength

    private static let weakWords: Set<String> = [
        "stuff", "things", "whatever", "kind of", "sort of", "a lot",
        "very", "really", "basically", "just", "good", "bad", "big", "nice",
        "get", "got", "thing"
    ]

    private static let strongVerbs: Set<String> = [
        "built", "launched", "reduced", "increased", "negotiated", "convinced",
        "designed", "led", "delivered", "solved", "implemented", "grew", "cut",
        "pitched", "drove"
    ]

    private static let genericVerbs: Set<String> = [
        "did", "made", "got", "went", "had", "was", "said"
    ]

    static func analyzeVocabulary(in text: String) -> VocabularyResult {
        let lower = text.lowercased()
        let words = lower.split(separator: " ").map(String.init)
        let totalWords = words.count
        guard totalWords > 0 else {
            return VocabularyResult(score: 0, tip: "No words detected.")
        }

        var score = 7

        let strongCount = words.filter { strongVerbs.contains($0) }.count
        let allVerbCount = words.filter { strongVerbs.contains($0) || genericVerbs.contains($0) }.count
        if allVerbCount > 0 && Double(strongCount) / Double(allVerbCount) > 0.15 {
            score += 1
        }

        let uniqueWords = Set(words)
        let ttr = Double(uniqueWords.count) / Double(totalWords)
        if ttr > 0.60 {
            score += 1
        }

        var uniqueWeakWordsUsed = 0
        for weak in weakWords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: weak))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                uniqueWeakWordsUsed += 1
            }
        }

        if uniqueWeakWordsUsed == 0 {
            score += 1
        }
        score -= min(4, uniqueWeakWordsUsed)

        let contentWords = words.filter { $0.count > 3 }
        let contentFreq = Dictionary(grouping: contentWords, by: { $0 }).mapValues(\.count)
        if contentFreq.values.contains(where: { $0 > 3 }) {
            score -= 1
        }

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let passiveCount = sentences.filter { sentence in
            let s = sentence.lowercased()
            return s.contains("was ") || s.contains("were ")
        }.count
        if sentences.count > 0 && Double(passiveCount) / Double(sentences.count) > 0.25 {
            score -= 1
        }

        score = min(10, max(0, score))

        let tip: String
        if uniqueWeakWordsUsed > 2 {
            tip = "Replace vague words like 'things' and 'stuff' with specific nouns."
        } else if strongCount == 0 {
            tip = "Use stronger action verbs — 'drove' instead of 'did', 'built' instead of 'made'."
        } else if ttr <= 0.60 {
            tip = "Vary your word choice — you're reusing the same terms frequently."
        } else {
            tip = "Strong vocabulary — specific and varied word choices."
        }

        return VocabularyResult(score: score, tip: tip)
    }

    // MARK: - Full Analysis

    static func analyze(transcript: String, duration: TimeInterval, mode: SessionMode) -> Metrics {
        let wordCount = transcript.split(separator: " ").count
        let filler = analyzeFillers(in: transcript)
        let pace = analyzePace(wordCount: wordCount, duration: duration)
        let clarity = analyzeClarity(in: transcript)
        let structure = analyzeStructure(in: transcript, mode: mode)
        let vocabulary = analyzeVocabulary(in: transcript)

        return Metrics(
            fillerScore: filler.score, fillerCount: filler.count,
            paceScore: pace.score, wpm: pace.wpm,
            clarityScore: clarity.score,
            structureScore: structure.score,
            vocabularyScore: vocabulary.score
        )
    }

    // MARK: - Best/Worst Moments

    static func detectMoments(in text: String, duration: TimeInterval) -> Moments {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty, duration > 0 else {
            return Moments(bestTimestamp: 0, bestText: "", worstTimestamp: 0, worstText: "")
        }

        let wordsPerSecond = Double(words.count) / duration
        let segmentDuration: TimeInterval = 10
        let segmentWordCount = max(1, Int(wordsPerSecond * segmentDuration))

        var segments: [(timestamp: TimeInterval, text: String)] = []
        var index = 0
        var segmentIndex = 0

        while index < words.count {
            let end = min(index + segmentWordCount, words.count)
            let segmentWords = words[index..<end]
            let segmentText = segmentWords.joined(separator: " ")
            let timestamp = Double(segmentIndex) * segmentDuration
            segments.append((timestamp, segmentText))
            index = end
            segmentIndex += 1
        }

        if duration < 20 || segments.count < 2 {
            let best = segments.first ?? (0, "")
            return Moments(bestTimestamp: best.timestamp, bestText: best.text, worstTimestamp: 0, worstText: "")
        }

        var bestScore = Int.min
        var worstScore = Int.max
        var bestSeg = segments[0]
        var worstSeg = segments[0]

        for seg in segments {
            let lower = seg.text.lowercased()
            let segWords = lower.split(separator: " ").map(String.init)
            let strongCount = segWords.filter { strongVerbs.contains($0) }.count
            let fillerResult = analyzeFillers(in: seg.text)
            let score = strongCount - fillerResult.count

            if score > bestScore {
                bestScore = score
                bestSeg = seg
            }
            if score < worstScore {
                worstScore = score
                worstSeg = seg
            }
        }

        return Moments(
            bestTimestamp: bestSeg.timestamp, bestText: bestSeg.text,
            worstTimestamp: worstSeg.timestamp, worstText: worstSeg.text
        )
    }
}
