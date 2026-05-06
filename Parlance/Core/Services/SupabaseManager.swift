// Parlance/Core/Services/SupabaseManager.swift
import Foundation
import Supabase

// Credentials injected via project.pbxproj INFOPLIST_KEY_* build settings.
// The Supabase anon key is safe to embed — RLS policies enforce access control server-side.
@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""

        guard let url = URL(string: urlString), !urlString.isEmpty else {
            fatalError("[SupabaseManager] Invalid or missing SupabaseURL in Info.plist")
        }
        guard !key.isEmpty else {
            fatalError("[SupabaseManager] Missing SupabaseAnonKey in Info.plist")
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
