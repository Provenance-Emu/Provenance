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
/// Items include root categories, metadata-driven folders, canonical ROM files under **Systems**,
/// and symlink rows under alternate browse axes that point at canonical `game:<md5>` items.
///
/// Leaf game data is always ``Game`` / ``System`` (CPDI); Realm rows cross the boundary only inside ``RomFileProviderLibrary``.
/// Uses `Game` and `System` CPDI structs from `PVPrimitives` so leaf snapshots stay decoupled from Realm.
final class FileProviderItem: NSObject, NSFileProviderItem {

    // MARK: - Kind

    enum Kind {
        /// The virtual root container.
        case root
        /// Top-level browse axis (Systems, Publishers, …).
        case categoryFolder(RomFileProviderRootCategory)
        /// Console folder; parent is usually `cat:systems`.
        case systemFolder(system: System, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// Canonical ROM under a system folder (stable id `game:<md5>`).
        case gameFile(game: Game, romURL: URL?)
        /// Symlink to a canonical game; unique id per parent context.
        case symlinkToGame(game: Game, romURL: URL?, symlinkRawId: String, targetGameMD5: String, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// `pub:<enc>` — one publisher (grouping key).
        case publisherFolder(groupingKey: String, title: String, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// `puball:<enc>` — all games for a publisher.
        case publisherAllGamesFolder(groupingKey: String, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// `pubsys:<enc>:<systemId>` — one system under a publisher.
        case publisherSystemFolder(groupingKey: String, system: System, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// `year:<key>` release-year bucket.
        case yearFolder(yearKey: String, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// `region:<enc>` region bucket.
        case regionFolder(groupingKey: String, title: String, parentItemIdentifier: NSFileProviderItemIdentifier)
        /// `rating:<key>` user-rating bucket.
        case ratingFolder(ratingKey: String, title: String, parentItemIdentifier: NSFileProviderItemIdentifier)
    }

    let kind: Kind

    // MARK: - Init

    /// Creates a root container item.
    init(root: Void = ()) {
        kind = .root
        super.init()
    }

    /// Creates a top-level category folder.
    init(category: RomFileProviderRootCategory) {
        kind = .categoryFolder(category)
        super.init()
    }

    /// Creates a system folder from a `System` CPDI struct and explicit parent.
    init(system: System, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .systemFolder(system: system, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    /// Creates a canonical game ROM item.
    init(game: Game, romURL: URL?) {
        kind = .gameFile(game: game, romURL: romURL)
        super.init()
    }

    /// Creates a symlink row pointing at `game:<targetGameMD5>`.
    init(symlinkTo game: Game, romURL: URL?, symlinkRawId: String, targetGameMD5: String, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .symlinkToGame(game: game, romURL: romURL, symlinkRawId: symlinkRawId, targetGameMD5: targetGameMD5, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    init(publisherFolderGroupingKey groupingKey: String, title: String, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .publisherFolder(groupingKey: groupingKey, title: title, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    init(publisherAllGamesFolderGroupingKey groupingKey: String, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .publisherAllGamesFolder(groupingKey: groupingKey, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    init(publisherSystemFolderGroupingKey groupingKey: String, system: System, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .publisherSystemFolder(groupingKey: groupingKey, system: system, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    init(yearFolder yearKey: String, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .yearFolder(yearKey: yearKey, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    init(regionFolderGroupingKey groupingKey: String, title: String, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .regionFolder(groupingKey: groupingKey, title: title, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    init(ratingFolderKey ratingKey: String, title: String, parentItemIdentifier: NSFileProviderItemIdentifier) {
        kind = .ratingFolder(ratingKey: ratingKey, title: title, parentItemIdentifier: parentItemIdentifier)
        super.init()
    }

    // MARK: - Identifier prefix constants

    /// Prefix used in `NSFileProviderItemIdentifier` raw values for system-folder items.
    static let systemIdentifierPrefix = "system:"
    /// Prefix used in `NSFileProviderItemIdentifier` raw values for canonical game-file items.
    static let gameIdentifierPrefix = "game:"

    // MARK: - NSFileProviderItem

    var itemIdentifier: NSFileProviderItemIdentifier {
        switch kind {
        case .root:
            return .rootContainer
        case .categoryFolder(let cat):
            return NSFileProviderItemIdentifier(cat.rawIdentifier)
        case .systemFolder(let system, _):
            return NSFileProviderItemIdentifier("\(FileProviderItem.systemIdentifierPrefix)\(system.identifier)")
        case .gameFile(let game, _):
            return NSFileProviderItemIdentifier("\(FileProviderItem.gameIdentifierPrefix)\(game.md5)")
        case .symlinkToGame(_, _, let symlinkRawId, _, _):
            return NSFileProviderItemIdentifier(symlinkRawId)
        case .publisherFolder(let groupingKey, _, _):
            return NSFileProviderItemIdentifier(RomFileProviderVirtualPath.publisherFolderPrefix + RomFileProviderVirtualPath.encodeSegment(groupingKey))
        case .publisherAllGamesFolder(let groupingKey, _):
            return NSFileProviderItemIdentifier(RomFileProviderVirtualPath.publisherAllGamesPrefix + RomFileProviderVirtualPath.encodeSegment(groupingKey))
        case .publisherSystemFolder(let groupingKey, let system, _):
            let enc = RomFileProviderVirtualPath.encodeSegment(groupingKey)
            return NSFileProviderItemIdentifier("\(RomFileProviderVirtualPath.publisherSystemPrefix)\(enc):\(system.identifier)")
        case .yearFolder(let yearKey, _):
            return NSFileProviderItemIdentifier("year:\(yearKey)")
        case .regionFolder(let groupingKey, _, _):
            return NSFileProviderItemIdentifier("region:" + RomFileProviderVirtualPath.encodeSegment(groupingKey))
        case .ratingFolder(let ratingKey, _, _):
            return NSFileProviderItemIdentifier("rating:\(ratingKey)")
        }
    }

    var parentItemIdentifier: NSFileProviderItemIdentifier {
        switch kind {
        case .root:
            return .rootContainer
        case .categoryFolder:
            return .rootContainer
        case .systemFolder(_, let parent):
            return parent
        case .gameFile(let game, _):
            return NSFileProviderItemIdentifier("\(FileProviderItem.systemIdentifierPrefix)\(game.systemIdentifier)")
        case .symlinkToGame(_, _, _, _, let parent):
            return parent
        case .publisherFolder(_, _, let parent):
            return parent
        case .publisherAllGamesFolder(_, let parent):
            return parent
        case .publisherSystemFolder(_, _, let parent):
            return parent
        case .yearFolder(_, let parent):
            return parent
        case .regionFolder(_, _, let parent):
            return parent
        case .ratingFolder(_, _, let parent):
            return parent
        }
    }

    var filename: String {
        switch kind {
        case .root:
            return "Provenance"
        case .categoryFolder(let cat):
            return sanitize(cat.folderDisplayName)
        case .systemFolder(let system, _):
            return sanitize(system.name)
        case .gameFile(let game, let romURL):
            if let name = romURL?.lastPathComponent, !name.isEmpty { return sanitize(name) }
            if !game.file.fileName.isEmpty { return sanitize(game.file.fileName) }
            return sanitize(game.title)
        case .symlinkToGame(let game, let romURL, _, _, _):
            if let name = romURL?.lastPathComponent, !name.isEmpty { return sanitize(name) }
            if !game.file.fileName.isEmpty { return sanitize(game.file.fileName) }
            return sanitize(game.title)
        case .publisherFolder(_, let title, _):
            return sanitize(title)
        case .publisherAllGamesFolder:
            return sanitize("All Games")
        case .publisherSystemFolder(_, let system, _):
            return sanitize(system.name)
        case .yearFolder(let yearKey, _):
            return sanitize(yearKey)
        case .regionFolder(_, let title, _):
            return sanitize(title)
        case .ratingFolder(_, let title, _):
            return sanitize(title)
        }
    }

    var contentType: UTType {
        switch kind {
        case .root, .categoryFolder, .systemFolder, .publisherFolder, .publisherAllGamesFolder, .publisherSystemFolder, .yearFolder, .regionFolder, .ratingFolder:
            return .folder
        case .gameFile(let game, let romURL), .symlinkToGame(let game, let romURL, _, _, _):
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
        case .root, .categoryFolder, .publisherFolder, .publisherAllGamesFolder, .publisherSystemFolder, .yearFolder, .regionFolder, .ratingFolder:
            return [.allowsReading, .allowsContentEnumerating]
        case .systemFolder:
            return [.allowsReading, .allowsContentEnumerating, .allowsAddingSubItems]
        case .gameFile, .symlinkToGame:
            return [.allowsReading, .allowsDeleting, .allowsRenaming]
        }
    }

    var itemVersion: NSFileProviderItemVersion {
        switch kind {
        case .root:
            let tag = Data("root".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .categoryFolder(let cat):
            let tag = Data(cat.rawIdentifier.utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .systemFolder(let system, _):
            let contentTag = Data(system.identifier.utf8)
            let metaTag = Data("\(system.identifier)|\(system.name)".utf8)
            return NSFileProviderItemVersion(contentVersion: contentTag, metadataVersion: metaTag)
        case .gameFile(let game, _):
            let contentTag = Data(game.md5.utf8)
            let metaString = "\(game.md5)|\(game.title)|\(game.file.fileName)"
            let metaTag = Data(metaString.utf8)
            return NSFileProviderItemVersion(contentVersion: contentTag, metadataVersion: metaTag)
        case .symlinkToGame(let game, _, let symlinkRawId, let targetMD5, _):
            let contentTag = Data(symlinkRawId.utf8)
            let metaString = "\(targetMD5)|\(symlinkRawId)|\(game.title)|\(game.file.fileName)"
            let metaTag = Data(metaString.utf8)
            return NSFileProviderItemVersion(contentVersion: contentTag, metadataVersion: metaTag)
        case .publisherFolder(let key, let title, _):
            let tag = Data("pub|\(key)|\(title)".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .publisherAllGamesFolder(let key, _):
            let tag = Data("puball|\(key)".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .publisherSystemFolder(let key, let system, _):
            let tag = Data("pubsys|\(key)|\(system.identifier)".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .yearFolder(let yearKey, _):
            let tag = Data("year|\(yearKey)".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .regionFolder(let key, let title, _):
            let tag = Data("region|\(key)|\(title)".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        case .ratingFolder(let key, let title, _):
            let tag = Data("rating|\(key)|\(title)".utf8)
            return NSFileProviderItemVersion(contentVersion: tag, metadataVersion: tag)
        }
    }

    var documentSize: NSNumber? {
        switch kind {
        case .gameFile(let game, _), .symlinkToGame(let game, _, _, _, _):
            return game.file.size > 0 ? NSNumber(value: game.file.size) : nil
        default:
            return nil
        }
    }

    var contentModificationDate: Date? {
        switch kind {
        case .gameFile, .symlinkToGame:
            return _contentModificationDate
        default:
            return nil
        }
    }

    /// Symlink target for alternate browse trees (canonical `game:<md5>`).
    @objc var symlinkTargetItemIdentifier: NSFileProviderItemIdentifier? {
        switch kind {
        case .symlinkToGame(_, _, _, let targetMD5, _):
            return NSFileProviderItemIdentifier("\(FileProviderItem.gameIdentifierPrefix)\(targetMD5)")
        default:
            return nil
        }
    }

    /// Cached content modification date — computed at most once per instance to avoid
    /// repeated filesystem attribute lookups during listing/sorting in Files.app.
    private lazy var _contentModificationDate: Date? = {
        let romURL: URL?
        switch kind {
        case .gameFile(_, let url):
            romURL = url
        case .symlinkToGame(_, let url, _, _, _):
            romURL = url
        default:
            romURL = nil
        }
        guard let romURL = romURL else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: romURL.path)
        return attributes?[.modificationDate] as? Date
    }()

    /// Sanitizes a raw name for safe use as a file provider filename.
    private func sanitize(_ raw: String) -> String {
        let withoutSeparators = raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let withoutControlChars = String(
            withoutSeparators.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        )
        let components = withoutControlChars.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let cleaned = components.joined(separator: " ")
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    // MARK: - Internal helpers

    /// The resolved local URL for the ROM, if available.
    var romURL: URL? {
        switch kind {
        case .gameFile(_, let url):
            return url
        case .symlinkToGame(_, let url, _, _, _):
            return url
        default:
            return nil
        }
    }

    /// Canonical MD5 for symlink resolution (`nil` for non-symlink kinds).
    var symlinkTargetGameMD5: String? {
        if case .symlinkToGame(_, _, _, let md5, _) = kind { return md5 }
        return nil
    }
}
