import Foundation
import os

/// On-disk manifest for the currently-in-progress recording session.
/// Lives in Application Support (not temp) so it survives reboots and
/// iOS clearing the temp directory. Lets us recover the user's audio
/// on cold start after a force-quit or crash mid-recording.
@MainActor
final class ActiveSessionPersistence {
    static let shared = ActiveSessionPersistence()

    private static let schemaVersion = 1
    private static let fileName = "active_session.json"

    private let logger = Logger(subsystem: "com.parlance.app", category: "ActiveSessionPersistence")
    private let fileManager = FileManager.default

    private init() {}

    struct Manifest: Codable {
        var schemaVersion: Int
        var audioFilePath: String
        var mode: SessionMode
        var difficultyLevel: Int
        var question: Question
        var wasDailyChallenge: Bool
        var startedAt: Date
        var phase: Phase

        enum Phase: String, Codable {
            case recording
            case processing
        }
    }

    // MARK: - Paths

    private var manifestURL: URL? {
        do {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return support.appendingPathComponent(Self.fileName, isDirectory: false)
        } catch {
            logger.error("manifest URL resolve failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Public API

    func write(
        audioURL: URL,
        state: ActiveSessionState,
        phase: Manifest.Phase,
        startedAt: Date = .now
    ) {
        guard let url = manifestURL else { return }
        let manifest = Manifest(
            schemaVersion: Self.schemaVersion,
            audioFilePath: audioURL.path,
            mode: state.mode,
            difficultyLevel: state.difficultyLevel,
            question: state.question,
            wasDailyChallenge: state.wasDailyChallenge,
            startedAt: startedAt,
            phase: phase
        )
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(manifest)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("manifest write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updatePhase(_ phase: Manifest.Phase) {
        guard var manifest = read() else { return }
        manifest.phase = phase
        guard let url = manifestURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(manifest)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("manifest phase update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func read() -> Manifest? {
        guard let url = manifestURL,
              fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(Manifest.self, from: data)
            guard manifest.schemaVersion == Self.schemaVersion else {
                logger.notice("manifest schemaVersion mismatch — treating as missing")
                return nil
            }
            return manifest
        } catch {
            logger.error("manifest read failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func clear() {
        guard let url = manifestURL,
              fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            logger.error("manifest clear failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Recovery

    /// Returns a usable recovery candidate or nil. Silently clears stale
    /// state (missing or zero-byte audio) — no user-visible error.
    func recoveryCandidate() -> ResumeCandidate? {
        guard let manifest = read() else { return nil }
        let audioURL = URL(fileURLWithPath: manifest.audioFilePath)
        let fileExists = fileManager.fileExists(atPath: audioURL.path)
        let size: Int64 = {
            guard fileExists,
                  let attrs = try? fileManager.attributesOfItem(atPath: audioURL.path),
                  let n = attrs[.size] as? NSNumber else { return 0 }
            return n.int64Value
        }()
        guard fileExists, size > 0 else {
            clear()
            if fileExists {
                try? fileManager.removeItem(at: audioURL)
            }
            return nil
        }
        return ResumeCandidate(manifest: manifest, audioURL: audioURL)
    }

    /// Deletes audio files in the temp directory older than 24h that match
    /// the AudioRecorder naming pattern (UUID.m4a). Skips the currently
    /// recovered file (if any) so an in-flight recovery is never destroyed.
    /// Static + nonisolated so it can run on a background task at launch.
    nonisolated static func sweepOrphanedTempRecordings(excluding active: URL? = nil) {
        let fileManager = FileManager.default
        let logger = Logger(subsystem: "com.parlance.app", category: "ActiveSessionPersistence")
        let tmp = fileManager.temporaryDirectory
        let excludedPath = active?.standardizedFileURL.path
        let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60)
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: tmp,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            for url in contents where url.pathExtension == "m4a" {
                let name = url.deletingPathExtension().lastPathComponent
                guard UUID(uuidString: name) != nil else { continue }
                if let excludedPath, url.standardizedFileURL.path == excludedPath { continue }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                let mtime = values?.contentModificationDate ?? .distantPast
                guard mtime < cutoff else { continue }
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    logger.error("orphan sweep delete failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            logger.error("orphan sweep enumerate failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// In-memory wrapper passed to the UI when a recovery candidate exists.
struct ResumeCandidate: Identifiable {
    let id = UUID()
    let manifest: ActiveSessionPersistence.Manifest
    let audioURL: URL

    var sessionState: ActiveSessionState {
        ActiveSessionState(
            mode: manifest.mode,
            difficultyLevel: manifest.difficultyLevel,
            question: manifest.question,
            wasDailyChallenge: manifest.wasDailyChallenge
        )
    }
}
