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
        request.shouldReportPartialResults = false
        // Prefer on-device recognition when the locale supports it. Without
        // this flag the request routes through Apple's servers, which makes
        // transcription fail in offline mode even though recording succeeded.
        // Falling back to network when the locale lacks an on-device model
        // is the existing default behavior.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withThrowingTaskGroup(of: TranscriptionResult.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    var didResume = false
                    recognizer.recognitionTask(with: request) { result, error in
                        guard !didResume else { return }
                        if let error {
                            didResume = true
                            #if DEBUG
                            print("[Transcription] Failed: \(error.localizedDescription)")
                            #endif
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
                            #if DEBUG
                            print("[Transcription] Success — \(segments.count) words: \(result.bestTranscription.formattedString.prefix(120))")
                            #endif
                            continuation.resume(returning: TranscriptionResult(
                                transcript: result.bestTranscription.formattedString,
                                segments: segments
                            ))
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw TranscriptionError.recognitionFailed("Transcription timed out")
            }

            // Return whichever finishes first, cancel the other
            guard let result = try await group.next() else {
                throw TranscriptionError.recognitionFailed("No result")
            }
            group.cancelAll()
            return result
        }
    }
}
