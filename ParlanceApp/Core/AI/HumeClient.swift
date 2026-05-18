// Parlance/Core/AI/HumeClient.swift
import Foundation
import Supabase

enum HumeClient {
    /// Submits the audio to the Worker's /emotion/submit endpoint, then polls
    /// /emotion/status with exponential backoff until the Hume job completes,
    /// fails, or the total wait exceeds `AppConstants.humePollBudget`.
    static func analyzeEmotion(audioURL: URL, workerBaseURL: URL) async throws -> EmotionResult {
        let supabaseClient = await MainActor.run { SupabaseManager.shared.client }
        let accessToken = try await supabaseClient.auth.session.accessToken

        let jobID = try await submit(audioURL: audioURL, workerBaseURL: workerBaseURL, accessToken: accessToken)
        return try await poll(jobID: jobID, workerBaseURL: workerBaseURL, accessToken: accessToken)
    }

    private static func submit(audioURL: URL, workerBaseURL: URL, accessToken: String) async throws -> String {
        let endpoint = workerBaseURL.appendingPathComponent("emotion/submit")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = AppConstants.humeTimeout

        let audioData = try Data(contentsOf: audioURL)
        let (data, response) = try await URLSession.shared.upload(for: request, from: audioData)

        guard let http = response as? HTTPURLResponse else {
            throw HumeError.serverError(status: -1, body: "no HTTPURLResponse")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw HumeError.serverError(status: http.statusCode, body: body)
        }

        let submitResponse = try JSONDecoder().decode(SubmitResponse.self, from: data)
        return submitResponse.jobID
    }

    private static func poll(jobID: String, workerBaseURL: URL, accessToken: String) async throws -> EmotionResult {
        let endpoint = workerBaseURL.appendingPathComponent("emotion/status")
        let deadline = Date().addingTimeInterval(AppConstants.humePollBudget)
        // Backoff schedule (seconds); last value repeats until the budget runs out.
        let backoff: [UInt64] = [1, 1, 2, 2, 3, 3, 4, 5]
        var attempt = 0

        while Date() < deadline {
            let delay = backoff[min(attempt, backoff.count - 1)]
            try await Task.sleep(nanoseconds: delay * 1_000_000_000)
            attempt += 1

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = AppConstants.humeTimeout
            request.httpBody = try JSONEncoder().encode(["job_id": jobID])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HumeError.serverError(status: -1, body: "no HTTPURLResponse")
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                throw HumeError.serverError(status: http.statusCode, body: body)
            }

            let status = try JSONDecoder().decode(StatusResponse.self, from: data)
            switch status.status {
            case "completed":
                if let result = status.result {
                    return result
                }
                throw HumeError.serverError(status: 200, body: "completed without result payload")
            case "pending":
                continue
            default:
                throw HumeError.serverError(status: 200, body: "unknown status: \(status.status)")
            }
        }

        throw HumeError.timedOut
    }
}

private struct SubmitResponse: Decodable {
    let jobID: String

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
    }
}

private struct StatusResponse: Decodable {
    let status: String
    let result: EmotionResult?
}

enum HumeError: Error, CustomStringConvertible {
    case serverError(status: Int, body: String)
    case timedOut

    var description: String {
        switch self {
        case .serverError(let status, let body):
            return "serverError status=\(status) body=\(body.prefix(300))"
        case .timedOut:
            return "timedOut after \(AppConstants.humePollBudget)s"
        }
    }
}
