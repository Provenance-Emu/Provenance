import Foundation

public enum RomMCredential: Codable, Sendable {
    case none
    case token(String)
    case basic(username: String, password: String)

    func authorization() throws -> String? {
        switch self {
        case .none:
            return nil
        case let .token(token):
            guard !token.isEmpty, token.utf8.allSatisfy({ (33...126).contains($0) }) else {
                throw RomMError.invalidCredential
            }
            return "Bearer " + token
        case let .basic(username, password):
            guard !username.isEmpty, !username.contains(":"), !password.isEmpty else {
                throw RomMError.invalidCredential
            }
            return "Basic " + Data((username + ":" + password).utf8).base64EncodedString()
        }
    }
}

/// Login material serialized by an app into its own secure credential store.
public struct RomMSavedLogin: Codable, Sendable {
    public let credential: RomMCredential
    public let allowHTTP: Bool

    public init(credential: RomMCredential, allowHTTP: Bool) {
        self.credential = credential
        self.allowHTTP = allowHTTP
    }

    public init?(storedValue: String) {
        guard let login = try? JSONDecoder().decode(Self.self, from: Data(storedValue.utf8)) else { return nil }
        self = login
    }

    public func storedValue() throws -> String {
        String(decoding: try JSONEncoder().encode(self), as: UTF8.self)
    }
}

public enum RomMError: LocalizedError, Equatable {
    case invalidAddress
    case invalidCredential
    case insecureConnection
    case accessDenied
    case invalidResponse
    case invalidContent
    case unavailable
    case status(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress: "Enter a valid RomM server address."
        case .invalidCredential: "Enter a valid RomM credential."
        case .insecureConnection: "Use HTTPS or allow sending credentials over HTTP for this server."
        case .accessDenied: "RomM denied access. Check your credentials and library permissions."
        case .invalidResponse: "The server returned an unexpected RomM response."
        case .invalidContent: "The RomM download is incomplete or contains invalid file paths."
        case .unavailable: "This game is no longer available on RomM."
        case let .status(code): "RomM returned HTTP \(code)."
        }
    }
}

public struct RomMPlatform: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let slug: String
    public let fsSlug: String?
    public let name: String
    public let displayName: String?
    public let romCount: Int

    public var title: String { displayName.flatMap { $0.isEmpty ? nil : $0 } ?? name }
    public var identifiers: [String] { [slug, fsSlug].compactMap { $0?.lowercased() } }
}

public struct RomMGame: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String?
    public let fsName: String
    public let platformId: Int
    public let platformSlug: String
    public let fsSizeBytes: Int64
    public let hasFileOnDisk: Bool?
    public let missingFromFs: Bool?
    public let isPhysical: Bool?

    public var title: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? fsName }
    public var isDownloadable: Bool {
        hasFileOnDisk ?? (missingFromFs != true && isPhysical != true && fsSizeBytes > 0)
    }
}

public struct RomMPage: Decodable, Sendable {
    public let items: [RomMGame]
    public let total: Int
    public let limit: Int
    public let offset: Int

    public var nextOffset: Int? {
        guard offset >= 0, total > offset, !items.isEmpty, items.count < total - offset else { return nil }
        return offset + items.count
    }
}

/// The caller owns the staging directory and removes it after importing.
public struct RomMDownload: Sendable {
    public let directory: URL
    public let files: [URL]
}
