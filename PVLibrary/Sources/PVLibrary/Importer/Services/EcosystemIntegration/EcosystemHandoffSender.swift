//
//  EcosystemHandoffSender.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVSystems

/// Decides whether a game in Provenance's library can go straight to a sibling
/// app through the drop box (see `EcosystemHandoff`), and sends it.
///
/// Only iCube is a target today: GameCube and Wii disc images. A game goes
/// direct only when every one of these holds, otherwise the caller keeps its
/// usual behaviour:
/// - its system maps to a sibling (`target(for:)`),
/// - that sibling is installed (the caller's `canOpenURL`, which needs the
///   scheme in `LSApplicationQueriesSchemes`),
/// - the sibling's presence entry takes a `game` for that system id,
/// - the library file is one the sibling imports (an archive or `.m3u` is not).
public enum EcosystemHandoffSender {
    /// A sibling app Provenance sends games to, and the hand-off system id it
    /// publishes for the game's system.
    public struct Target: Equatable, Sendable {
        public let app: EcosystemApp
        public let systemID: String
    }

    /// What the caller knows about the game, read from the library on its own
    /// thread; no Realm object crosses into the send.
    public struct Game: Equatable, Sendable {
        public let title: String
        public let system: SystemIdentifier
        public let md5: String?
        /// The library file: the disc image itself.
        public let file: URL

        public init(title: String, system: SystemIdentifier, md5: String?, file: URL) {
            self.title = title
            self.system = system
            self.md5 = md5
            self.file = file
        }
    }

    /// A send that can go direct: where to and which file.
    public struct Route: Equatable, Sendable {
        public let target: Target
        /// `Game.file` with symbolic links resolved; the receivers refuse links.
        public let file: URL
    }

    /// What `send` left in the drop box.
    public struct Sent: Equatable, Sendable {
        public let manifest: EcosystemHandoffManifest
        /// Open this to bring the sibling forward. Nil only for a scheme that
        /// cannot form a URL, which none of the targets is.
        public let wakeURL: URL?
    }

    /// Disc images iCube imports. Anything else (zip, 7z, m3u) it refuses.
    static let iCubeExtensions: Set<String> = [
        "iso", "gcm", "tgc", "wbfs", "gcz", "ciso", "rvz", "wad", "dol", "elf", "nkit", "wia", "img", "bin"
    ]

    /// The sibling that takes games of `system`, with the id it publishes for it.
    public static func target(for system: SystemIdentifier) -> Target? {
        switch system {
        case .GameCube: return Target(app: .icube, systemID: "gamecube")
        case .Wii: return Target(app: .icube, systemID: "wii")
        default: return nil
        }
    }

    /// File extensions `app` imports from a hand-off; nil for an app Provenance
    /// does not send to.
    static func acceptedExtensions(for app: EcosystemApp) -> Set<String>? {
        switch app {
        case .icube: return iCubeExtensions
        case .ifly, .xenios, .melonx, .meloCafe: return nil
        }
    }

    /// The direct route for `game`, or nil when it must take the usual path.
    /// Reads the sibling's presence entry and stats the file: run it off the
    /// main thread. `isInstalled` is the caller's `canOpenURL` answer.
    public static func route(
        for game: Game,
        isInstalled: (EcosystemApp) -> Bool,
        root: URL?,
        fileManager: FileManager = .default
    ) -> Route? {
        guard let target = target(for: game.system),
              let extensions = acceptedExtensions(for: target.app),
              let root = root,
              isInstalled(target.app),
              let presence = EcosystemPresence.read(scheme: target.app.urlScheme, root: root),
              presence.accepts(kind: EcosystemHandoff.gameKind, system: target.systemID)
        else { return nil }

        let file = game.file.resolvingSymlinksInPath()
        guard extensions.contains(file.pathExtension.lowercased()),
              (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
        else { return nil }
        return Route(target: target, file: file)
    }

    /// Stages `game` for `route` and returns the manifest and the URL to open.
    /// Copies the disc image (a clone on APFS): run it off the main thread.
    public static func send(
        _ game: Game,
        via route: Route,
        root: URL,
        id: String = UUID().uuidString,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> Sent {
        let entry = EcosystemHandoffStager.Entry(
            source: route.file,
            relativePath: route.file.lastPathComponent,
            role: EcosystemHandoffManifest.primaryRole
        )
        let scheme = route.target.app.urlScheme
        let manifest = try EcosystemHandoffStager.stage(
            [entry],
            to: scheme,
            title: game.title,
            system: route.target.systemID,
            md5: game.md5,
            root: root,
            id: id,
            now: now,
            fileManager: fileManager
        )
        return Sent(manifest: manifest, wakeURL: EcosystemHandoff.wakeURL(to: scheme, id: id))
    }
}
