// ParlanceApp/Core/Services/AvatarService.swift
import Foundation
import UIKit
import Supabase

/// Single source of truth for avatar storage paths, public URLs, and upload/delete.
/// Never let call sites construct bucket paths or URLs themselves.
@MainActor
final class AvatarService {
    static let shared = AvatarService()

    static let bucketName = "avatars"
    private static let maxDimension: CGFloat = 512
    private static let jpegQuality: CGFloat = 0.8

    private init() {}

    // MARK: - Path / URL helpers (pure, unit-tested)

    nonisolated static func objectPath(for userId: String) -> String {
        "\(userId)/avatar.jpg"
    }

    nonisolated static func cacheBustedURL(base: URL, updatedAt: Date?) -> URL {
        guard let updatedAt else { return base }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        let stamp = Int(updatedAt.timeIntervalSince1970)
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "v", value: String(stamp)))
        components.queryItems = items
        return components.url ?? base
    }

    nonisolated static func resizeForUpload(_ data: Data) throws -> Data {
        guard let source = UIImage(data: data) else {
            throw AvatarError.invalidImage
        }
        let scale = min(1, maxDimension / max(source.size.width, source.size.height))
        let target = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = resized.jpegData(compressionQuality: jpegQuality) else {
            throw AvatarError.encodeFailed
        }
        return jpeg
    }

    // MARK: - Public URL for a stored avatar

    func publicURL(forPath path: String, updatedAt: Date?) -> URL? {
        guard let base = try? SupabaseManager.shared.client.storage
            .from(Self.bucketName)
            .getPublicURL(path: path) else {
            return nil
        }
        return Self.cacheBustedURL(base: base, updatedAt: updatedAt)
    }

    // MARK: - Upload / delete (network — exercised manually, not in unit tests)

    @discardableResult
    func uploadAvatar(originalData: Data, userId: String) async throws -> String {
        let jpeg = try Self.resizeForUpload(originalData)
        let path = Self.objectPath(for: userId)
        _ = try await SupabaseManager.shared.client.storage
            .from(Self.bucketName)
            .upload(
                path,
                data: jpeg,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return path
    }

    func deleteAvatar(userId: String) async throws {
        let path = Self.objectPath(for: userId)
        _ = try await SupabaseManager.shared.client.storage
            .from(Self.bucketName)
            .remove(paths: [path])
    }

    /// Persists the avatar path + timestamp on the caller's profiles row.
    func updateProfileAvatar(userId: String, path: String?) async throws -> Date {
        let stamp = Date()
        struct AvatarUpdate: Encodable {
            let avatar_url: String?
            let avatar_updated_at: Date
        }
        try await SupabaseManager.shared.client
            .from("profiles")
            .update(AvatarUpdate(avatar_url: path, avatar_updated_at: stamp))
            .eq("id", value: userId)
            .execute()
        return stamp
    }
}

enum AvatarError: Error {
    case invalidImage
    case encodeFailed
}
