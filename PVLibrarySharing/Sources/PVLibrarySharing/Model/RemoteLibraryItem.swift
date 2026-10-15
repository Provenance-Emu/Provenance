//
//  RemoteLibraryItem.swift
//  PVLibrarySharing
//
//  One normalised model for a game in another app's library.
//

import Foundation
import PVSystems

/// A game offered by a peer, normalised across dialects.
public struct RemoteLibraryItem: Sendable, Hashable, Identifiable {
    /// The dialect's own id, treated as opaque: iFly's `Game.id`
    /// (`md5`, or `title|platform|sizeBytes`), iCube's `stableKey`.
    /// Phase 2 sends it back unchanged (`pull {gameId}`, `manifest?key=`).
    public var id: String
    public var title: String
    /// The peer's raw platform value, kept for display when it doesn't map.
    public var platform: String
    /// nil when Provenance has no system for `platform`.
    public var systemIdentifier: SystemIdentifier?
    /// Lower-case hex MD5 when the peer has hashed the file.
    public var md5: String?
    public var sizeBytes: Int64
    /// Key for `LibrarySource.artwork(for:)`; nil when the peer has no art.
    public var artKey: String?
    public var source: PeerApp

    // iCube identity fallbacks (spec §3.4); nil for iFly.
    public var gameID: String?
    public var discNumber: Int?
    public var revision: Int?

    public init(
        id: String,
        title: String,
        platform: String,
        systemIdentifier: SystemIdentifier?,
        md5: String?,
        sizeBytes: Int64,
        artKey: String?,
        source: PeerApp,
        gameID: String? = nil,
        discNumber: Int? = nil,
        revision: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.systemIdentifier = systemIdentifier
        self.md5 = md5.map { $0.lowercased() }
        self.sizeBytes = sizeBytes
        self.artKey = artKey
        self.source = source
        self.gameID = gameID
        self.discNumber = discNumber
        self.revision = revision
    }

    /// True when Provenance can play this item's system.
    public var isSupported: Bool { systemIdentifier != nil }
}

/// A peer's whole shared library.
public struct RemoteCatalogue: Sendable, Hashable {
    /// The name the peer reports for itself (`deviceName` / `sourceDevice.name`).
    public var deviceName: String
    public var items: [RemoteLibraryItem]
    public var source: PeerApp

    public init(deviceName: String, items: [RemoteLibraryItem], source: PeerApp) {
        self.deviceName = deviceName
        self.items = items
        self.source = source
    }

    /// Items whose system Provenance supports. Peers that predate the v1.1
    /// `systemIdentifier` filter return everything, so clients always filter
    /// locally (spec §3.2).
    public var supportedItems: [RemoteLibraryItem] {
        items.filter(\.isSupported)
    }

    /// Distinct supported systems, sorted.
    public var systems: [SystemIdentifier] {
        Set(items.compactMap(\.systemIdentifier)).sorted()
    }

    /// Keeps only the items whose system is in `playable`.
    public func filtered(to playable: Set<SystemIdentifier>) -> RemoteCatalogue {
        var copy = self
        copy.items = items.filter { item in
            guard let system = item.systemIdentifier else { return false }
            return playable.contains(system)
        }
        return copy
    }
}
