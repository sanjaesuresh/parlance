import SwiftUI
import Combine

@MainActor
final class RealLifeSetupViewModel: ObservableObject {
    @Published var scenarioText: String = ""
    @Published var durationSeconds: Int = 60          // default 1:00
    @Published private(set) var denylistTripped: Bool = false
    @Published private(set) var validationFailure: RealLifeScenarioValidator.Failure?

    private let history: RealLifeScenarioHistoryStore
    private let denylist: (String) -> Bool

    static let maxLength = 500
    static let minDurationToStart = 15                 // hard floor
    static let maxDuration = 180
    static let durationStep = 15

    init(
        history: RealLifeScenarioHistoryStore = .shared,
        denylist: @escaping (String) -> Bool = RealLifeContentDenylist.matches,
        prefillScenario: String? = nil
    ) {
        self.history = history
        self.denylist = denylist
        if let prefill = prefillScenario, !prefill.isEmpty {
            let clamped = String(prefill.prefix(Self.maxLength))
            scenarioText = clamped
            denylistTripped = denylist(clamped)
        }
    }

    var trimmedScenario: String {
        scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var characterCount: Int { scenarioText.count }
    var characterCountColor: Color {
        characterCount > Self.maxLength - 20 ? AppColors.red : AppColors.dim
    }

    var canStart: Bool {
        !trimmedScenario.isEmpty
            && characterCount <= Self.maxLength
            && durationSeconds >= Self.minDurationToStart
            && !denylistTripped
    }

    var durationDisplay: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var recentScenarios: [ScenarioHistoryEntry] { history.recent() }

    /// Called whenever the user edits the text field. Re-runs the denylist
    /// check and clamps to max length.
    func onScenarioChange(_ newValue: String) {
        let clamped = String(newValue.prefix(Self.maxLength))
        scenarioText = clamped
        denylistTripped = denylist(clamped)
        validationFailure = nil
    }

    /// Validates the scenario text. Returns true if valid (ready to start),
    /// false and sets `validationFailure` if not. Called on Continue tap.
    @discardableResult
    func attemptStart() -> Bool {
        if let failure = RealLifeScenarioValidator.validate(trimmedScenario) {
            validationFailure = failure
            return false
        }
        validationFailure = nil
        return true
    }

    /// Called when the user taps a recent chip.
    func loadFromRecent(_ entry: ScenarioHistoryEntry) {
        onScenarioChange(entry.text)
    }

    /// Snap a continuous 0...180 slider value to the nearest 15s step.
    func setDurationFromSlider(_ continuousSeconds: Double) {
        let snapped = (Int(continuousSeconds.rounded()) / Self.durationStep) * Self.durationStep
        durationSeconds = min(Self.maxDuration, max(0, snapped))
    }
}
