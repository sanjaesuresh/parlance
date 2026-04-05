import Foundation

final class ClaudeClient {
    private let baseURL: URL

    init() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String,
              let url = URL(string: urlString) else {
            fatalError("ParlanceAPIBaseURL not set in Info.plist")
        }
        self.baseURL = url
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    struct FeedbackResponse: Decodable {
        let feedback: String
    }

    func fetchFeedback(prompt: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("feedback")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.feedbackTimeout

        let body: [String: Any] = [
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return decoded.feedback
    }
}
