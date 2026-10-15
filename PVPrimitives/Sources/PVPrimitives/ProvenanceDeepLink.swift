import Foundation

/// Shared constants and helpers for Provenance deep-link URIs.
public enum ProvenanceDeepLink {
    /// Custom URL scheme for app deep links.
    public static let scheme = "provenance"

    /// Host of the open action: `provenance://open?md5=<value>`.
    public static let openHost = "open"

    /// Query item that carries the game MD5 in the custom-scheme open link.
    public static let md5QueryName = "md5"

    /// Universal-link host. Must match `applinks:provenance-emu.com` in the entitlements
    /// and the `apple-app-site-association` file that host serves.
    public static let universalLinkHost = "provenance-emu.com"

    /// Hosts accepted when reading a universal link (the entitlements also list `provenance.app`).
    public static let universalLinkHosts: Set<String> = [universalLinkHost, "provenance.app"]

    /// Path prefix of the public game page, matched by the AASA `/game/*` component.
    public static let gamePathPrefix = "/game/"

    /// Number of hexadecimal characters in an MD5 digest.
    private static let md5HexLength = 32

    /// Deep-link URI for navigating to the library screen.
    public static let libraryScreenURI = "\(scheme)://screen/library"

    /// Returns the canonical library screen deep-link URL.
    public static var libraryScreenURL: URL {
        guard let url = URL(string: libraryScreenURI) else {
            preconditionFailure("Invalid static URI: \(libraryScreenURI)")
        }
        return url
    }

    /// Builds a deep-link URI for opening a game by MD5.
    /// - Parameter md5: MD5 identifier for the game.
    /// - Returns: URI string in `provenance://open?md5=<value>` format.
    public static func openGameMD5URI(_ md5: String) -> String {
        "\(scheme)://\(openHost)?\(md5QueryName)=\(md5)"
    }

    /// Builds the universal link for a game: `https://provenance-emu.com/game/<md5>`.
    ///
    /// Spotlight and Handoff use it as `NSUserActivity.webpageURL`; NFC game tags store it
    /// so that background tag reading can launch the app.
    public static func gameUniversalLink(_ md5: String) -> URL? {
        URL(string: "https://\(universalLinkHost)\(gamePathPrefix)\(md5)")
    }

    /// Returns the game MD5 carried by a Provenance launch URL, or `nil` when the URL is not
    /// a game route. Accepts `provenance://open?md5=<md5>` and
    /// `https://provenance-emu.com/game/<md5>` (also `http` and the `provenance.app` host).
    /// The MD5 must be 32 hex characters and is returned unchanged.
    public static func gameMD5(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlScheme = components.scheme?.lowercased() else { return nil }
        let host = components.host?.lowercased() ?? ""

        let candidate: String?
        if urlScheme == scheme, host == openHost {
            candidate = components.queryItems?.first(where: { $0.name == md5QueryName })?.value
        } else if urlScheme == "https" || urlScheme == "http",
                  universalLinkHosts.contains(host),
                  components.path.hasPrefix(gamePathPrefix) {
            var rest = Substring(components.path.dropFirst(gamePathPrefix.count))
            if rest.hasSuffix("/") { rest = rest.dropLast() }
            candidate = String(rest)
        } else {
            candidate = nil
        }

        guard let md5 = candidate, isMD5(md5) else { return nil }
        return md5
    }

    /// True when `value` is a 32-character hexadecimal string.
    public static func isMD5(_ value: String) -> Bool {
        value.count == md5HexLength && value.allSatisfy(\.isHexDigit)
    }
}
