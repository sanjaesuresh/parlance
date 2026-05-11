// Parlance/Core/AI/HumeClient.swift
import Foundation

enum HumeClient {
    /// Uploads the audio file at `audioURL` to the Cloudflare Worker's `/emotion` endpoint
    /// and returns the parsed EmotionResult. Throws if the network call fails or the Worker
    /// returns a non-2xx status.
    static func analyzeEmotion(audioURL: URL, workerBaseURL: URL) async throws -> EmotionResult {
        let supabaseClient = await MainActor.run { SupabaseManager.shared.client }
        let accessToken = try await supabaseClient.auth.session.accessToken

        let endpoint = workerBaseURL.appendingPathComponent("emotion")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = AppConstants.humeTimeout

        let audioData = try Data(contentsOf: audioURL)
        let (data, response) = try await URLSession.shared.upload(for: request, from: audioData)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HumeError.serverError
        }

        return try JSONDecoder().decode(EmotionResult.self, from: data)
    }
}

enum HumeError: Error {
    case serverError
}
