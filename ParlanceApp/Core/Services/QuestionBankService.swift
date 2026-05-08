import Foundation

final class QuestionBankService {
    let allQuestions: [Question]

    init() {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let questions = try? JSONDecoder().decode([Question].self, from: data) else {
            #if DEBUG
            print("[QuestionBankService] Failed to load questions.json — using empty bank")
            #endif
            self.allQuestions = []
            return
        }
        self.allQuestions = questions
    }

    init(questions: [Question]) {
        self.allQuestions = questions
    }

    func questions(for mode: SessionMode, band: String) -> [Question] {
        allQuestions.filter { $0.mode == mode && $0.difficultyBand == band }
    }

    func selectQuestion(
        mode: SessionMode,
        band: String,
        category: ExplanationCategory? = nil,
        excludingIds: Set<String>
    ) -> Question? {
        let bandPool = questions(for: mode, band: band)

        // Non-explanation modes: ignore category, original behavior.
        guard mode == .explanation else {
            let unseen = bandPool.filter { !excludingIds.contains($0.id) }
            return unseen.randomElement() ?? bandPool.randomElement()
        }

        let resolvedCategory = category ?? .any

        // "Any topic" pulls from knowledge-tier prompts only — industries
        // (Tech, Healthcare, Finance, etc.) require domain familiarity that
        // a general user shouldn't be assumed to have.
        let anyPool = bandPool.filter { $0.category?.tier == .knowledge }

        if resolvedCategory != .any {
            let categoryPool = bandPool.filter { $0.category == resolvedCategory }
            let categoryUnseen = categoryPool.filter { !excludingIds.contains($0.id) }
            if let pick = categoryUnseen.randomElement() {
                return pick
            }
            // Fallback (a): same category, ignore seen.
            if let pick = categoryPool.randomElement() {
                return pick
            }
        }

        // Fallback (b): broader pool, unseen.
        let anyUnseen = anyPool.filter { !excludingIds.contains($0.id) }
        if let pick = anyUnseen.randomElement() {
            return pick
        }

        // Fallback (c): broader pool, ignore seen. Final defensive fall-through
        // to bandPool covers the (unexpected) case of an empty knowledge pool.
        return anyPool.randomElement() ?? bandPool.randomElement()
    }
}
