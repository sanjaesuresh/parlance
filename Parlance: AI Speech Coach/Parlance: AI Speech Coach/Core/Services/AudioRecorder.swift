import AVFoundation
import Combine

@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: AppConstants.waveformBarCount)

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private(set) var recordingURL: URL?

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

        isRecording = true
        startTime = .now

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMeters()
            }
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
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
            _ = stopRecording()
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
