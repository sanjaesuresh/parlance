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

    func selectQuestion(mode: SessionMode, band: String, excludingIds: Set<String>) -> Question? {
        let eligible = questions(for: mode, band: band)
        let unseen = eligible.filter { !excludingIds.contains($0.id) }

        if unseen.isEmpty {
            return eligible.randomElement()
        }
        return unseen.randomElement()
    }
}
