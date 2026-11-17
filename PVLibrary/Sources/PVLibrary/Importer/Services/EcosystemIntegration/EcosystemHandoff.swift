//
//  EcosystemHandoff.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVFileSystem

/// The drop box Provenance, iFly and iCube share on one device.
///
/// All three apps carry the App Group `PVAppGroupId`. Its container is the only
/// storage they can all reach, so it carries games from one app to another with
/// no network and without the sender staying alive: the sender clones the files
/// in, the receiver picks them up whenever it next runs.
///
/// Layout, under `<group container>/Ecosystem/` (version 1, shared with iFly and
/// iCube; iFly's `EcosystemHandoff.swift` holds the same description):
///
///     Apps/<scheme>.json                          EcosystemPresence, one per app
///     Handoff/<recipient scheme>/<id>/            one hand-off, complete
///         manifest.json                           EcosystemHandoffManifest
///         files/<relative path>                   the files, layout preserved
///     Handoff/<recipient scheme>/.<id>.staging/   a hand-off still being written
///
/// - **Presence.** On launch and on every return to the foreground an app
///   rewrites `Apps/<its scheme>.json`. `handoff` is the highest hand-off
///   version it receives (0: none).
/// - **Send.** Only to a peer whose presence says `handoff >= 1` and lists the
///   kind in `accepts`: write `.<id>.staging`, rename it to `<id>`, then open
///   `<recipient>://handoff?id=<id>&from=<own scheme>`.
/// - **Receive.** On launch, on foreground and on the `handoff` URL, take every
///   non-hidden directory in `Handoff/<own scheme>/` whose manifest it
///   understands, move the files into its own library, delete the directory.
///   A newer `version`, an unknown `kind` or another recipient is left alone.
/// - **Clean up.** A sender removes its own hand-offs nobody picked up after
///   `staleAfter`, and staging directories older than `stagingStaleAfter`.
///
/// Scheme names are the directory names, lowercased: `provenance`, `ifly`,
/// `dolphinios` (iCube).
public enum EcosystemHandoff {
    /// Provenance's scheme: its inbox name and the `from` of anything it sends.
    /// Lite registers the same scheme and shares the App Group, so with both
    /// installed whichever runs first takes a hand-off.
    public static let ownScheme = "provenance"

    /// Hand-off version this build reads and writes.
    public static let protocolVersion = 1

    /// The hand-off kind for a game's file set. The only kind in version 1.
    public static let gameKind = "game"

    /// Host of the wake-up URL: `<scheme>://handoff?id=<id>&from=<scheme>`.
    public static let urlHost = "handoff"

    static let rootDirectoryName = "Ecosystem"
    static let appsDirectoryName = "Apps"
    static let handoffDirectoryName = "Handoff"
    static let manifestName = "manifest.json"
    static let filesDirectoryName = "files"
    /// Suffix of a hand-off still being written: `.<id>.staging`.
    static let stagingSuffix = ".staging"

    /// A hand-off nobody picked up is removed by its sender after this long.
    static let staleAfter: TimeInterval = 7 * 24 * 60 * 60

    /// A staging directory this old belongs to a send that died.
    static let stagingStaleAfter: TimeInterval = 60 * 60

    /// `<group container>/Ecosystem`, or nil when this build cannot reach the
    /// group (unsigned simulator run, missing entitlement).
    public static var sharedRoot: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)?
            .appendingPathComponent(rootDirectoryName, isDirectory: true)
    }

    /// `Handoff/<scheme>/`: where hand-offs addressed to `scheme` wait.
    public static func inbox(for scheme: String, root: URL) -> URL {
        root.appendingPathComponent(handoffDirectoryName, isDirectory: true)
            .appendingPathComponent(scheme.lowercased(), isDirectory: true)
    }

    /// `Apps/<scheme>.json`.
    public static func presenceURL(for scheme: String, root: URL) -> URL {
        root.appendingPathComponent(appsDirectoryName, isDirectory: true)
            .appendingPathComponent(scheme.lowercased())
            .appendingPathExtension("json")
    }

    /// Is `url` the wake-up a sender opens after leaving a hand-off for us
    /// (`provenance://handoff?id=…&from=…`)? The query is informational: the
    /// inbox is the source of truth.
    public static func isWakeURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == ownScheme && url.host(percentEncoded: false)?.lowercased() == urlHost
    }

    /// The URL that brings a receiver forward to import hand-off `id`:
    /// `<scheme>://handoff?id=<id>&from=<own scheme>`.
    public static func wakeURL(to scheme: String, id: String, from sender: String = ownScheme) -> URL? {
        var components = URLComponents()
        components.scheme = scheme.lowercased()
        components.host = urlHost
        components.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "from", value: sender)
        ]
        return components.url
    }

    /// JSON as every app in the drop box writes it: ISO 8601 dates without
    /// fractional seconds, which is what `.iso8601` decodes.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Manifest

