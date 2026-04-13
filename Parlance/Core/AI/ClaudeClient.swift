// Parlance/Core/AI/ClaudeClient.swift
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

    // MARK: - New: full scoring response

    func fetchScoring(prompt: String) async throws -> ScoringResult {
        let data = try await post(prompt: prompt, timeout: AppConstants.scoringTimeout)

        if let result = try? JSONDecoder().decode(ScoringResult.self, from: data) {
            return result
        }
        #if DEBUG
        print("[ClaudeClient] Direct ScoringResult decode failed. Raw response:", String(data: data, encoding: .utf8) ?? "<non-UTF8>")
        #endif

        struct Wrapped: Decodable { let feedback: String }
        if let wrapped = try? JSONDecoder().decode(Wrapped.self, from: data),
           let jsonData = wrapped.feedback.data(using: .utf8),
           let result = try? JSONDecoder().decode(ScoringResult.self, from: jsonData) {
            return result
        }
        #if DEBUG
        print("[ClaudeClient] Wrapped ScoringResult decode also failed.")
        #endif

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Legacy: plain feedback string (kept for ResultsViewModel.retryFeedback)

    struct FeedbackResponse: Decodable {
        let feedback: String
    }

    func fetchFeedback(prompt: String) async throws -> String {
        let data = try await post(prompt: prompt)
        let decoded = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return decoded.feedback
    }

    // MARK: - Shared transport

    private func post(prompt: String, timeout: TimeInterval = AppConstants.feedbackTimeout) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("feedback")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let body: [String: Any] = [
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
