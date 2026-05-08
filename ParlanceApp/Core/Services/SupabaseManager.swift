// Parlance/Core/Services/SupabaseManager.swift
import Foundation
import Supabase

// The Supabase anon key is safe to embed — RLS policies enforce access control server-side.
// It is not a secret; it identifies the project, not a privileged user.
@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // swiftlint:disable line_length
        let url = URL(string: "https://xekrfjufgorrcnpnsaei.supabase.co")!
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhla3JmanVmZ29ycmNucG5zYWVpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwMjMxNzgsImV4cCI6MjA5MzU5OTE3OH0.w4gjaTtnrYyDLoqRMYPNwm0vBYRLfUp1jYOrvVhWxfc"
        // swiftlint:enable line_length
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
