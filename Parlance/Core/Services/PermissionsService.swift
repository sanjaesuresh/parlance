import AVFoundation
import Speech
import UIKit
import Combine

final class PermissionsService: ObservableObject {
    @Published var microphoneStatus: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
    @Published var speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    var microphoneGranted: Bool { microphoneStatus == .granted }
    var speechGranted: Bool { speechStatus == .authorized }

    func requestMicrophone() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.microphoneStatus = AVAudioSession.sharedInstance().recordPermission
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

    @MainActor
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
