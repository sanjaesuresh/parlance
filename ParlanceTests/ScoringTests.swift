// ParlanceTests/ScoringTests.swift
import Testing
import Foundation
import SwiftData
@testable import Parlance

// MARK: - Helpers

private func makeScoringResult(
    metrics: [String: MetricScore] = ["clarity": MetricScore(score: 7, tip: "Be concise")],
    overallScore: Int = 72,
    feedback: String? = "Strong session.",
    bestQuote: String = "strong opening",
    worstQuote: String = "rambled at end"
) -> ScoringResult {
    ScoringResult(
        metrics: metrics,
        overallScore: overallScore,
        feedback: feedback,
        bestMoment: ScoringMoment(quote: bestQuote, reason: "Clear and direct"),
        worstMoment: ScoringMoment(quote: worstQuote, reason: "Lost structure"),
        relevanceToPrompt: nil
    )
}

private func makeSessionContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Session.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

// MARK: - Session.isAIScored

@Suite("Session.isAIScored")
struct SessionIsAIScoredTests {

    // Bug 2 fix: isAIScored should be false when metrics dict is empty,
    // not just when metricScoresData is nil.

    @Test("legacy session with nil metricScoresData returns false")
    func legacySession_isNotAIScored() throws {
        let container = try makeSessionContainer()
        let context = ModelContext(container)

        let session = Session(
            mode: .interview, difficultyLevel: 1, duration: 60,
            transcript: "Hello world", overallScore: 75, fillerCount: 0,
            paceScore: 7, clarityScore: 8, structureScore: 7, vocabularyScore: 6,
            question: "Test?", xpEarned: 100, wasDailyChallenge: false
        )
        context.insert(session)

        #expect(!session.isAIScored)
    }

    @Test("zero-fallback session (empty metrics dict) returns false")
    func zeroFallback_isNotAIScored() throws {
        let container = try makeSessionContainer()
        let context = ModelContext(container)

        let zeroed = ScoringResult(
            metrics: [:],
            overallScore: 0,
            feedback: nil,
            bestMoment: ScoringMoment(quote: "", reason: ""),
            worstMoment: ScoringMoment(quote: "", reason: ""),
            relevanceToPrompt: nil
        )
        let session = Session(
            mode: .interview, difficultyLevel: 1, duration: 30,
            transcript: "Hi", fillerCount: 0, question: "Test?",
            scoringResult: zeroed, xpEarned: 50, wasDailyChallenge: false
        )
        context.insert(session)

        // Before the fix, metricScoresData was non-nil (encoded `{}`)
        // so isAIScored incorrectly returned true. It should return false.
        #expect(!session.isAIScored)
    }

    @Test("session with real AI metrics returns true")
    func realMetrics_isAIScored() throws {
        let container = try makeSessionContainer()
        let context = ModelContext(container)

        let session = Session(
            mode: .interview, difficultyLevel: 3, duration: 90,
            transcript: "I led a team through a difficult migration.",
            fillerCount: 1, question: "Describe a challenge.",
            scoringResult: makeScoringResult(), xpEarned: 150, wasDailyChallenge: false
        )
        context.insert(session)

        #expect(session.isAIScored)
    }

    @Test("AI moments are stored and readable after session init")
    func aiMoments_storedCorrectly() throws {
        let container = try makeSessionContainer()
        let context = ModelContext(container)

        let result = makeScoringResult(bestQuote: "nailed the hook", worstQuote: "rushed conclusion")
        let session = Session(
            mode: .keynote, difficultyLevel: 5, duration: 120,
            transcript: "Today I want to talk about leadership.",
            fillerCount: 2, question: "Tell me about leadership.",
            scoringResult: result, xpEarned: 200, wasDailyChallenge: false
        )
        context.insert(session)

        #expect(session.bestMomentQuote == "nailed the hook")
        #expect(session.worstMomentQuote == "rushed conclusion")
        #expect(session.overallScore == 72)
    }
}

// MARK: - ScoringResult JSON decoding

@MainActor
@Suite("ScoringResult JSON decoding")
struct ScoringResultDecodingTests {

    // These tests catch the silent parse failure that causes 0% scores.
    // If Claude's response format changes or the worker wraps the output,
    // these tests will fail and tell you why.

    private func decode(_ json: String) throws -> ScoringResult {
        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(ScoringResult.self, from: data)
    }

    @Test("decodes complete valid JSON from Claude")
    func decodes_fullResponse() throws {
        let json = """
        {
          "metrics": {
            "clarity": { "score": 7, "tip": "Be more concise" },
            "pace":    { "score": 8, "tip": "Good rhythm overall" }
          },
          "overallScore": 72,
          "feedback": "Strong session. Work on your opening.",
          "bestMoment":  { "quote": "strong opening", "reason": "Clear and direct" },
          "worstMoment": { "quote": "rambled at end", "reason": "Lost structure" }
        }
        """
        let result = try decode(json)

        #expect(result.overallScore == 72)
        #expect(result.metrics["clarity"]?.score == 7)
        #expect(result.metrics["pace"]?.score == 8)
        #expect(result.feedback == "Strong session. Work on your opening.")
        #expect(result.bestMoment.quote == "strong opening")
        #expect(result.worstMoment.quote == "rambled at end")
    }

