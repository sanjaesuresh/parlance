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

    /// Marketing homepage. Used as the invite landing target until a
    /// dedicated /invite page exists.
    static let home: URL = URL(string: host)!

    /// Universal-link target used in Supabase password-recovery emails.
    /// Matches the AASA component `/reset-password*` hosted at this host.
    static let passwordReset: URL = URL(string: "\(host)/reset-password")!
}
