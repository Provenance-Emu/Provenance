//
//  ServerWire.swift
//  PVLibrarySharing
//
//  What Provenance sends when it answers an iFly or iCube client. Field names,
//  optionality and encoder settings copied from each app's model so the
//  peer's own decoder accepts them unchanged:
//  iFly  ContinuityKit/Model/{ContinuityLibraryManifest,ContinuityManifest,
//        FileDescriptor,GameIdentity,SourceDevice}.swift
//  iCube PVContinuity/Model/{ContinuityLibraryCatalog,ContinuityManifest,
//        FileDescriptor,GameIdentity}.swift
//

import CryptoKit
import Foundation
import PVSystems

struct WireSourceDevice: Codable, Sendable, Equatable {
    var name: String
    var platform: String
    var appVersion: String

    init(_ device: HostDevice) {
        name = device.name
        platform = device.platform
        appVersion = device.appVersion
    }
}

/// Both apps' `FileDescriptor`. `required` is always sent: iFly decodes it as
/// a non-optional Bool. `modifiedAt` is left out (optional on both).
struct WireFileDescriptor: Codable, Sendable, Equatable {
    var kind: String
    var relativePath: String
    var sha256: String
    var size: Int64
    var required: Bool
}

// MARK: - iFly

/// iFly's `ContinuityLibraryManifest`, encoded with a plain `JSONEncoder` as
/// iFly does. `saveStateCount` is non-optional in iFly's decoder.
struct IFlyWireLibraryManifest: Codable, Sendable {
    var version = 1
    var peerId: String
    var deviceName: String
    var games: [Game]
    var catalogVersion: String?

    struct Game: Codable, Sendable, Equatable {
        var title: String
        var platform: String
        var md5: String?
        var sizeBytes: Int64
        var artKey: String?
        var saveStateCount: Int

        /// iFly's `Game.id`, which a `pull {gameId}` sends back.
        var id: String { md5 ?? "\(title)|\(platform)|\(sizeBytes)" }
    }

    /// `"v1-" + sha256` over the sorted games, the shape of iFly's
    /// `computeVersion` (Provenance sends no owner-side fields, so those terms
    /// are empty). Only Provenance compares it, as its own ETag.
    static func version(of games: [Game]) -> String {
        var input = ""
        for game in games.sorted(by: { $0.id < $1.id }) {
            input += "\(game.id)|\(game.sizeBytes)||0|0|0|\(game.artKey ?? "")\n"
        }
        return "v1-" + FileSHA256.hex(of: Data(input.utf8))
    }
}

/// iFly's `GameIdentity` (platform is a lower-case slug here).
struct IFlyWireGameIdentity: Codable, Sendable {
    var md5Hash: String?
    var displayName: String
    var platform: String
}

/// iFly's `ContinuityManifest` for a library pull: `bios` and
/// `optionalExtras` are non-optional arrays in iFly's decoder, so they are
/// always sent, empty. The receiver boots the first `gameFile`, so the
/// primary file comes first.
struct IFlyWirePullManifest: Encodable, Sendable {
    var version = 1
    var sessionId: String
    var mintedAt: Date
    var sourceDevice: WireSourceDevice
    var game: IFlyWireGameIdentity
    var files: [WireFileDescriptor]
    var bios: [WireFileDescriptor] = []
    var optionalExtras: [WireFileDescriptor] = []

    /// iFly's `ContinuityManifest.encoded()`: ISO 8601 dates, sorted keys.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - iCube

/// iCube's `GameIdentity`. `stableKey` must match iCube's byte for byte.
struct ICubeWireGameIdentity: Codable, Sendable, Equatable {
    var gameID: String?
    var md5: String?
    var crc32: String?
    var displayName: String
    var platform: String
    var discNumber: Int?
    var revision: Int?

    var stableKey: String {
        if let gameID, !gameID.isEmpty {
            return "id:\(gameID)|d\(discNumber ?? 0)|r\(revision ?? -1)"
        }
        if let md5, !md5.isEmpty { return "md5:\(md5)" }
        return "name:\(displayName)|\(platform)"
    }
}

struct ICubeWireCatalog: Codable, Sendable {
    var version = 1
    var sourceDevice: WireSourceDevice
    var entries: [Entry]

    struct Entry: Codable, Sendable {
        var key: String
        var game: ICubeWireGameIdentity
        var sizeBytes: Int64
        var hasArtwork: Bool
    }
}

/// iCube's `ContinuityManifest`: no `bios`, no `optionalExtras`.
struct ICubeWireManifest: Encodable, Sendable {
    var version = 1
    var sessionId: String
    var mintedAt: Date
    var sourceDevice: WireSourceDevice
    var game: ICubeWireGameIdentity
    var files: [WireFileDescriptor]
}

/// Both iCube encoders: ISO 8601 dates and sorted keys.
func iCubeEncoded<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

extension FileSHA256 {
    static func hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Platform strings

extension SystemMap {
    /// The wire platform a dialect uses for `system`, or nil when the dialect
    /// doesn't serve it. iFly catalogues use display names; its pull manifests
    /// use lower-case slugs. iCube uses `gc` / `wii`.
    static func wirePlatform(for system: SystemIdentifier, app: PeerApp, slug: Bool = false) -> String? {
        switch (app, system) {
        case (.iFly, .Dreamcast): return slug ? "dreamcast" : "Dreamcast"
        case (.iFly, .NAOMI): return slug ? "naomi" : "Naomi"
        case (.iFly, .NAOMI2): return slug ? "naomi2" : "Naomi 2"
        case (.iFly, .Atomiswave): return slug ? "atomiswave" : "Atomiswave"
        case (.iCube, .GameCube): return "gc"
        case (.iCube, .Wii): return "wii"
        default: return nil
        }
    }
}