    @Test("decodes when feedback is null — Claude sometimes omits it")
    func decodes_nullFeedback() throws {
        let json = """
        {
          "metrics": { "clarity": { "score": 6, "tip": "Slow down" } },
          "overallScore": 60,
          "feedback": null,
          "bestMoment":  { "quote": "good point", "reason": "Clear" },
          "worstMoment": { "quote": "um anyway",  "reason": "Filler" }
        }
        """
        let result = try decode(json)

        #expect(result.overallScore == 60)
        #expect(result.feedback == nil)
    }

    @Test("decodes when feedback field is absent")
    func decodes_missingFeedback() throws {
        let json = """
        {
          "metrics": { "pace": { "score": 5, "tip": "Vary your speed" } },
          "overallScore": 55,
          "bestMoment":  { "quote": "clear intro", "reason": "Hooked listener" },
          "worstMoment": { "quote": "flat ending",  "reason": "No call to action" }
        }
        """
        let result = try decode(json)

        #expect(result.overallScore == 55)
        #expect(result.feedback == nil)
    }

    @Test("FeedbackClient wrapped-decode path works — worker may envelope JSON in feedback key")
    func decodes_wrappedWorkerEnvelope() throws {
        let inner = """
        {"metrics":{"clarity":{"score":7,"tip":"Clear"}},"overallScore":68,"feedback":null,"bestMoment":{"quote":"great hook","reason":"Direct"},"worstMoment":{"quote":"lost track","reason":"Structure"}}
        """
        // This is the format: { "feedback": "<json string>" }
        let wrappedJSON = try JSONSerialization.data(withJSONObject: ["feedback": inner])

        struct Wrapped: Decodable { let feedback: String }
        let wrapped = try JSONDecoder().decode(Wrapped.self, from: wrappedJSON)
        let innerData = try #require(wrapped.feedback.data(using: .utf8))
        let result = try JSONDecoder().decode(ScoringResult.self, from: innerData)

        #expect(result.overallScore == 68)
        #expect(result.metrics["clarity"]?.score == 7)
    }

    @Test("metrics with all-zero scores still decodes — preserves data integrity")
    func decodes_allZeroScores() throws {
        let json = """
        {
          "metrics": { "clarity": { "score": 0, "tip": "No transcript" } },
          "overallScore": 0,
          "feedback": "No speech detected.",
          "bestMoment":  { "quote": "", "reason": "" },
          "worstMoment": { "quote": "", "reason": "" }
        }
        """
        let result = try decode(json)

        #expect(result.overallScore == 0)
        #expect(result.metrics["clarity"]?.score == 0)
        #expect(result.bestMoment.quote.isEmpty)
    }
}

// MARK: - TimingStats.compute

@Suite("TimingStats.compute")
struct TimingStatsTests {

    @Test("returns empty stats for no segments")
    func emptySegments_returnsEmpty() {
        let stats = TimingStats.compute(from: [], totalDuration: 60)
        #expect(stats.wordCount == 0)
        #expect(stats.speechToSilenceRatio == 0)
        #expect(stats.longestPauseDuration == 0)
    }

    @Test("returns empty stats for zero duration")
    func zeroDuration_returnsEmpty() {
        let segments = [WordSegment(word: "hello", timestamp: 0, duration: 0.3)]
        let stats = TimingStats.compute(from: segments, totalDuration: 0)
        #expect(stats.wordCount == 0)
    }

    @Test("word count equals segment count")
    func wordCount_equalsSegmentCount() {
        let segments = [
            WordSegment(word: "I",      timestamp: 0.0, duration: 0.2),
            WordSegment(word: "led",    timestamp: 0.3, duration: 0.3),
            WordSegment(word: "a",      timestamp: 0.7, duration: 0.1),
            WordSegment(word: "team",   timestamp: 0.9, duration: 0.4),
        ]
        let stats = TimingStats.compute(from: segments, totalDuration: 5.0)
        #expect(stats.wordCount == 4)
    }

    @Test("speech ratio is capped at 1.0 when speech time exceeds duration")
    func speechRatio_cappedAtOne() {
        // Each word is 1s long, total = 3s, but totalDuration = 2s
        let segments = [
            WordSegment(word: "one",   timestamp: 0, duration: 1.0),
            WordSegment(word: "two",   timestamp: 1, duration: 1.0),
            WordSegment(word: "three", timestamp: 2, duration: 1.0),
        ]
        let stats = TimingStats.compute(from: segments, totalDuration: 2.0)
        #expect(stats.speechToSilenceRatio <= 1.0)
    }

