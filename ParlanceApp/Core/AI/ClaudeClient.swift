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

    // MARK: - Full scoring response

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

    // MARK: - Legacy plain-feedback path (kept for ResultsViewModel.retryFeedback)

    struct FeedbackResponse: Decodable {
        let feedback: String
    }

    func fetchFeedback(prompt: String) async throws -> String {
        let data = try await post(prompt: prompt)
        let decoded = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return decoded.feedback
    }

    // MARK: - Shared transport

    private func post(prompt: String, timeout: TimeInterval = 8) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("feedback")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        var body: [String: Any] = [
            "messages": [["role": "user", "content": prompt]]
        ]
        if let temperature {
            body["temperature"] = temperature
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[ClaudeClient] Bad status. Raw:", String(data: data, encoding: .utf8) ?? "<non-UTF8>")
            #endif
            throw URLError(.badServerResponse)
        }
        #if DEBUG
        print("[ClaudeClient] Raw response:", String(data: data, encoding: .utf8) ?? "<non-UTF8>")
        #endif
        return data
    }
}
