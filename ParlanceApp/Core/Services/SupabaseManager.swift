// Parlance/Core/Services/SupabaseManager.swift
import Foundation
import Supabase

// The Supabase anon key is safe to embed — RLS policies enforce access control server-side.
// It is not a secret; it identifies the project, not a privileged user.
//
// This wrapper is intentionally **not** `@MainActor`. The underlying
// `SupabaseClient` is thread-safe, and isolating the wrapper to the main
// actor previously forced every caller — including non-isolated network
// actors like `APIClient` — into a useless `await MainActor.run { ... }`
// hop just to read the client reference.
final class SupabaseManager: @unchecked Sendable {
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