    @Test("identifies longest pause and the word preceding it")
    func longestPause_identifiedCorrectly() {
        // Gap between "ready" and "set" = 0.5s; between "set" and "go" = 2.0s
        let segments = [
            WordSegment(word: "ready", timestamp: 0.0, duration: 0.3),
            WordSegment(word: "set",   timestamp: 0.8, duration: 0.3),  // gap: 0.5s
            WordSegment(word: "go",    timestamp: 3.1, duration: 0.2),  // gap: 2.0s
        ]
        let stats = TimingStats.compute(from: segments, totalDuration: 10.0)
        #expect(stats.longestPauseAfterWord == "set")
        #expect(stats.longestPauseDuration > 1.9)
    }
}

// MARK: - SpeechAnalyzer

@Suite("SpeechAnalyzer")
struct SpeechAnalyzerTests {

    @Test("counts filler words in typical speech")
    func countsFillers() {
        let transcript = "Um I think like we should basically um do this"
        let result = SpeechAnalyzer.analyzeFillers(in: transcript)
        // "um" x2, "like" x1, "basically" x1 = 4
        #expect(result.count == 4)
    }

    @Test("returns zero for clean speech with no fillers")
    func noFillers_returnsZero() {
        let transcript = "The quarterly results exceeded expectations across all regions."
        let result = SpeechAnalyzer.analyzeFillers(in: transcript)
        #expect(result.count == 0)
    }

    @Test("returns zero for empty string")
    func emptyString_returnsZero() {
        let result = SpeechAnalyzer.analyzeFillers(in: "")
        #expect(result.count == 0)
    }

    @Test("counts multiple distinct filler types correctly")
    func multipleFillerTypes_countedCorrectly() {
        let transcript = "um we uh should um try um this uh approach"
        // "um" x3, "uh" x2 = 5 total
        let result = SpeechAnalyzer.analyzeFillers(in: transcript)
        #expect(result.count == 5)
    }

    @Test("fillerRanges returns correct count for highlighting")
    func fillerRanges_countMatchesAnalysis() {
        let transcript = "I mean like this is uh important"
        let fillerResult = SpeechAnalyzer.analyzeFillers(in: transcript)
        let ranges = SpeechAnalyzer.fillerRanges(in: transcript)
        #expect(ranges.count == fillerResult.count)
    }

    @Test("fillerRanges are sorted by position in transcript")
    func fillerRanges_areSorted() {
        let transcript = "um hello uh world like this"
        let ranges = SpeechAnalyzer.fillerRanges(in: transcript)
        for i in 1..<ranges.count {
            #expect(ranges[i].lowerBound >= ranges[i-1].lowerBound)
        }
    }
}

// MARK: - FeedbackGenerator.buildPrompt

@Suite("FeedbackGenerator.buildPrompt")
struct FeedbackGeneratorPromptTests {

    @Test("prompt includes transcript when provided")
    func promptIncludesTranscript() {
        let transcript = "Leadership means owning outcomes."
        let prompt = FeedbackGenerator.buildPrompt(
            mode: .interview, level: 3, question: "What is leadership?",
            transcript: transcript, timingStats: .empty, audioFeatures: .empty
        )
        #expect(prompt.contains(transcript))
    }

    @Test("prompt shows no-transcript message when transcript is empty")
    func promptShowsFallback_whenTranscriptEmpty() {
        let prompt = FeedbackGenerator.buildPrompt(
            mode: .interview, level: 1, question: "Tell me about yourself.",
            transcript: "", timingStats: .empty, audioFeatures: .empty
        )
        #expect(prompt.contains("No transcript available"))
    }

    @Test("prompt includes word count from timing stats")
    func promptIncludesWordCount() {
        let timing = TimingStats(
            wordCount: 142,
            speechToSilenceRatio: 0.82,
            longestPauseDuration: 1.2,
            longestPauseAfterWord: "because",
            speakingRateStdDev: 3.1
        )
        let prompt = FeedbackGenerator.buildPrompt(
            mode: .keynote, level: 7, question: "Inspire the room.",
            transcript: "Friends, today we change everything.",
            timingStats: timing, audioFeatures: .empty
        )
        #expect(prompt.contains("142"))
    }

    @Test("prompt uses mode display name")
    func promptUsesModeDisplayName() {
        let prompt = FeedbackGenerator.buildPrompt(
            mode: .pitch, level: 5, question: "Pitch your startup.",
            transcript: "We solve a real problem.",
            timingStats: .empty, audioFeatures: .empty
        )
        #expect(prompt.contains(SessionMode.pitch.displayName))
    }

    @Test("prompt requests JSON-only output with no markdown")
    func promptRequestsJsonOnly() {
        let prompt = FeedbackGenerator.buildPrompt(
            mode: .casual, level: 2, question: "How was your day?",
            transcript: "It was really great actually.",
            timingStats: .empty, audioFeatures: .empty
        )
        #expect(prompt.contains("Return ONLY valid JSON"))
        #expect(prompt.contains("no markdown"))
    }
}
