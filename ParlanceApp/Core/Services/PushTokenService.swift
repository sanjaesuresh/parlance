// Parlance/Core/Services/PushTokenService.swift
import Foundation
import Supabase

@MainActor
final class PushTokenService {
    static let shared = PushTokenService()

    private let client = SupabaseManager.shared.client
    private static let iso8601 = ISO8601DateFormatter()

    private init() {}

    /// Upserts the APNs device token for the currently authenticated user.
    /// Conflicts on `user_id` so reinstalls overwrite the stale token rather
    /// than creating duplicate rows. Failures are logged and swallowed —
    /// push delivery is non-critical.
    func upsert(token: String) async {
        guard let userID = client.auth.currentUser?.id else {
            print("[PushTokenService] No authenticated user — skipping token upsert")
            return
        }

        do {
            try await client
                .from("push_tokens")
                .upsert(
                    [
                        "user_id":  userID.uuidString,
                        "token":    token,
                        "platform": "ios",
                        "updated_at": PushTokenService.iso8601.string(from: Date())
                    ],
                    onConflict: "user_id"
                )
                .execute()
            print("[PushTokenService] Token upserted for user \(userID)")
        } catch {
            print("[PushTokenService] Failed to upsert token: \(error)")
        }
    }

    /// Deletes the push token row for the currently authenticated user.
    /// Call before signing out so the row is removed while the session is
    /// still valid. Failures are logged and swallowed.
    func deleteToken() async {
        guard let userID = client.auth.currentUser?.id else {
            print("[PushTokenService] No authenticated user — skipping token deletion")
            return
        }

        do {
            try await client
                .from("push_tokens")
                .delete()
                .eq("user_id", value: userID.uuidString)
                .execute()
            print("[PushTokenService] Token deleted for user \(userID)")
        } catch {
            print("[PushTokenService] Failed to delete token: \(error)")
        }
    }
}
