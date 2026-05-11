import AVFoundation
import Combine
import Speech
import UIKit

@MainActor
final class PermissionsService: ObservableObject {
    @Published var microphoneStatus: AVAudioApplication.recordPermission = AVAudioApplication.shared.recordPermission
    @Published var speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    var microphoneGranted: Bool { microphoneStatus == .granted }
    var speechGranted: Bool { speechStatus == .authorized }

    func requestMicrophone() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    self.microphoneStatus = AVAudioApplication.shared.recordPermission
                    continuation.resume(returning: granted)
                }
            }
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
