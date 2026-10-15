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
    /// iFly only: `POST {gameId}` → one game's pull manifest. Metered on the host.
    static let iFlyLibraryPull = "/api/continuity/library/pull"
    /// iCube only: `GET ?key=` → one game's pull manifest (same path as iFly's
    /// catalogue, different meaning).
    static let iCubeLibraryManifest = "/api/continuity/library/manifest"
    /// Both: one file of a granted manifest. iFly `?path=`, iCube `?key=&path=`.
    static let libraryFile = "/api/continuity/library/file"
    /// iCube pairing; exists from app launch, independent of sharing.
    static let pairStart = "/api/continuity/pair/start"
    static let pairComplete = "/api/continuity/pair/complete"

    static let keyQueryItem = "key"
    static let pathQueryItem = "path"

    /// `base + path`, with `?key=` built through `URLComponents` like both
    /// peers do, so `+`, `|`, `:` and spaces in opaque keys survive.
    static func url(base: URL, path: String, key: String? = nil) -> URL {
        let joined = base.appendingPathComponent(path)
        guard let key else { return joined }
        var components = URLComponents(url: joined, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: keyQueryItem, value: key)]
        return components?.url ?? joined
    }

    /// `base + library/file`: iFly sends `?path=` only, iCube `?key=&path=`
    /// (it re-checks the entry's exclusion before serving a byte).
    static func libraryFileURL(base: URL, key: String?, relativePath: String) -> URL {
        let joined = base.appendingPathComponent(libraryFile)
        var components = URLComponents(url: joined, resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []
        if let key { items.append(URLQueryItem(name: keyQueryItem, value: key)) }
        items.append(URLQueryItem(name: pathQueryItem, value: relativePath))
        components?.queryItems = items
        return components?.url ?? joined
    }
}

// MARK: - Pull manifest (both apps)

/// The fields of iFly's and iCube's `ContinuityManifest` a pull needs.
///
/// Lenient on purpose: `mintedAt`, `sourceDevice`, `game`, `saveState` and
/// `optionalExtras` are not decoded (Provenance never copies a peer's state,
/// and iFly's library manifests carry a `game` identity shaped differently
/// from iCube's). The version is still checked: both apps reject anything
/// outside 1...1. iCube has no `bios` key at all, so it is optional here; iFly
/// always sends it.
struct ContinuityPullManifest: Decodable, Sendable {
    static let supportedVersions: ClosedRange<Int> = 1...1

    var version: Int
    var files: [Descriptor]
    var bios: [Descriptor]?

    /// `FileDescriptor` in both apps. `required` is always encoded by both.
    struct Descriptor: Codable, Sendable {
        var kind: String
        var relativePath: String
        var sha256: String
        var size: Int64
        var required: Bool?
    }

    enum CodingKeys: String, CodingKey {
        case version, files, bios
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard Self.supportedVersions.contains(version) else {
            throw LibrarySharingError.unsupportedCatalogueVersion(version)
        }
        self.version = version
        self.files = try container.decode([Descriptor].self, forKey: .files)
        self.bios = try container.decodeIfPresent([Descriptor].self, forKey: .bios)
    }

    func remoteManifest(itemId: String) -> RemoteManifest {
        let all = files + (bios ?? [])
        return RemoteManifest(itemId: itemId, files: all.map {
            RemoteFile(kind: $0.kind, relativePath: $0.relativePath, sha256: $0.sha256, size: $0.size, required: $0.required ?? true)
        })
    }
}

/// iFly's `ContinuityLibraryMessages.PullRequest`.
struct IFlyPullRequest: Codable, Sendable {
    var gameId: String
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
