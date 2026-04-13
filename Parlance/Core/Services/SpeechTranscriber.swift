// Parlance/Core/Services/SpeechTranscriber.swift
import Speech

struct TranscriptionResult {
    let transcript: String
    let segments: [WordSegment]
}

final class SpeechTranscriber {
    enum TranscriptionError: Error {
        case notAvailable
        case recognitionFailed(String)
    }

    static func transcribe(url: URL) async throws -> TranscriptionResult {
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
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                if let error {
                    didResume = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal {
                    didResume = true
                    let segments: [WordSegment] = result.bestTranscription.segments.map {
                        WordSegment(
                            word: $0.substring,
                            timestamp: $0.timestamp,
                            duration: $0.duration
                        )
                    }
                    continuation.resume(returning: TranscriptionResult(
                        transcript: result.bestTranscription.formattedString,
                        segments: segments
                    ))
                }
            }
        }
    }
}
