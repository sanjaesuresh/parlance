import AVFoundation
import Speech
import UIKit
import Combine

@MainActor
final class PermissionsService: ObservableObject {
    @Published var microphoneStatus: AVAudioApplication.RecordPermission = AVAudioApplication.shared.recordPermission
    @Published var speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    var microphoneGranted: Bool { microphoneStatus == .granted }
    var speechGranted: Bool { speechStatus == .authorized }

    func requestMicrophone() async -> Bool {
        do {
            let granted = try await AVAudioApplication.requestRecordPermission()
            microphoneStatus = AVAudioApplication.shared.recordPermission
            return granted
        } catch {
            return false
        }
    }

    func requestSpeechRecognition() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.speechStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
