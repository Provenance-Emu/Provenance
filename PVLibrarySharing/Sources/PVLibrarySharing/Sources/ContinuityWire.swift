//
//  ContinuityWire.swift
//  PVLibrarySharing
//
//  Wire types and routes of the continuity library contract, as iFly and
//  iCube ship it today. Field names are copied from
//  iFly  ContinuityKit/Model/ContinuityLibraryManifest.swift,
//        ContinuityKit/Server/ContinuityLibraryMessages.swift
//  iCube PVContinuity/Model/ContinuityLibraryCatalog.swift,
//        PVContinuity/Model/GameIdentity.swift,
//        PVContinuity/Trust/ContinuityPairingMessages.swift.
//  `Data` fields travel as base64 strings (Codable's default) in both apps.
//

import Foundation

/// Route paths. Both apps share the prefix; the meaning of
/// `library/manifest` differs (iFly: whole catalogue, iCube: one game).
enum ContinuityRoutes {
    static let libraryAuthStart = "/api/continuity/library/auth/start"
    static let libraryAuthComplete = "/api/continuity/library/auth/complete"
    static let libraryArt = "/api/continuity/library/art"
    /// iFly only: the whole catalogue.
    static let iFlyLibraryManifest = "/api/continuity/library/manifest"
    /// iCube only: the whole catalogue.
    static let iCubeLibraryCatalog = "/api/continuity/library/catalog"
    /// iCube pairing; exists from app launch, independent of sharing.
    static let pairStart = "/api/continuity/pair/start"
    static let pairComplete = "/api/continuity/pair/complete"

    static let keyQueryItem = "key"

    /// `base + path`, with `?key=` built through `URLComponents` like both
    /// peers do, so `+`, `|`, `:` and spaces in opaque keys survive.
    static func url(base: URL, path: String, key: String? = nil) -> URL {
        let joined = base.appendingPathComponent(path)
        guard let key else { return joined }
        var components = URLComponents(url: joined, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: keyQueryItem, value: key)]
        return components?.url ?? joined
    }
}

// MARK: - Shared auth messages

struct AuthStartResponse: Codable, Sendable {
    var authId: String
    var serverId: String
    var nonce: Data
}

struct AuthCompleteRequest: Codable, Sendable {
    var authId: String
    var peerId: String
    var signature: Data
}

struct LibraryTokenResponse: Codable, Sendable {
    var libraryToken: String
}

// MARK: - iFly

/// iFly's `AuthStartRequest`: name and key travel up front so an undecided
/// host can show its consent prompt and trust the peer on first use.
struct IFlyAuthStartRequest: Codable, Sendable {
    var peerId: String
    var name: String
    var publicKey: Data
    var icloudHash: String?
}

/// iFly's `ContinuityLibraryManifest`. Unknown fields are ignored, and the
/// owner-side fields (`lastPlayedDate`, `playCount`, `favorite`, `addedDate`,
/// `saveStateCount`, `vmuFileCount`) are deliberately not decoded: phase 1
/// doesn't show them, and iFly encodes its dates with the default strategy
/// (seconds since 2001), which a later reader must keep in mind.
struct IFlyLibraryManifest: Codable, Sendable {
    var version: Int
    var peerId: String
    var deviceName: String
    var games: [Game]
    var catalogVersion: String?

    struct Game: Codable, Sendable {
        var title: String
        var platform: String
        var md5: String?
        var sizeBytes: Int64
        var artKey: String?

        /// iFly's `Game.id`: computed, never sent. Phase 2's `pull {gameId}`
        /// must send exactly this string.
        var id: String { md5 ?? "\(title)|\(platform)|\(sizeBytes)" }
    }
}

// MARK: - iCube

struct ICubeAuthStartRequest: Codable, Sendable {
    var peerId: String
}

struct ICubePairStartRequest: Codable, Sendable {
    var peerId: String
    var name: String
    var publicKey: Data
}

struct ICubePairStartResponse: Codable, Sendable {
    var pairingId: String
    var serverId: String
    var serverName: String
    var serverPublicKey: Data
}

struct ICubePairCompleteRequest: Codable, Sendable {
    var pairingId: String
    var proof: Data
}

/// iCube's `ContinuityLibraryCatalog`. iCube rejects any version outside
/// 1...1 on decode, so this client does too.
struct ICubeLibraryCatalog: Codable, Sendable {
    static let supportedVersions: ClosedRange<Int> = 1...1

    var version: Int
    var sourceDevice: SourceDevice
    var entries: [Entry]

    struct SourceDevice: Codable, Sendable {
        var name: String
        var platform: String
        var appVersion: String
    }

    struct Entry: Codable, Sendable {
        var key: String
        var game: GameIdentity
        var sizeBytes: Int64
        var hasArtwork: Bool
    }

    struct GameIdentity: Codable, Sendable {
        var gameID: String?
        var md5: String?
        var crc32: String?
        var displayName: String
        var platform: String
        var discNumber: Int?
        var revision: Int?
    }
}
