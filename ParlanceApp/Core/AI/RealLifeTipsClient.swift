import Foundation
import Supabase

enum RealLifeRefusalKind: String, Decodable {
    case notASpeakingPrompt
    case unsafe
}

enum RealLifeTipsResult: Equatable {
    case tips(rewrittenPrompt: String, tips: [String])
    case refused(reason: String, kind: RealLifeRefusalKind)
    case failed
}

protocol RealLifeTipsFetching {
    func fetchTips(scenario: String, level: Int, durationSeconds: Int) async -> RealLifeTipsResult
}

final class RealLifeTipsClient: RealLifeTipsFetching {
    private let baseURL: URL
    private let timeout: TimeInterval

    init(baseURL: URL = AppConstants.apiBaseURL, timeout: TimeInterval = 4) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func fetchTips(scenario: String, level: Int, durationSeconds: Int) async -> RealLifeTipsResult {
        do {
            let supabaseClient = await MainActor.run { SupabaseManager.shared.client }
            let accessToken = try await supabaseClient.auth.session.accessToken

            let endpoint = baseURL.appendingPathComponent("real-life/tips")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = timeout

            let body: [String: Any] = [
                "scenario": scenario,
                "level": level,
                "durationSeconds": durationSeconds,
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failed
            }

            struct Success: Decodable { let rewrittenPrompt: String; let tips: [String] }
            struct Refusal: Decodable {
                let refused: Bool
                let reason: String
                let kind: String?
            }

            if let refusal = try? JSONDecoder().decode(Refusal.self, from: data), refusal.refused {
                let kind = RealLifeRefusalKind(rawValue: refusal.kind ?? "") ?? .unsafe
                return .refused(reason: refusal.reason, kind: kind)
            }
            if let ok = try? JSONDecoder().decode(Success.self, from: data),
               !ok.rewrittenPrompt.isEmpty,
               ok.tips.count == 3, ok.tips.allSatisfy({ !$0.isEmpty }) {
                return .tips(rewrittenPrompt: ok.rewrittenPrompt, tips: ok.tips)
            }
            return .failed
        } catch {
            return .failed
        }
    }
}
