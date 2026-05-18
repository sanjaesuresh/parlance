// Parlance/Core/AI/ClaudeClient.swift
import Foundation

protocol ScoringClient {
    func fetchScoring(prompt: String) async throws -> ScoringResult
}

final class ClaudeClient: ScoringClient {
    private let baseURL: URL
    private let temperature: Double?

    init(baseURL: URL = AppConstants.apiBaseURL, temperature: Double? = nil) {
        self.baseURL = baseURL
        self.temperature = temperature
    }

    func fetchScoring(prompt: String) async throws -> ScoringResult {
        let endpoint = Endpoint<FeedbackRequest, ScoringResult>(
            path: "feedback",
            request: FeedbackRequest(
                messages: [.init(role: "user", content: prompt)],
                temperature: temperature
            ),
            timeout: AppConstants.scoringTimeout,
            decode: Self.decodeScoring
        )
        return try await APIClient(baseURL: baseURL).send(endpoint)
    }

    // Why: Worker sometimes wraps ScoringResult JSON inside a `{ "feedback": "<json>" }` envelope.
    private static func decodeScoring(_ data: Data) throws -> ScoringResult {
        if let result = try? JSONDecoder().decode(ScoringResult.self, from: data) {
            return result
        }
        #if DEBUG
        print("[ClaudeClient] Direct ScoringResult decode failed. Raw:", String(data: data, encoding: .utf8) ?? "<non-UTF8>")
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

    private struct FeedbackRequest: Encodable {
        let messages: [Message]
        let temperature: Double?

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }
}
