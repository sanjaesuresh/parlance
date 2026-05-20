// Parlance/Core/AI/ClaudeClient.swift
import Foundation

enum ScoringError: Error, Equatable {
    /// The server returned a `{ refused: true, reason: "..." }` envelope.
    case refused(reason: String)
    /// The server returned 200 but the body was unparseable as either
    /// a `ScoringResult` or a refused envelope.
    case parseFailure
}

protocol ScoringClient {
    func fetchScoring(prompt: String, transcript: String) async throws -> ScoringResult
}

final class ClaudeClient: ScoringClient {
    private let baseURL: URL
    private let temperature: Double?

    init(baseURL: URL = AppConstants.apiBaseURL, temperature: Double? = nil) {
        self.baseURL = baseURL
        self.temperature = temperature
    }

    func fetchScoring(prompt: String, transcript: String) async throws -> ScoringResult {
        let endpoint = Endpoint<FeedbackRequest, ScoringResult>(
            path: "feedback",
            request: FeedbackRequest(
                messages: [.init(role: "user", content: prompt)],
                temperature: temperature,
                transcript: transcript
            ),
            timeout: AppConstants.scoringTimeout,
            decode: Self.decodeScoring
        )
        return try await APIClient(baseURL: baseURL).send(endpoint)
    }

    // Why: Worker sometimes wraps ScoringResult JSON inside a `{ "feedback": "<json>" }` envelope.
    private static func decodeScoring(_ data: Data) throws -> ScoringResult {
        // 1) Direct ScoringResult.
        if let result = try? JSONDecoder().decode(ScoringResult.self, from: data) {
            return result
        }

        // 2) Worker may return a refused envelope: { "refused": true, "reason": "<code>" }
        struct Refused: Decodable { let refused: Bool; let reason: String? }
        if let refused = try? JSONDecoder().decode(Refused.self, from: data), refused.refused {
            throw ScoringError.refused(reason: refused.reason ?? "unknown")
        }

        // 3) Worker may wrap ScoringResult JSON inside { "feedback": "<json>" }.
        struct Wrapped: Decodable { let feedback: String }
        if let wrapped = try? JSONDecoder().decode(Wrapped.self, from: data),
           let jsonData = wrapped.feedback.data(using: .utf8),
           let result = try? JSONDecoder().decode(ScoringResult.self, from: jsonData) {
            return result
        }

        #if DEBUG
        print("[ClaudeClient] Could not decode response. Raw:", String(data: data, encoding: .utf8) ?? "<non-UTF8>")
        #endif
        throw ScoringError.parseFailure
    }

    private struct FeedbackRequest: Encodable {
        let messages: [Message]
        let temperature: Double?
        let transcript: String

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }
}
