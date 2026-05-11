import SwiftUI
import Combine
import AVFAudio
import Speech

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var showMicPrePrompt = false
    @Published var showSpeechPrePrompt = false
    @Published var showSpeechDenied = false
    @Published var showPermissionDenied = false
    @Published var permissionDeniedMessage = ""
    @Published var recordingStartFailed = false

    func handleRecordTap(
        recorder: AudioRecorder,
        permissions: PermissionsService
    ) {
        if recorder.isRecording {
            return
        }

        if !permissions.microphoneGranted {
            if permissions.microphoneStatus == .undetermined {
                showMicPrePrompt = true
                return
            } else {
                permissionDeniedMessage = "Microphone access is required to record. Go to Settings → Privacy → Microphone to enable it."
                showPermissionDenied = true
                return
            }
        }

        if permissions.speechStatus == .denied || permissions.speechStatus == .restricted {
            showSpeechDenied = true
            return
        }

        if !permissions.speechGranted && permissions.speechStatus == .notDetermined {
            showSpeechPrePrompt = true
            return
        }

        do {
            try recorder.startRecording()
        } catch {
            recordingStartFailed = true
        }
    }

    func requestMicPermission(permissions: PermissionsService) async -> Bool {
        let granted = await permissions.requestMicrophone()
        if granted {
            showSpeechPrePrompt = true
        }
        return granted
    }

    func requestSpeechPermission(permissions: PermissionsService) async {
        _ = await permissions.requestSpeechRecognition()
    }
}
