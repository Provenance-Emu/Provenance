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

    // MARK: - Identifier prefix constants

    /// Prefix used in `NSFileProviderItemIdentifier` raw values for system-folder items.
    static let systemIdentifierPrefix = "system:"
    /// Prefix used in `NSFileProviderItemIdentifier` raw values for game-file items.
    static let gameIdentifierPrefix = "game:"

    // MARK: - NSFileProviderItem

    var itemIdentifier: NSFileProviderItemIdentifier {
        switch kind {
        case .root:
            return .rootContainer
        case .systemFolder(let system):
            return NSFileProviderItemIdentifier("\(FileProviderItem.systemIdentifierPrefix)\(system.identifier)")
        case .gameFile(let game, _):
            return NSFileProviderItemIdentifier("\(FileProviderItem.gameIdentifierPrefix)\(game.md5)")
        }
    }

    var parentItemIdentifier: NSFileProviderItemIdentifier {
        switch kind {
        case .root, .systemFolder:
            return .rootContainer
        case .gameFile(let game, _):
            return NSFileProviderItemIdentifier("\(FileProviderItem.systemIdentifierPrefix)\(game.systemIdentifier)")
        }
    }

    var filename: String {
        switch kind {
        case .root:
            return "Provenance"
        case .systemFolder(let system):
            return sanitize(system.name)
        case .gameFile(let game, let romURL):
            // Prefer the actual on-disk filename; fall back to the CPDI fileName; then a title-based default.
            if let name = romURL?.lastPathComponent, !name.isEmpty { return sanitize(name) }
            if !game.file.fileName.isEmpty { return sanitize(game.file.fileName) }
            return sanitize(game.title)
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
            // Read-only; eviction is not advertised since there is no rehydration path.
            return [.allowsReading]
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
        case .gameFile:
            return _contentModificationDate
        }
    }

    /// Cached content modification date — computed at most once per instance to avoid
    /// repeated filesystem attribute lookups during listing/sorting in Files.app.
    private lazy var _contentModificationDate: Date? = {
        guard case .gameFile(_, let romURL) = kind,
              let romURL = romURL else {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: romURL.path)
        return attributes?[.modificationDate] as? Date
    }()

    /// Sanitizes a raw name for safe use as a file provider filename.
    ///
    /// Removes path separators and control characters throughout the string (not just
    /// at the edges) to avoid Files.app presentation errors or provider failures.
    /// Falls back to "Untitled" if the result is empty after sanitization.
    private func sanitize(_ raw: String) -> String {
        // Replace path separators with a dash.
        let withoutSeparators = raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        // Strip control characters from the entire string (not just edges).
        let withoutControlChars = String(
            withoutSeparators.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        )
        let cleaned = withoutControlChars.trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Untitled" : cleaned
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
