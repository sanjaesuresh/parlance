// Centralized marketing / support URLs used by sheets, links, and the
// paywall. Reduces the ten-or-so `URL(string: "https://theparlance.app/...")!`
// force-unwraps scattered across feature views and gives a single place to
// flip the marketing host or migrate to universal links.
//
// The literals here are all known-good and parse via `URL.init(string:)`,
// so the implicit-unwrap in the static computation is safe. Adding a new
// surface? Add it here, never `URL(string:)!` it inline.
import Foundation

enum AppURLs {
    private static let host = "https://theparlance.app"

    static let privacy: URL = URL(string: "\(host)/privacy")!
    static let support: URL = URL(string: "\(host)/support")!

    /// Apple's standard EULA. Used on the Pro paywall to satisfy App Store
    /// Guideline 3.1.2(a) without maintaining our own Terms of Use page.
    static let standardEULA: URL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Profile invite link with the inviter's username appended as a
    /// percent-encoded query parameter.
    static func invite(username: String) -> URL {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        // The path + scheme are static; only the query param is interpolated,
        // and addingPercentEncoding has already neutralized any unsafe chars.
        return URL(string: "\(host)/invite?user=\(encoded)") ?? URL(string: "\(host)/invite")!
    }
}
