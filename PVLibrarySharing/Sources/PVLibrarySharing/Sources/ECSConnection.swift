import Foundation

/// Canonical server origins keep credentials scoped to one HTTP endpoint.
public enum ECSConnection {
    public static func origin(for address: String) throws -> URL {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = address.contains("://") ? address : "http://" + address
        guard var parts = URLComponents(string: value), let scheme = parts.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/" else {
            throw LibrarySharingError.unsupportedServer("Enter a server address without a path or credentials.")
        }
        parts.scheme = scheme
        parts.host = host.lowercased()
        parts.path = ""
        if parts.port == nil, scheme == "http" { parts.port = 8473 }
        guard let url = parts.url, parts.port.map({ (1...65535).contains($0) }) ?? true else {
            throw LibrarySharingError.unsupportedServer("Invalid server port.")
        }
        return url
    }
}
