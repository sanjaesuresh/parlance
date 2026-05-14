// Parlance/Core/AI/WeeklyBriefClient.swift
//
// Client wrapper for POST /coach/weekly-brief. Mirrors ClaudeClient's
// authenticated-POST pattern. Returns a WeeklyBrief on success; throws on
// non-2xx, since the Worker always degrades to a fallback brief itself —
// the only ways this path errors are auth, rate-limit, network, or the
// "insufficient_data" 400 (which the client checks BEFORE making the call,
// but defends against here too).

import Foundation
import Supabase

struct WeeklyBriefHighlight: Codable, Equatable {
    let kind: String      // "positive" | "negative"
    let phrase: String
}

struct WeeklyBrief: Codable, Equatable {
    let brief: String
    let highlights: [WeeklyBriefHighlight]
    let generatedAt: Date
    let model: String?     // nil when source == "fallback"
    let source: String     // "gemini" | "fallback"
}

enum WeeklyBriefError: Error, Equatable {
    case unauthorized
    case rateLimited
    case insufficientData
    case server(status: Int)
    case decode
}

enum WeeklyBriefClient {

    static func fetch(payload: WeeklyBriefRequest, baseURL: URL = AppConstants.apiBaseURL) async throws -> WeeklyBrief {
        let endpoint = baseURL.appendingPathComponent("coach/weekly-brief")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12

        let supabaseClient = await MainActor.run { SupabaseManager.shared.client }
        let accessToken = try await supabaseClient.auth.session.accessToken
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase  // payload uses camelCase by spec, override below
        // Actually the Worker contract is camelCase, not snake — keep default.
        let encoderCamel = JSONEncoder()
        encoderCamel.dateEncodingStrategy = .iso8601
        request.httpBody = try encoderCamel.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WeeklyBriefError.decode }

        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return try decoder.decode(WeeklyBrief.self, from: data)
            } catch {
                #if DEBUG
                print("[WeeklyBriefClient] decode failed:", String(data: data, encoding: .utf8) ?? "<binary>")
                #endif
                throw WeeklyBriefError.decode
            }
        case 400:
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if (body?["error"] as? String) == "insufficient_data" {
                throw WeeklyBriefError.insufficientData
            }
            throw WeeklyBriefError.server(status: 400)
        case 401:
            throw WeeklyBriefError.unauthorized
        case 429:
            throw WeeklyBriefError.rateLimited
        default:
            throw WeeklyBriefError.server(status: http.statusCode)
        }
    }
}
