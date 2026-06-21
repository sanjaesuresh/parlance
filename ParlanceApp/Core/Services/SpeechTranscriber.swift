// Parlance/Core/Services/SpeechTranscriber.swift
import Speech
import AVFoundation

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
        // Partial results MUST stay enabled. On-device recognition splits long
        // audio into utterance windows and resets the transcript at each one;
        // its single `isFinal` callback only contains the *last* window. Each
        // completed window arrives earlier as a partial result carrying real
        // segment timestamps, so we accumulate those windows below to capture
        // the whole recording instead of just the final few seconds.
        request.shouldReportPartialResults = true
        // Prefer on-device recognition when the locale supports it. Without
        // this flag the request routes through Apple's servers, which makes
        // transcription fail in offline mode even though recording succeeded.
        // Falling back to network when the locale lacks an on-device model
        // is the existing default behavior.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // A fixed short timeout would abort long recordings before recognition
        // finishes. Scale it to the clip length with generous headroom.
        let timeout = await recognitionTimeout(for: url)

        return try await withThrowingTaskGroup(of: TranscriptionResult.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    var didResume = false
                    // Finalized windows accumulate here; in-progress partials
                    // (which report zero-valued timestamps) are skipped.
                    var committedText: [String] = []
                    var committedWords: [WordSegment] = []
                    var lastWindowEnd: TimeInterval = 0

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
                        guard let result else { return }

                        // A finalized utterance window carries real segment
                        // timing that extends past everything committed so far.
                        // In-progress partials report a zero end time and are
                        // ignored until the window is finalized. The strict
                        // comparison also dedupes a final result that merely
                        // repeats the last committed window.
                        let transcription = result.bestTranscription
                        let windowEnd = transcription.segments.last
                            .map { $0.timestamp + $0.duration } ?? 0
                        if windowEnd > lastWindowEnd {
                            lastWindowEnd = windowEnd
                            committedText.append(transcription.formattedString)
                            committedWords.append(contentsOf: transcription.segments.map {
                                WordSegment(
                                    word: $0.substring,
                                    timestamp: $0.timestamp,
                                    duration: $0.duration
                                )
                            })
                        }

                        if result.isFinal {
                            didResume = true
                            let transcript = committedText.joined(separator: " ")
                            #if DEBUG
                            print("[Transcription] Success — \(committedWords.count) words across \(committedText.count) windows: \(transcript.prefix(120))")
                            #endif
                            continuation.resume(returning: TranscriptionResult(
                                transcript: transcript,
                                segments: committedWords
                            ))
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
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

    /// Recognition headroom scaled to the clip length. File recognition of a
    /// multi-minute recording can take longer than a fixed short timeout, so we
    /// allow the audio duration plus a buffer, with a sensible floor.
    private static func recognitionTimeout(for url: URL) async -> TimeInterval {
        let floor: TimeInterval = 30
        let asset = AVURLAsset(url: url)
        do {
            let seconds = try await CMTimeGetSeconds(asset.load(.duration))
            guard seconds.isFinite, seconds > 0 else { return floor }
            return max(floor, seconds + 30)
        } catch {
            return floor
        }
    }
}
