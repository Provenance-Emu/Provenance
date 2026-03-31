//
//  FileProviderExtension.swift
//  ROM File Provider
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import CryptoKit
import Foundation
import FileProvider
import PVLibrary
import PVLogging
import PVRealm
import PVPrimitives
import RealmSwift

/// The principal class for the Provenance ROM library file provider extension.
///
/// Implements `NSFileProviderReplicatedExtension` to expose the Provenance game
/// library as a virtual file system inside Files.app.
///
/// ## Virtual hierarchy
/// ```
/// (root)
/// ├── Systems          → system:<id> → game:<md5>   (canonical ROMs; imports allowed)
/// ├── Publishers       → pub:<key> → All Games | <System> → sym:… → game:<md5>
/// ├── Years            → year:<YYYY|Unknown> → sym:…
/// ├── Regions          → region:<key> → sym:…
/// └── Ratings          → rating:<key> → sym:…
/// ```
///
/// Alternate browse axes use symlink rows (`sym:…`) whose target is the canonical `game:<md5>` item.
///
/// ## Write support
/// - `createItem` — only into `system:<id>` under **Systems** (same as before).
/// - `modifyItem` / `deleteItem` — follow symlink targets to the canonical game record.
///
/// ## Domain registration
/// The host application must call `PVFileProviderDomain.registerIfNeeded()` at
/// launch (see `PVAppDelegate+FileProvider.swift`) before the system will
/// present "Provenance" as a location in Files.app.
final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

    required init(domain: NSFileProviderDomain) {
        RealmConfiguration.setDefaultRealmConfig()
        super.init()
        FileProviderExtension.logSharedRealmDiagnostics(context: "FileProviderExtension init, domain=\(domain.displayName)")
        ILOG("FileProviderExtension: initialized for domain \(domain.displayName)")
    }

    /// Mirrors Spotlight / Top Shelf: log App Group + `default.realm` presence and touch shared ``RomFileProviderLibrary`` / ``RomDatabase`` read access.
    private static func logSharedRealmDiagnostics(context: String) {
        if !RealmConfiguration.supportsAppGroups {
            WLOG("FileProvider: \(context) — App Groups not configured; library may be empty")
            return
        }
        if let container = RealmConfiguration.appGroupContainer {
            ILOG("FileProvider: \(context) — app group container \(container.path)")
        }
        if let appGroupPath = RealmConfiguration.appGroupPath {
            let realmURL = appGroupPath.appendingPathComponent("default.realm", isDirectory: false)
            if FileManager.default.fileExists(atPath: realmURL.path) {
                ILOG("FileProvider: \(context) — Realm file present at \(realmURL.path)")
            } else {
                WLOG("FileProvider: \(context) — no Realm file at \(realmURL.path) (open the main app once)")
            }
        }
        _ = RomFileProviderLibrary.realm
    }

    func invalidate() {
        ILOG("FileProviderExtension: invalidated")
    }

    func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        if let item = resolveItem(for: identifier) {
            completionHandler(item, nil)
        } else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        return Progress()
    }

    func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion?,
        request: NSFileProviderRequest,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        guard let md5 = canonicalGameMD5(from: itemIdentifier.rawValue) else {
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }

        let realm = RomFileProviderLibrary.realm
        guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
              !pvGame.isInvalidated else {
            WLOG("FileProvider: game not found for md5=\(md5)")
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }

        guard let romURL = pvGame.file?.url,
              FileManager.default.fileExists(atPath: romURL.path) else {
            WLOG("FileProvider: ROM file not locally available for \(pvGame.title)")
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }

        let item = FileProviderItem(game: pvGame.asDomain(), romURL: romURL)
        ILOG("FileProvider: serving \(romURL.lastPathComponent) for \(pvGame.title)")
        completionHandler(romURL, item, nil)

        return Progress()
    }

    func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        guard itemTemplate.contentType != .folder else {
            completionHandler(nil, [], false, CocoaError(.featureUnsupported))
            return Progress()
        }

        guard let sourceURL = url else {
            completionHandler(nil, [], false, CocoaError(.featureUnsupported))
            return Progress()
        }

        let parentRaw = itemTemplate.parentItemIdentifier.rawValue
        guard parentRaw.hasPrefix(FileProviderItem.systemIdentifierPrefix) else {
            completionHandler(nil, [], false, CocoaError(.featureUnsupported))
            return Progress()
        }
        let systemID = String(parentRaw.dropFirst(FileProviderItem.systemIdentifierPrefix.count))

        let progress = Progress(totalUnitCount: 1)
        let task = Task.detached(priority: .userInitiated) { [self] in
            do {
                let item = try self.performImport(
                    from: sourceURL,
                    filename: itemTemplate.filename,
                    systemID: systemID
                )
                progress.completedUnitCount = 1
                completionHandler(item, [], false, nil)
            } catch {
                ELOG("FileProvider: createItem error — \(error)")
                completionHandler(nil, [], false, error)
            }
        }
        progress.cancellationHandler = { task.cancel() }

        return progress
    }

    func modifyItem(
        _ item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents newContents: URL?,
        options: NSFileProviderModifyItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        guard let md5 = canonicalGameMD5(from: item.itemIdentifier.rawValue) else {
            completionHandler(nil, [], false, CocoaError(.featureUnsupported))
            return Progress()
        }

        do {
            let realm = RomFileProviderLibrary.realm
            guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                  !pvGame.isInvalidated else {
                completionHandler(nil, [], false, NSFileProviderError(.noSuchItem))
                return Progress()
            }

            if changedFields.contains(.contents) {
                completionHandler(nil, [], false, CocoaError(.featureUnsupported))
                return Progress()
            }

            if changedFields.contains(.filename) {
                let newFilename = sanitizedFilename(from: item.filename)
                if let existingURL = pvGame.file?.url {
                    let destURL = existingURL.deletingLastPathComponent()
                        .appendingPathComponent(newFilename)
                    if existingURL.path != destURL.path {
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            throw NSFileProviderError(.filenameCollision)
                        }
                        try FileManager.default.moveItem(at: existingURL, to: destURL)
                        if let pvFile = pvGame.file {
                            let newPartial = pvFile.relativeRoot.createRelativePath(fromURL: destURL)
                            try realm.write {
                                pvFile.partialPath = newPartial
                                pvGame.title = (newFilename as NSString).deletingPathExtension
                                pvGame.romPath = newPartial
                            }
                        }
                        ILOG("FileProvider: renamed \(existingURL.lastPathComponent) → \(newFilename)")
                    }
                }
            }

            let romURL = pvGame.file?.url
            let updatedItem: FileProviderItem
            let rawId = item.itemIdentifier.rawValue
            if rawId.hasPrefix(RomFileProviderVirtualPath.symlinkPrefix),
               let parsed = RomFileProviderVirtualPath.parseSymlink(from: rawId) {
                updatedItem = FileProviderItem(
                    symlinkTo: pvGame.asDomain(),
                    romURL: romURL,
                    symlinkRawId: rawId,
                    targetGameMD5: parsed.md5,
                    parentItemIdentifier: NSFileProviderItemIdentifier(parsed.parentItemRaw)
                )
            } else {
                updatedItem = FileProviderItem(game: pvGame.asDomain(), romURL: romURL)
            }
            completionHandler(updatedItem, [], false, nil)
        } catch {
            ELOG("FileProvider: modifyItem error — \(error)")
            completionHandler(nil, [], false, error)
        }

        return Progress()
    }

    func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        guard let md5 = canonicalGameMD5(from: identifier.rawValue) else {
            completionHandler(CocoaError(.featureUnsupported))
            return Progress()
        }

        do {
            let realm = RomFileProviderLibrary.realm
            guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                  !pvGame.isInvalidated else {
                completionHandler(nil)
                return Progress()
            }

            if let romURL = pvGame.file?.url,
               FileManager.default.fileExists(atPath: romURL.path) {
                try FileManager.default.removeItem(at: romURL)
                ILOG("FileProvider: deleted file at \(romURL.lastPathComponent)")
            }

            let saveStatesToDelete = Array(pvGame.saveStates)
            let cheatsToDelete = Array(pvGame.cheats)
            let recentPlaysToDelete = Array(pvGame.recentPlays)
            let screenShotsToDelete = Array(pvGame.screenShots)

            try realm.write {
                realm.delete(saveStatesToDelete)
                realm.delete(cheatsToDelete)
                realm.delete(recentPlaysToDelete)
                realm.delete(screenShotsToDelete)
                if let pvFile = pvGame.file {
                    realm.delete(pvFile)
                }
                realm.delete(pvGame)
            }

            completionHandler(nil)
        } catch {
            ELOG("FileProvider: deleteItem error — \(error)")
            completionHandler(error)
        }

        return Progress()
    }

    func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }

    private func performImport(from sourceURL: URL, filename: String, systemID: String) throws -> FileProviderItem {
        let realm = RomFileProviderLibrary.realm

        guard let pvSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: systemID),
              !pvSystem.isInvalidated else {
            throw NSFileProviderError(.noSuchItem)
        }

        try Task.checkCancellation()
        guard let md5 = streamingMD5(for: sourceURL) else {
            ELOG("FileProvider: failed to compute MD5 for \(filename)")
            throw NSFileProviderError(.cannotSynchronize)
        }

        if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
           !existing.isInvalidated {
            if let existingFileURL = existing.file?.url,
               FileManager.default.fileExists(atPath: existingFileURL.path) {
                ILOG("FileProvider: ROM already exists (md5=\(md5)), skipping copy")
                return FileProviderItem(game: existing.asDomain(), romURL: existingFileURL)
            }
        }

        let destDir = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: systemID)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)

        try Task.checkCancellation()

        let destURL = uniqueDestinationURL(in: destDir, for: filename)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        try Task.checkCancellation()

        if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
           !existing.isInvalidated {
            ILOG("FileProvider: existing ROM record for md5=\(md5) has no valid local file; updating record with imported copy at \(destURL.lastPathComponent)")
            let newRomFile = PVFile(withURL: destURL)
            let newPartialPath = newRomFile.partialPath
            try realm.write {
                if let oldFile = existing.file {
                    realm.delete(oldFile)
                }
                realm.add(newRomFile)
                existing.file = newRomFile
                existing.romPath = newPartialPath
                existing.isDownloaded = true
            }
            return FileProviderItem(game: existing.asDomain(), romURL: destURL)
        }

        let romFile = PVFile(withURL: destURL)
        let actualFilename = destURL.lastPathComponent
        let game = PVGame()
        game.md5Hash = md5
        game.systemIdentifier = systemID
        game.system = pvSystem
        game.title = (actualFilename as NSString).deletingPathExtension
        game.requiresSync = true
        game.isDownloaded = true
        game.file = romFile
        game.romPath = romFile.partialPath

        try realm.write {
            realm.add(romFile)
            realm.add(game)
        }

        ILOG("FileProvider: imported \(filename) md5=\(md5) system=\(systemID)")
        return FileProviderItem(game: game.asDomain(), romURL: destURL)
    }

    private func sanitizedFilename(from rawFilename: String) -> String {
        var name = (rawFilename as NSString).lastPathComponent
        name = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filteredScalars = name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        name = String(String.UnicodeScalarView(filteredScalars))
        let components = name.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        name = components.joined(separator: " ")
        return name.isEmpty ? "Untitled" : name
    }

    private func uniqueDestinationURL(in directory: URL, for filename: String) -> URL {
        let safeFilename = sanitizedFilename(from: filename)
        let candidate = directory.appendingPathComponent(safeFilename)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return candidate
        }
        let base = (safeFilename as NSString).deletingPathExtension
        let ext = (safeFilename as NSString).pathExtension
        var counter = 2
        while true {
            let name = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            let url = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) { return url }
            counter += 1
        }
    }

    private func streamingMD5(for url: URL) -> String? {
        let chunkSize = 1024 * 1024
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }

        var hasher = Insecure.MD5()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let n = stream.read(buffer, maxLength: chunkSize)
            if n < 0 { return nil }
            if n == 0 { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: n))
        }

        return hasher.finalize().map { String(format: "%02X", $0) }.joined()
    }

    /// Resolves symlink or canonical `game:` raw value to uppercase MD5 primary key.
    private func canonicalGameMD5(from raw: String) -> String? {
        if raw.hasPrefix(FileProviderItem.gameIdentifierPrefix) {
            return String(raw.dropFirst(FileProviderItem.gameIdentifierPrefix.count)).uppercased()
        }
        if raw.hasPrefix(RomFileProviderVirtualPath.symlinkPrefix) {
            return RomFileProviderVirtualPath.parseSymlinkMD5(from: raw)
        }
        return nil
    }

    private func resolveItem(for identifier: NSFileProviderItemIdentifier) -> FileProviderItem? {
        if identifier == .rootContainer {
            return FileProviderItem(root: ())
        }

        let raw = identifier.rawValue

        if let cat = RomFileProviderRootCategory(rawValue: raw) {
            return FileProviderItem(category: cat)
        }

        if raw.hasPrefix(FileProviderItem.systemIdentifierPrefix) {
            return resolveSystemFolder(raw: raw)
        }

        if raw.hasPrefix(FileProviderItem.gameIdentifierPrefix) {
            return resolveCanonicalGame(raw: raw)
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.symlinkPrefix) {
            return resolveSymlink(raw: raw)
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.publisherAllGamesPrefix) {
            let enc = String(raw.dropFirst(RomFileProviderVirtualPath.publisherAllGamesPrefix.count))
            guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { return nil }
            let parent = NSFileProviderItemIdentifier(RomFileProviderVirtualPath.publisherFolderPrefix + enc)
            return FileProviderItem(publisherAllGamesFolderGroupingKey: groupingKey, parentItemIdentifier: parent)
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.publisherSystemPrefix) {
            return resolvePublisherSystemFolder(raw: raw)
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.publisherFolderPrefix) {
            return resolvePublisherFolder(raw: raw)
        }

        if raw.hasPrefix("year:") {
            let yearKey = String(raw.dropFirst("year:".count))
            let parent = NSFileProviderItemIdentifier(RomFileProviderRootCategory.years.rawIdentifier)
            return FileProviderItem(yearFolder: yearKey, parentItemIdentifier: parent)
        }

        if raw.hasPrefix("region:") {
            let enc = String(raw.dropFirst("region:".count))
            guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { return nil }
            let parent = NSFileProviderItemIdentifier(RomFileProviderRootCategory.regions.rawIdentifier)
            let title = RomFileProviderLibrary.displayName(axis: .region, groupingKey: groupingKey)
            return FileProviderItem(regionFolderGroupingKey: groupingKey, title: title, parentItemIdentifier: parent)
        }

        if raw.hasPrefix("rating:") {
            let key = String(raw.dropFirst("rating:".count))
            let parent = NSFileProviderItemIdentifier(RomFileProviderRootCategory.ratings.rawIdentifier)
            let title = RomFileProviderLibrary.ratingFolderLabel(forKey: key)
            return FileProviderItem(ratingFolderKey: key, title: title, parentItemIdentifier: parent)
        }

        return nil
    }

    private func resolveSystemFolder(raw: String) -> FileProviderItem? {
        let sysID = String(raw.dropFirst(FileProviderItem.systemIdentifierPrefix.count))
        let realm = RomFileProviderLibrary.realm
        guard let pvSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: sysID),
              !pvSystem.isInvalidated else { return nil }
        let parent = NSFileProviderItemIdentifier(RomFileProviderRootCategory.systems.rawIdentifier)
        return FileProviderItem(system: pvSystem.asDomain(), parentItemIdentifier: parent)
    }

    private func resolveCanonicalGame(raw: String) -> FileProviderItem? {
        let md5 = String(raw.dropFirst(FileProviderItem.gameIdentifierPrefix.count)).uppercased()
        let realm = RomFileProviderLibrary.realm
        guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
              !pvGame.isInvalidated else { return nil }
        return FileProviderItem(game: pvGame.asDomain(), romURL: pvGame.file?.url)
    }

    private func resolveSymlink(raw: String) -> FileProviderItem? {
        guard let parsed = RomFileProviderVirtualPath.parseSymlink(from: raw) else { return nil }
        let realm = RomFileProviderLibrary.realm
        guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: parsed.md5),
              !pvGame.isInvalidated else { return nil }
        let game = pvGame.asDomain()
        let url = pvGame.file?.url
        let parent = NSFileProviderItemIdentifier(parsed.parentItemRaw)
        return FileProviderItem(
            symlinkTo: game,
            romURL: url,
            symlinkRawId: raw,
            targetGameMD5: parsed.md5,
            parentItemIdentifier: parent
        )
    }

    private func resolvePublisherFolder(raw: String) -> FileProviderItem? {
        let enc = String(raw.dropFirst(RomFileProviderVirtualPath.publisherFolderPrefix.count))
        guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { return nil }
        let parent = NSFileProviderItemIdentifier(RomFileProviderRootCategory.publishers.rawIdentifier)
        let title = RomFileProviderLibrary.displayName(axis: .publisher, groupingKey: groupingKey)
        return FileProviderItem(publisherFolderGroupingKey: groupingKey, title: title, parentItemIdentifier: parent)
    }

    private func resolvePublisherSystemFolder(raw: String) -> FileProviderItem? {
        let rest = String(raw.dropFirst(RomFileProviderVirtualPath.publisherSystemPrefix.count))
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let enc = String(rest[..<colon])
        let systemId = String(rest[rest.index(after: colon)...])
        guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { return nil }
        let realm = RomFileProviderLibrary.realm
        guard let pvSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: systemId),
              !pvSystem.isInvalidated else { return nil }
        let parent = NSFileProviderItemIdentifier(RomFileProviderVirtualPath.publisherFolderPrefix + enc)
        return FileProviderItem(publisherSystemFolderGroupingKey: groupingKey, system: pvSystem.asDomain(), parentItemIdentifier: parent)
    }
}

