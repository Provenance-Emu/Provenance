//
//  FileProviderItem.swift
//  ROM File Provider
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import FileProvider
import UniformTypeIdentifiers
import PVPrimitives

/// A virtual item surfaced by the Provenance ROM library file provider.
///
/// Items represent one of three kinds:
/// - **Root** — the virtual root container (read-only folder)
/// - **System folder** — one per game console that has at least one locally-present ROM
/// - **Game ROM file** — an individual ROM file nested inside its system folder
///
/// Uses `Game` and `System` CPDI structs from `PVPrimitives` so the item is
/// completely decoupled from Realm — safe to pass across threads and to store
/// as a snapshot.
final class FileProviderItem: NSObject, NSFileProviderItem {

    // MARK: - Kind

    enum Kind {
        /// The virtual root container.
        case root
        /// A system folder grouping ROMs for one game console.
        case systemFolder(system: System)
        /// A single ROM file.  `romURL` is the resolved on-disk URL (may be nil when
        /// the file has not been downloaded locally).
        case gameFile(game: Game, romURL: URL?)
    }

    let kind: Kind

    // MARK: - Init

    /// Creates a root container item.
    init(root: Void = ()) {
        kind = .root
        super.init()
    }

    /// Creates a system folder item from a `System` CPDI struct.
    init(system: System) {
        kind = .systemFolder(system: system)
        super.init()
    }

    /// Creates a game ROM item from a `Game` CPDI struct and an optional resolved file URL.
    init(game: Game, romURL: URL?) {
        kind = .gameFile(game: game, romURL: romURL)
        super.init()
    }

    // MARK: - NSFileProviderItem

    var itemIdentifier: NSFileProviderItemIdentifier {
        switch kind {
        case .root:
            return .rootContainer
        case .systemFolder(let system):
            return NSFileProviderItemIdentifier("system:\(system.identifier)")
        case .gameFile(let game, _):
            return NSFileProviderItemIdentifier("game:\(game.md5)")
        }
    }

    var parentItemIdentifier: NSFileProviderItemIdentifier {
        switch kind {
        case .root, .systemFolder:
            return .rootContainer
        case .gameFile(let game, _):
            return NSFileProviderItemIdentifier("system:\(game.systemIdentifier)")
        }
    }

    var filename: String {
        switch kind {
        case .root:
            return "Provenance"
        case .systemFolder(let system):
            return system.name
        case .gameFile(let game, let romURL):
            // Prefer the actual on-disk filename; fall back to the CPDI fileName; then a title-based default.
            if let name = romURL?.lastPathComponent, !name.isEmpty { return name }
            if !game.file.fileName.isEmpty { return game.file.fileName }
            return game.title
        }
    }

    var contentType: UTType {
        switch kind {
        case .root, .systemFolder:
            return .folder
        case .gameFile(let game, let romURL):
            let ext = romURL?.pathExtension ?? ""
            if !ext.isEmpty { return ROMContentType.contentType(forExtension: ext) }
            let fileNameExt = (game.file.fileName as NSString).pathExtension
            if !fileNameExt.isEmpty { return ROMContentType.contentType(forExtension: fileNameExt) }
            let displayExt = (filename as NSString).pathExtension
            return ROMContentType.contentType(forExtension: displayExt)
        }
    }

    var capabilities: NSFileProviderItemCapabilities {
        switch kind {
        case .root, .systemFolder:
            // allowsContentEnumerating is required for Files.app to treat these as browsable containers.
            return [.allowsReading, .allowsContentEnumerating]
        case .gameFile:
            // Read-only; eviction allowed so the system can reclaim space.
            return [.allowsReading, .allowsEvicting]
        }
    }

    var itemVersion: NSFileProviderItemVersion {
        switch kind {
        case .root:
            let tag = Data("root".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .systemFolder(let system):
            let tag = Data(system.identifier.utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .gameFile(let game, _):
            // Content version: the ROM's md5 hash — stable content identity.
            let contentTag = Data(game.md5.utf8)
            // Metadata version: incorporates title and filename so that renames or
            // metadata updates are detected by Files.app (not just content changes).
            let metaString = "\(game.md5)|\(game.title)|\(game.file.fileName)"
            let metaTag = Data(metaString.utf8)
            return NSFileProviderItemVersion(contentVersion: contentTag, metadataVersion: metaTag)
        }
    }

    var documentSize: NSNumber? {
        switch kind {
        case .root, .systemFolder:
            return nil
        case .gameFile(let game, _):
            return game.file.size > 0 ? NSNumber(value: game.file.size) : nil
        }
    }

    var contentModificationDate: Date? {
        switch kind {
        case .root, .systemFolder:
            return nil
        case .gameFile(_, let romURL):
            guard let romURL = romURL else { return nil }
            let attributes = try? FileManager.default.attributesOfItem(atPath: romURL.path)
            return attributes?[.modificationDate] as? Date
        }
    }

    // MARK: - Internal helpers

    /// The resolved local URL for the ROM, if available.
    var romURL: URL? {
        switch kind {
        case .root, .systemFolder:
            return nil
        case .gameFile(_, let url):
            return url
        }
    }
}
