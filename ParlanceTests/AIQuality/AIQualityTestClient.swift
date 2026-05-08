// ParlanceTests/AIQuality/AIQualityTestClient.swift
import Foundation
@testable import Parlance

/// `ScoringClient` used by the AI quality harness. Always passes `temperature: 0` to the
/// worker so successive runs are near-deterministic.
final class AIQualityTestClient: ScoringClient {
    private let inner: ClaudeClient

    init(baseURL: URL = AppConstants.apiBaseURL) {
        self.inner = ClaudeClient(baseURL: baseURL, temperature: 0)
    }

    func fetchScoring(prompt: String) async throws -> ScoringResult {
        try await inner.fetchScoring(prompt: prompt)
    }
}
