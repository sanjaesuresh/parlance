// Parlance/Core/Services/AudioFeatureExtractor.swift
import AVFoundation
import Accelerate

enum AudioFeatureExtractor {

    /// Extract pitch and energy features from a recorded audio file.
    /// Runs synchronously — call from a background context.
    static func extract(from url: URL) -> AudioFeatures {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return .empty
        }

        let processingFormat = audioFile.processingFormat
        let totalFrameCount = AVAudioFrameCount(audioFile.length)
        guard totalFrameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: totalFrameCount),
              (try? audioFile.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData else {
            return .empty
        }

        let samples = channelData[0]  // mono (channel 0)
        let totalFrames = Int(buffer.frameLength)
        let sampleRate = Float(processingFormat.sampleRate)
        let frameSize = 2048

        var rmsValues: [Double] = []
        var pitchValues: [Double] = []

        var offset = 0
        while offset + frameSize <= totalFrames {
            let framePtr = samples + offset

            var rms: Float = 0
            vDSP_rmsqv(framePtr, 1, &rms, vDSP_Length(frameSize))
            rmsValues.append(Double(rms))

            if rms > 0.01 {
                if let f0 = estimatePitch(samples: framePtr, count: frameSize, sampleRate: sampleRate) {
                    pitchValues.append(Double(f0))
                }
            }

            offset += frameSize
        }

        guard !rmsValues.isEmpty else { return .empty }

        return AudioFeatures(
            pitchMeanHz: pitchValues.isEmpty ? 0 : pitchValues.reduce(0, +) / Double(pitchValues.count),
            pitchStdDevHz: pitchValues.isEmpty ? 0 : stdDev(pitchValues),
            energyMeanRMS: rmsValues.reduce(0, +) / Double(rmsValues.count),
            energyStdDevRMS: stdDev(rmsValues)
        )
    }

    // MARK: - Pitch via autocorrelation

    private static func estimatePitch(samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float? {
        let minLag = Int(sampleRate / 300)  // 300 Hz upper bound
        let maxLag = Int(sampleRate / 85)   // 85 Hz lower bound
        guard minLag > 0, maxLag < count, minLag < maxLag else { return nil }

        var r0: Float = 0
        vDSP_dotpr(samples, 1, samples, 1, &r0, vDSP_Length(count))
        guard r0 > 0 else { return nil }

        var bestLag = minLag
        var bestCorr: Float = -1

        for lag in minLag...maxLag {
            let len = count - lag
            guard len > 0 else { break }
            var corr: Float = 0
            vDSP_dotpr(samples, 1, samples + lag, 1, &corr, vDSP_Length(len))
            corr /= r0
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }

        guard bestCorr > 0.4 else { return nil }
        return sampleRate / Float(bestLag)
    }

    // MARK: - Stats

    private static func stdDev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
