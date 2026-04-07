import SwiftUI
import Combine
import SwiftData

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var isRetryingFeedback = false

    func retryFeedback(for session: Session, question: Question) async {
        isRetryingFeedback = true

        let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String ?? ""
        guard let url = URL(string: urlString) else {
            isRetryingFeedback = false
            return
        }
        let client = ClaudeClient(baseURL: url)

        let feedback = await FeedbackGenerator.fetchFeedback(
            client: client,
            mode: session.mode,
            level: session.difficultyLevel,
            question: question.question,
            duration: session.duration,
            overallScore: session.overallScore,
            fillerCount: session.fillerCount,
            paceScore: session.paceScore,
            clarityScore: session.clarityScore,
            structureScore: session.structureScore,
            vocabularyScore: session.vocabularyScore,
            transcript: session.transcript
        )
        session.aiCoachFeedback = feedback
        try? PersistenceService.shared.context.save()
        isRetryingFeedback = false
    }

    func fillerTip(for session: Session) -> String {
        guard session.hasTranscript else { return "Enable speech recognition for filler word analysis." }
        let filler = SpeechAnalyzer.analyzeFillers(in: session.transcript)
        if let most = filler.mostFrequent {
            return "Try to reduce your use of '\(most)' — it appeared most often."
        }
        return session.fillerCount == 0 ? "No filler words detected — excellent!" : "Work on reducing filler words."
    }

    func paceTip(for session: Session) -> String {
        guard session.hasTranscript else { return "Enable speech recognition for pace analysis." }
        let wordCount = session.transcript.split(separator: " ").count
        return SpeechAnalyzer.analyzePace(wordCount: wordCount, duration: session.duration).tip
    }

    func clarityTip(for session: Session) -> String {
        guard session.hasTranscript else { return "Enable speech recognition for clarity analysis." }
        return SpeechAnalyzer.analyzeClarity(in: session.transcript).tip
    }

    func structureTip(for session: Session) -> String {
        guard session.hasTranscript else { return "Enable speech recognition for structure analysis." }
        return SpeechAnalyzer.analyzeStructure(in: session.transcript, mode: session.mode).tip
    }

    func vocabularyTip(for session: Session) -> String {
        guard session.hasTranscript else { return "Enable speech recognition for vocabulary analysis." }
        return SpeechAnalyzer.analyzeVocabulary(in: session.transcript).tip
    }
}
