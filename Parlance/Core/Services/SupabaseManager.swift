import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""
        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }
}
