import AVFoundation
import Combine

@MainActor
final class AudioRecorder: ObservableObject {
    /// Why the recorder stopped. `nil` while recording or before any
    /// session. Read by RecordingView to distinguish a user tap from a
    /// phone-call interruption — the latter should surface a "your call
    /// interrupted the recording" sheet rather than silently auto-stop into
    /// processing.
    enum StopReason: Equatable {
        case userTap
        case interruption
        case maxDuration
    }

    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: AppConstants.waveformBarCount)
    @Published private(set) var stoppedReason: StopReason?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private(set) var recordingURL: URL?
    private var interruptionObserver: NSObjectProtocol?

    var canStop: Bool { elapsedTime >= AppConstants.minRecordingDuration }
    var shouldShowNudge: Bool { elapsedTime >= AppConstants.deliberateNudgeTime && elapsedTime < AppConstants.deliberateNudgeTime + 3 }
    var shouldShowWrapUp: Bool { elapsedTime >= AppConstants.wrapUpWarningTime }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in
                _ = self?.stopRecording(reason: .interruption)
            }
        }

        stoppedReason = nil
        isRecording = true
        startTime = .now

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }
    }

    /// Stops recording and records `reason` (defaulting to `.userTap`) so the
    /// caller can distinguish a user tap from an interruption or max-duration
    /// auto-stop. The first call to set `stoppedReason` wins — re-entry from
    /// `updateMeters` after an interruption observer fired won't overwrite
    /// the `.interruption` reason.
    @discardableResult
    func stopRecording(reason: StopReason = .userTap) -> URL? {
        if stoppedReason == nil {
            stoppedReason = reason
        }
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recordingURL
    }

    func deleteRecording() {
        guard let url = recordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }

    private func updateMeters() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()

        if let startTime {
            elapsedTime = Date.now.timeIntervalSince(startTime)
        }

        if elapsedTime >= AppConstants.maxRecordingDuration {
            _ = stopRecording(reason: .maxDuration)
            return
        }

        let power = recorder.averagePower(forChannel: 0)
        let normalizedPower = max(0, (power + 50) / 50)

        var newLevels = audioLevels
        newLevels.removeFirst()
        newLevels.append(normalizedPower)
        audioLevels = newLevels
    }
}
