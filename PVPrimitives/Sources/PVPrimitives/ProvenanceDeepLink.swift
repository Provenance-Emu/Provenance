import Foundation

/// Shared constants and helpers for Provenance deep-link URIs.
public enum ProvenanceDeepLink {
    /// Custom URL scheme for app deep links.
    public static let scheme = "provenance"

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
        "\(scheme)://open?md5=\(md5)"
    }
}
