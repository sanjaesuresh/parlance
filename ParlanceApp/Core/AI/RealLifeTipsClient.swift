import Foundation

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
        let endpoint = Endpoint<TipsRequest, RealLifeTipsResult>(
            path: "real-life/tips",
            request: TipsRequest(scenario: scenario, level: level, durationSeconds: durationSeconds),
            timeout: timeout,
            decode: Self.decodeTips
        )

        do {
            return try await APIClient(baseURL: baseURL).send(endpoint)
        } catch {
            return .failed
        }
    }

    private static func decodeTips(_ data: Data) throws -> RealLifeTipsResult {
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
    }

    private struct TipsRequest: Encodable {
        let scenario: String
        let level: Int
        let durationSeconds: Int
    }

    private struct Success: Decodable {
        let rewrittenPrompt: String
        let tips: [String]
    }

    private struct Refusal: Decodable {
        let refused: Bool
        let reason: String
        let kind: String?
    }
}
