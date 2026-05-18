// Parlance/Core/AI/WeeklyBriefClient.swift
//
// Client wrapper for POST /coach/weekly-brief. Returns a WeeklyBrief on success;
// throws on non-2xx, since the Worker always degrades to a fallback brief itself —
// the only ways this path errors are auth, rate-limit, network, or the
// "insufficient_data" 400 (which the client checks BEFORE making the call,
// but defends against here too).

import Foundation

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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let endpoint = Endpoint<WeeklyBriefRequest, WeeklyBrief>.json(
            path: "coach/weekly-brief",
            request: payload,
            timeout: 12,
            encoder: encoder,
            decoder: decoder
        )

        do {
            return try await APIClient(baseURL: baseURL).send(endpoint)
        } catch let apiError as APIError {
            throw map(apiError)
        }
    }

    private static func map(_ error: APIError) -> WeeklyBriefError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .rateLimited:
            return .rateLimited
        case .server(let status, let body):
            if status == 400, let body = body,
               let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               (json["error"] as? String) == "insufficient_data" {
                return .insufficientData
            }
            return .server(status: status)
        case .decode:
            #if DEBUG
            print("[WeeklyBriefClient] decode failed")
            #endif
            return .decode
        case .transport, .offline:
            return .server(status: -1)
        }
    }
}
