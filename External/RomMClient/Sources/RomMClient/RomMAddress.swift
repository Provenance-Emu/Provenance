import Foundation

public struct RomMAddress: Hashable, Sendable {
    public let baseURL: URL
    public var isHTTPS: Bool { baseURL.scheme == "https" }

    /// Accepts an instance URL or its /api URL, including a reverse proxy prefix.
    public init(_ address: String) throws {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: value.contains("://") ? value : "https://" + value),
              let scheme = parts.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = parts.host, !host.isEmpty,
              parts.port.map({ (1...65535).contains($0) }) ?? true,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil
        else { throw RomMError.invalidAddress }

        var prefix = parts.percentEncodedPath
        while prefix.last == "/" { prefix.removeLast() }
        if prefix.hasSuffix("/api") { prefix.removeLast(4) }
        if !prefix.isEmpty {
            let segments = prefix.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
            guard segments.allSatisfy({ $0.removingPercentEncoding.map(RomMPath.isComponent) ?? false })
            else { throw RomMError.invalidAddress }
        }
        parts.scheme = scheme
        parts.host = host.lowercased()
        if (scheme == "https" && parts.port == 443) || (scheme == "http" && parts.port == 80) {
            parts.port = nil
        }
        parts.percentEncodedPath = prefix
        guard let base = parts.url else { throw RomMError.invalidAddress }
        baseURL = base
    }

    func endpoint(_ components: [String], query: [URLQueryItem]) throws -> URL {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        guard var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RomMError.invalidAddress
        }
        let encoded = try components.map { component in
            guard RomMPath.isComponent(component),
                  let encoded = component.addingPercentEncoding(withAllowedCharacters: allowed)
            else { throw RomMError.invalidContent }
            return encoded
        }
        parts.percentEncodedPath += "/api/" + encoded.joined(separator: "/")
        parts.queryItems = query.isEmpty ? nil : query
        // Form-style parsers (including FastAPI) interpret an unescaped '+' as a space.
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = parts.url else { throw RomMError.invalidAddress }
        return url
    }
}

enum RomMPath {
    static func isComponent(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".."
            && !value.contains("/") && !value.contains("\\") && !value.contains(":")
            && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
