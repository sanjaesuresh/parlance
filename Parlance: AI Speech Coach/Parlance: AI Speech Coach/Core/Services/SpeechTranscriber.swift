import Speech

final class SpeechTranscriber {
    enum TranscriptionError: Error {
        case notAvailable
        case recognitionFailed(String)
    }

    static func transcribe(url: URL) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAvailable
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