/// `manifest.json` of one hand-off (see `EcosystemHandoff`). Field names are the
/// wire format shared with iFly and iCube. `kind` and each file's `role` are
/// plain strings so a manifest from a newer app still decodes; the receiver
/// checks `version` and `kind` before acting.
public struct EcosystemHandoffManifest: Codable, Equatable, Sendable {
    public struct File: Codable, Equatable, Sendable {
        /// Path below `files/`, forward slashes, never absolute, no `..`.
        public var path: String
        /// `primaryRole` for a file the receiver adds to its library (a disc image,
        /// an index, an arcade set); `companionRole` for a file one of those needs
        /// beside it (a track, a NAOMI GD-ROM CHD).
        public var role: String
        public var size: Int64

        public init(path: String, role: String, size: Int64) {
            self.path = path
            self.role = role
            self.size = size
        }
    }

    public static let primaryRole = "primary"
    public static let companionRole = "companion"

    public var version: Int
    /// Also the hand-off's directory name.
    public var id: String
    /// Sender's scheme.
    public var from: String
    /// Recipient's scheme.
    public var to: String
    public var created: Date
    public var kind: String
    /// Display title, for the receiver's messages.
    public var title: String
    /// System id as the sender knows it (`dreamcast`, `naomi`, …), a hint only.
    public var system: String?
    /// Lowercase MD5 of the primary file as the sender's library has it.
    public var md5: String?
    public var files: [File]

    public init(
        version: Int, id: String, from: String, to: String, created: Date, kind: String,
        title: String, system: String? = nil, md5: String? = nil, files: [File]
    ) {
        self.version = version
        self.id = id
        self.from = from
        self.to = to
        self.created = created
        self.kind = kind
        self.title = title
        self.system = system
        self.md5 = md5
        self.files = files
    }
}

// MARK: - Presence

/// `Apps/<scheme>.json`: what one app tells its siblings about itself. A sender
/// reads the recipient's entry to choose between a direct hand-off and the share
/// sheet, so iFly and iCube send Provenance games directly only once this exists.
public struct EcosystemPresence: Codable, Equatable, Sendable {
    public var version: Int
    public var scheme: String
    public var bundleID: String
    public var appVersion: String
    public var build: String
    /// Highest hand-off version this app receives. 0: it does not receive.
    public var handoff: Int
    /// Hand-off kinds it receives.
    public var accepts: [String]
    /// System ids it takes games for. Empty: any system.
    public var systems: [String]
    public var updated: Date

    public init(
        version: Int, scheme: String, bundleID: String, appVersion: String, build: String,
        handoff: Int, accepts: [String], systems: [String], updated: Date
    ) {
        self.version = version
        self.scheme = scheme
        self.bundleID = bundleID
        self.appVersion = appVersion
        self.build = build
        self.handoff = handoff
        self.accepts = accepts
        self.systems = systems
        self.updated = updated
    }

    /// Can this app take a hand-off of `kind` for `system`? It must receive
    /// version 1 or later, list the kind, and either take any system (`systems`
    /// empty) or list this one.
    public func accepts(kind: String, system: String?) -> Bool {
        guard handoff >= 1, accepts.contains(kind) else { return false }
        if let system, !systems.isEmpty {
            return systems.contains(system)
        }
        return true
    }

    /// Provenance's own entry: receives version-1 game hand-offs for any system.
    public static func own(now: Date = Date(), bundle: Bundle = .main) -> EcosystemPresence {
        let info = bundle.infoDictionary ?? [:]
        return EcosystemPresence(
            version: EcosystemHandoff.protocolVersion,
            scheme: EcosystemHandoff.ownScheme,
            bundleID: bundle.bundleIdentifier ?? "",
            appVersion: info["CFBundleShortVersionString"] as? String ?? "",
            build: info["CFBundleVersion"] as? String ?? "",
            handoff: EcosystemHandoff.protocolVersion,
            accepts: [EcosystemHandoff.gameKind],
            systems: [],
            updated: now
        )
    }

    /// The entry `scheme` last wrote, or nil when it never has.
    public static func read(scheme: String, root: URL) -> EcosystemPresence? {
        guard let data = try? Data(contentsOf: EcosystemHandoff.presenceURL(for: scheme, root: root)) else {
            return nil
        }
        return try? EcosystemHandoff.decoder().decode(EcosystemPresence.self, from: data)
    }

    public func write(root: URL, fileManager: FileManager = .default) throws {
        let url = EcosystemHandoff.presenceURL(for: scheme, root: root)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try EcosystemHandoff.encoder().encode(self).write(to: url, options: .atomic)
    }
}
