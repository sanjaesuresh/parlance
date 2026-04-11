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
        let substanceScore: Int
        let wordCount: Int

        /// Overall score (0-100) — independent holistic grade, NOT just the breakdown mean.
        /// Substance anchors the score: you can't score well without actually saying something.
        var overallScore: Int {
            // Substance acts as a ceiling — if you said nothing meaningful, max ~30
            let breakdownMean = Double(fillerScore + paceScore + clarityScore + structureScore + vocabularyScore) / 5.0
            let substanceFraction = Double(substanceScore) / 10.0

            // Weighted: 40% substance, 60% breakdown metrics
            // This means gibberish (substance 1/10) caps you around 25 even if breakdown is perfect
            let raw = (substanceFraction * 0.4 + (breakdownMean / 10.0) * 0.6) * 100.0

            // Apply word count floor: under 20 words is always a poor answer
            let wordFloor: Double = wordCount < 20 ? 0.3 : wordCount < 40 ? 0.6 : 1.0
            let adjusted = raw * wordFloor

            return min(100, max(0, Int(adjusted.rounded())))
        }
    }

    struct Moments {
        let bestTimestamp: TimeInterval
        let bestText: String
        let worstTimestamp: TimeInterval
        let worstText: String
    }

    // MARK: - Content Substance

    /// Measures whether the speaker actually said something meaningful.
    /// Detects: sufficient length, idea development, non-repetitive content, real sentences.
    static func analyzeSubstance(in text: String, duration: TimeInterval) -> Int {
        let words = text.lowercased().split(separator: " ").map(String.init)
        let totalWords = words.count

        guard totalWords > 0 else { return 0 }

        var score: Double = 0

        // 1. Word count relative to duration (did they actually speak enough?)
        let expectedMinWords = max(10, Int(duration * 1.5)) // ~90 wpm minimum effort
        let wordRatio = Double(totalWords) / Double(expectedMinWords)
        if wordRatio >= 1.0 {
            score += 3.0
        } else if wordRatio >= 0.5 {
            score += 1.5
        } else {
            score += 0.5 // Said almost nothing
        }

        // 2. Lexical diversity — unique content words (>3 letters) vs total
        let contentWords = words.filter { $0.count > 3 }
        let uniqueContent = Set(contentWords)
        if contentWords.count > 5 {
            let diversity = Double(uniqueContent.count) / Double(contentWords.count)
            if diversity > 0.55 { score += 2.0 }
            else if diversity > 0.35 { score += 1.0 }
            // Below 0.35 = extreme repetition, no points
        }

        // 3. Repetition detection — any single word repeated excessively?
        let wordFreq = Dictionary(grouping: contentWords, by: { $0 }).mapValues(\.count)
        let maxRepeat = wordFreq.values.max() ?? 0
        let repeatRatio = contentWords.isEmpty ? 0 : Double(maxRepeat) / Double(contentWords.count)
        if repeatRatio < 0.15 {
            score += 1.5 // No dominant repeated word
        } else if repeatRatio < 0.25 {
            score += 0.5
        }
        // else: one word dominates = no points

        // 4. Sentence development — are there real, developed sentences?
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let developedSentences = sentences.filter { $0.split(separator: " ").count >= 8 }
        if developedSentences.count >= 3 {
            score += 2.0
        } else if developedSentences.count >= 1 {
            score += 1.0
        }

        // 5. Contains actual ideas — presence of connectives, reasoning words, specifics
        let ideaSignals = [
            "because", "therefore", "however", "for example", "specifically",
            "in my experience", "the reason", "what i mean", "which means",
            "first", "second", "finally", "additionally", "importantly",
            "i believe", "i think", "my approach", "the key", "the main"
        ]
        let lower = text.lowercased()
        let ideaCount = ideaSignals.filter { lower.contains($0) }.count
        if ideaCount >= 3 {
            score += 1.5
        } else if ideaCount >= 1 {
            score += 0.5
        }

        return min(10, max(0, Int(score.rounded())))
    }

    // MARK: - Filler Words

    private static let fillerPatterns: [(pattern: String, label: String)] = [
        // Classic hesitation fillers
        ("\\b(?:um|umm|ummm)\\b", "um"),
        ("\\b(?:uh|uhh|uhhh)\\b", "uh"),
        ("\\b(?:er|err)\\b", "er"),
        ("\\b(?:ah|ahh)\\b", "ah"),
        ("\\b(?:hmm|hm|hmmm)\\b", "hmm"),
        // Discourse markers used as fillers
        ("\\byou know\\b", "you know"),
        ("\\bi mean\\b", "I mean"),
        ("\\blike\\b", "like"),
        ("\\bso\\b(?=\\s+(?:um|uh|like|yeah|basically|anyway))", "so"),
        ("\\bright\\b(?=\\s*[,?])", "right"),
        ("\\bokay so\\b", "okay so"),
        // Hedge words
        ("\\bsort of\\b", "sort of"),
        ("\\bkind of\\b", "kind of"),
        ("\\bbasically\\b", "basically"),
        ("\\bliterally\\b", "literally"),
        ("\\bactually\\b", "actually"),
        ("\\bhonestly\\b", "honestly"),
        ("\\bobviously\\b", "obviously"),
        // Stalling phrases
        ("\\byou see\\b", "you see"),
        ("\\bthe thing is\\b", "the thing is"),
        ("\\bat the end of the day\\b", "at the end of the day"),
        ("\\bif you will\\b", "if you will"),
        ("\\bif that makes sense\\b", "if that makes sense"),
        ("\\bto be honest\\b", "to be honest"),
        ("\\bi guess\\b", "I guess")
    ]

    /// Returns the character ranges (in the ORIGINAL text) matched by any filler pattern.
    /// Used by UI to highlight fillers inline within the transcript. Ranges may overlap; callers should dedupe/sort.
    static func fillerRanges(in text: String) -> [Range<String.Index>] {
        let lower = text.lowercased()
        var ranges: [Range<String.Index>] = []
        for (pattern, _) in fillerPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(lower.startIndex..., in: lower)
            regex.enumerateMatches(in: lower, range: nsRange) { match, _, _ in
                guard let m = match, let r = Range(m.range, in: text) else { return }
                ranges.append(r)
            }
        }
        // Sort by lower bound, then dedupe exact duplicates.
        ranges.sort { $0.lowerBound < $1.lowerBound }
        return ranges
    }

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

        // Scale penalty by word count — 2 fillers in 20 words is worse than 2 in 200
        let wordCount = text.split(separator: " ").count
        let fillerRate = wordCount > 0 ? Double(totalCount) / Double(wordCount) : 0

        let score: Int
        if wordCount < 10 {
            // Too few words to judge fillers meaningfully
            score = totalCount == 0 ? 5 : max(0, 5 - totalCount)
        } else if fillerRate < 0.02 {
            score = 10 // Under 2% filler rate = excellent
        } else if fillerRate < 0.04 {
            score = 8
        } else if fillerRate < 0.07 {
            score = 6
        } else if fillerRate < 0.10 {
            score = 4
        } else {
            score = max(0, 2 - Int((fillerRate - 0.10) * 20))
        }

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
        case 120..<130:
            score = 8
            tip = "Slightly slow — increase energy a touch."
        case 161...175:
            score = 8
            tip = "Slightly fast — breathe between key points."
        case 100..<120:
            score = 6
            tip = "Slow — pick up the energy and vary your pace."
        case 176...200:
            score = 6
            tip = "Fast — slow down so your points land."
        case ..<100:
            // Very few words relative to time = barely spoke
            score = wordCount < 20 ? 2 : 4
            tip = wordCount < 20 ? "You barely spoke — try to develop your answer more." : "Too slow — increase energy and vary your pace."
        default:
            score = 3
            tip = "Way too fast — slow down and breathe between points."
        }

        return PaceResult(score: score, wpm: wpm, tip: tip)
    }

    // MARK: - Clarity

    static func analyzeClarity(in text: String) -> ClarityResult {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let wordCount = text.split(separator: " ").count

        // If barely any words, clarity is inherently low
        guard wordCount >= 10 else {
            return ClarityResult(score: 2, tip: "Your answer was too short to evaluate clearly — develop your ideas more.")
        }

        var longPenalty = 0
        var fragmentPenalty: Double = 0

        for sentence in sentences {
            let sentenceWordCount = sentence.split(separator: " ").count
            if sentenceWordCount > 25 { longPenalty += 1 }
            if sentenceWordCount < 5 { fragmentPenalty += 0.5 }
        }

        // Penalty for no real sentence structure (just a blob of words)
        if sentences.count <= 1 && wordCount > 15 {
            longPenalty += 2 // One giant run-on
        }

        let score = max(0, 10 - longPenalty - Int(fragmentPenalty))
        let tip: String
        if sentences.count <= 1 && wordCount > 15 {
            tip = "Your response was one long run-on — break it into distinct points."
        } else if longPenalty > Int(fragmentPenalty) {
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
        "the short answer", "first and foremost", "to begin", "i think",
        "in my experience", "the way i see it", "my take on this",
        "to put it simply", "the most important"
    ]

    private static let closingSignals = [
        "so in summary", "the bottom line", "to wrap up", "in conclusion",
        "overall", "to summarize", "the takeaway", "so ultimately",
        "at the end of the day", "the key point is", "what this means is"
    ]

    private static let starPatterns: [String: [String]] = [
        "situation": ["when i", "at my previous", "in that role", "at my company", "at the time"],
        "task": ["i was responsible for", "my goal was", "i needed to", "i had to"],
        "action": ["i decided", "i then", "what i did", "i reached out", "i built", "i led"],
        "result": ["as a result", "this led to", "the outcome was", "we achieved", "it resulted in", "by the end"]
    ]

    static func analyzeStructure(in text: String, mode: SessionMode) -> StructureResult {
        let lower = text.lowercased()
        let wordCount = text.split(separator: " ").count

        // Minimum content gate
        guard wordCount >= 15 else {
            return StructureResult(score: 2, tip: "Your answer was too short to have meaningful structure — aim for at least 30 seconds of speaking.")
        }

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

        // Bonus for having multiple distinct points
        let transitionWords = ["first", "second", "additionally", "also", "another", "furthermore", "moreover", "next", "finally"]
        let transitions = transitionWords.filter { lower.contains($0) }.count
        if transitions >= 2 { score += 1 }

        if mode == .interview {
            var starComponents = 0
            for (_, signals) in starPatterns {
                if signals.contains(where: { lower.contains($0) }) {
                    starComponents += 1
                }
            }
            if starComponents == 4 { score += 1 }
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
        "pitched", "drove", "managed", "achieved", "developed", "created",
        "transformed", "streamlined", "optimized", "facilitated", "spearheaded",
        "coordinated", "established", "demonstrated", "analyzed", "improved"
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

        // Minimum content gate — can't score well on vocab with <15 words
        guard totalWords >= 15 else {
            return VocabularyResult(score: 2, tip: "Your answer was too short to demonstrate vocabulary range — try to develop your response.")
        }

        // Start at 5 (neutral) and earn/lose from there
        var score = 5

        // Strong verbs present (+2 max)
        let strongCount = words.filter { strongVerbs.contains($0) }.count
        if strongCount >= 3 { score += 2 }
        else if strongCount >= 1 { score += 1 }

        // Lexical diversity (+2 max)
        let uniqueWords = Set(words)
        let ttr = Double(uniqueWords.count) / Double(totalWords)
        if ttr > 0.60 { score += 2 }
        else if ttr > 0.45 { score += 1 }
        else if ttr < 0.30 { score -= 1 } // Very repetitive

        // Weak words penalty (-2 max)
        var uniqueWeakWordsUsed = 0
        for weak in weakWords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: weak))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                uniqueWeakWordsUsed += 1
            }
        }
        score -= min(2, uniqueWeakWordsUsed / 2)

        // Specificity bonus — presence of numbers, proper nouns, or concrete details (+1)
        let hasNumbers = text.range(of: "\\d+", options: .regularExpression) != nil
        let hasSpecifics = ["percent", "million", "team of", "within", "across", "over the past"].contains(where: { lower.contains($0) })
        if hasNumbers || hasSpecifics { score += 1 }

        // Excessive repetition penalty
        let contentWords = words.filter { $0.count > 3 }
        let contentFreq = Dictionary(grouping: contentWords, by: { $0 }).mapValues(\.count)
        if contentFreq.values.contains(where: { $0 > 4 }) {
            score -= 1
        }

        score = min(10, max(0, score))

        let tip: String
        if totalWords < 30 {
            tip = "Say more — it's hard to demonstrate vocabulary range in a very short answer."
        } else if uniqueWeakWordsUsed > 2 {
            tip = "Replace vague words like 'things' and 'stuff' with specific nouns."
        } else if strongCount == 0 {
            tip = "Use stronger action verbs — 'drove' instead of 'did', 'built' instead of 'made'."
        } else if ttr <= 0.45 {
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
        let substance = analyzeSubstance(in: transcript, duration: duration)

        return Metrics(
            fillerScore: filler.score, fillerCount: filler.count,
            paceScore: pace.score, wpm: pace.wpm,
            clarityScore: clarity.score,
            structureScore: structure.score,
            vocabularyScore: vocabulary.score,
            substanceScore: substance,
            wordCount: wordCount
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
