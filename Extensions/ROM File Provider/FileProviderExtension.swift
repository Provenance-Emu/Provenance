//
//  FileProviderExtension.swift
//  ROM File Provider
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import CryptoKit
import FileProvider
import PVLibrary
import PVLogging
import PVRealm
import RealmSwift

/// The principal class for the Provenance ROM library file provider extension.
///
/// Implements `NSFileProviderReplicatedExtension` to expose the Provenance game
/// library as a virtual file system inside Files.app.
///
/// ## Virtual hierarchy
/// ```
/// (root)
/// └── <System Name>          ← system folder, identifier "system:<systemID>"
///     └── <ROM filename>     ← ROM file,     identifier "game:<md5Hash>"
/// ```
///
/// ## Write support (v2)
/// - `createItem` — copies a ROM dropped into a system folder into the library;
///   creates a minimal `PVGame` Realm record so it appears immediately; the main
///   app's directory-watcher enriches metadata on next launch.
/// - `modifyItem` — handles renames (`.filename`); content replacement is rejected (see `modifyItem` for rationale).
/// - `deleteItem` — removes the ROM file from disk and the Realm record.
///
/// ## Domain registration
/// The host application must call `PVFileProviderDomain.registerIfNeeded()` at
/// launch (see `PVAppDelegate+FileProvider.swift`) before the system will
/// present "Provenance" as a location in Files.app.
final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

    // MARK: - Lifecycle

    required init(domain: NSFileProviderDomain) {
        // Ensure Realm is configured before any database access in this process.
        RealmConfiguration.setDefaultRealmConfig()
        super.init()
        ILOG("FileProviderExtension: initialized for domain \(domain.displayName)")
    }

    func invalidate() {
        ILOG("FileProviderExtension: invalidated")
    }

    // MARK: - Item lookup

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

    // MARK: - Content fetching

    /// Streams the ROM file bytes to the file provider framework for read access.
    ///
    /// Returns an error if:
    /// - The identifier does not refer to a game item
    /// - No matching game is found in the Realm database
    /// - The ROM file is not present locally (e.g. cloud-only)
    func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion?,
        request: NSFileProviderRequest,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let raw = itemIdentifier.rawValue
        guard raw.hasPrefix(FileProviderItem.gameIdentifierPrefix) else {
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }

        let md5 = String(raw.dropFirst(FileProviderItem.gameIdentifierPrefix.count))

        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
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
        } catch {
            ELOG("FileProvider: fetchContents error — \(error)")
            completionHandler(nil, nil, error)
        }

        return Progress()
    }

    // MARK: - Mutation: create

    /// Imports a ROM file dropped into a system folder via Files.app.
    ///
    /// Only ROM files (not folders) dropped directly into a system folder are
    /// accepted. The file is copied to the Provenance ROM library directory for
    /// the target system, hashed (MD5), and a minimal `PVGame` Realm record is
    /// created so the file appears immediately in both Files.app and the app.
    /// The main app's directory-watcher will enrich the record with metadata and
    /// artwork on next launch.
    func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        // Only files — reject folder-creation requests.
        guard itemTemplate.contentType != .folder else {
            completionHandler(nil, [], false, NSFileProviderError(.unsupported))
            return Progress()
        }

        // File content is required; placeholder-only creation is not supported.
        guard let sourceURL = url else {
            completionHandler(nil, [], false, NSFileProviderError(.unsupported))
            return Progress()
        }

        // Only accept drops directly into a system folder (not the root container).
        let parentRaw = itemTemplate.parentItemIdentifier.rawValue
        guard parentRaw.hasPrefix(FileProviderItem.systemIdentifierPrefix) else {
            completionHandler(nil, [], false, NSFileProviderError(.unsupported))
            return Progress()
        }
        let systemID = String(parentRaw.dropFirst(FileProviderItem.systemIdentifierPrefix.count))

        let progress = Progress(totalUnitCount: 1)
        // Capture self strongly: the extension process is alive for the duration of
        // the task, and weak capture risks the completion handler never being called.
        // Retain the task handle so progress cancellation can cancel the underlying work.
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
        // Wire progress cancellation to the underlying task so that a user/system cancel
        // stops the file copy + hash instead of letting it run to completion.
        progress.cancellationHandler = { task.cancel() }

        return progress
    }

    // MARK: - Mutation: modify

    /// Handles rename of a ROM file.
    ///
    /// Supported `changedFields`:
    /// - `.filename` — renames the file on disk and updates the Realm record.
    ///
    /// `.contents` writes are intentionally rejected: the provider uses the ROM's MD5 hash as
    /// the `NSFileProviderItem` stable identifier and as the `PVGame` Realm primary key.
    /// Replacing file content would change the MD5, making the identifier stale.  Until a
    /// replace-as-new path (recompute hash → new record → delete old) is implemented, content
    /// replacement is not supported.
    func modifyItem(
        _ item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents newContents: URL?,
        options: NSFileProviderModifyItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        let raw = item.itemIdentifier.rawValue
        guard raw.hasPrefix(FileProviderItem.gameIdentifierPrefix) else {
            // System folders and root are not directly modifiable.
            completionHandler(nil, [], false, NSFileProviderError(.unsupported))
            return Progress()
        }

        let md5 = String(raw.dropFirst(FileProviderItem.gameIdentifierPrefix.count))

        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                  !pvGame.isInvalidated else {
                completionHandler(nil, [], false, NSFileProviderError(.noSuchItem))
                return Progress()
            }

            // Content replacement is not supported: the item identifier is derived from the
            // ROM's MD5 hash, which would change after a content swap, leaving the provider
            // in an inconsistent state.  Reject the request so Files.app surfaces an error
            // instead of silently corrupting the identifier / Realm record.
            if changedFields.contains(.contents) {
                completionHandler(nil, [], false, NSFileProviderError(.unsupported))
                return Progress()
            }

            // Rename — move the file and update the Realm partial-path.
            if changedFields.contains(.filename) {
                // Strip path components to prevent traversal via `../` or `/` in the
                // OS-supplied filename before constructing the destination URL.
                let newFilename = (item.filename as NSString).lastPathComponent
                if let existingURL = pvGame.file?.url {
                    let destURL = existingURL.deletingLastPathComponent()
                        .appendingPathComponent(newFilename)
                    if existingURL.path != destURL.path {
                        // Explicitly surface name conflicts as `.filenameCollision` so Files.app
                        // can show a user-friendly "name already in use" error instead of a
                        // generic OS error from `moveItem`.
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            throw NSFileProviderError(.filenameCollision)
                        }
                        try FileManager.default.moveItem(at: existingURL, to: destURL)
                        if let pvFile = pvGame.file {
                            let newPartial = pvFile.relativeRoot.createRelativePath(fromURL: destURL)
                            try realm.write {
                                pvFile.partialPath = newPartial
                                pvGame.title = (newFilename as NSString).deletingPathExtension
                                // Keep romPath in sync with the primary file path so that
                                // caches, sync, and metadata enrichment that key off romPath
                                // see the updated location immediately.
                                pvGame.romPath = newPartial
                                // Note: PVFile.fileName is a computed property derived from
                                // url?.lastPathComponent (which is derived from partialPath),
                                // so it reflects the new name automatically — no separate
                                // stored field needs updating.
                            }
                        }
                        ILOG("FileProvider: renamed \(existingURL.lastPathComponent) → \(newFilename)")
                    }
                }
            }

            let romURL = pvGame.file?.url
            let updatedItem = FileProviderItem(game: pvGame.asDomain(), romURL: romURL)
            completionHandler(updatedItem, [], false, nil)
        } catch {
            ELOG("FileProvider: modifyItem error — \(error)")
            completionHandler(nil, [], false, error)
        }

        return Progress()
    }

    // MARK: - Mutation: delete

    /// Deletes a ROM file from the Provenance library.
    ///
    /// Removes the on-disk file and the `PVGame` Realm record. System folders
    /// and the root container cannot be deleted via this path.
    func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        let raw = identifier.rawValue
        guard raw.hasPrefix(FileProviderItem.gameIdentifierPrefix) else {
            // Cannot delete system folders or the root container.
            completionHandler(NSFileProviderError(.unsupported))
            return Progress()
        }

        let md5 = String(raw.dropFirst(FileProviderItem.gameIdentifierPrefix.count))

        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                  !pvGame.isInvalidated else {
                // Already absent — treat as success.
                completionHandler(nil)
                return Progress()
            }

            // Remove ROM file from disk.
            if let romURL = pvGame.file?.url,
               FileManager.default.fileExists(atPath: romURL.path) {
                try FileManager.default.removeItem(at: romURL)
                ILOG("FileProvider: deleted file at \(romURL.lastPathComponent)")
            }

            // Realm does not cascade deletes; snapshot linking objects before the write
            // to avoid invalidated-object crashes inside the transaction.
            let saveStatesToDelete = Array(pvGame.saveStates)
            let cheatsToDelete = Array(pvGame.cheats)
            let recentPlaysToDelete = Array(pvGame.recentPlays)
            let screenShotsToDelete = Array(pvGame.screenShots)

            // Remove the Realm record plus all related objects (save states, cheats,
            // recent-play entries, screenshots) that hold a non-optional reference to
            // PVGame — leaving them behind would cause crashes or inconsistent UI.
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

    // MARK: - Enumeration

    func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }

    // MARK: - Private: import

    /// Copies `sourceURL` into the ROM library for `systemID`, hashes the file,
    /// and creates a minimal `PVGame` Realm record.
    ///
    /// If a game with the computed MD5 already exists the existing record is
    /// returned without creating a duplicate.
    private func performImport(from sourceURL: URL, filename: String, systemID: String) throws -> FileProviderItem {
        let realm = try Realm(configuration: RealmConfiguration.realmConfig)

        guard let pvSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: systemID),
              !pvSystem.isInvalidated else {
            throw NSFileProviderError(.noSuchItem)
        }

        // Hash the source file first so we can detect duplicates before doing any disk
        // writes — avoids copying large ROMs that will be immediately discarded.
        try Task.checkCancellation()
        guard let md5 = streamingMD5(for: sourceURL) else {
            ELOG("FileProvider: failed to compute MD5 for \(filename)")
            throw NSFileProviderError(.cannotSynchronize)
        }

        // Fast-path: if a game with this MD5 already exists and has a valid on-disk
        // file, return the canonical record immediately without touching disk.
        if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
           !existing.isInvalidated {
            if let existingFileURL = existing.file?.url,
               FileManager.default.fileExists(atPath: existingFileURL.path) {
                ILOG("FileProvider: ROM already exists (md5=\(md5)), skipping copy")
                return FileProviderItem(game: existing.asDomain(), romURL: existingFileURL)
            }
        }

        // Destination: <romsRoot>/<systemID>/<filename>
        let destDir = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: systemID)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)

        // Check cancellation before the potentially large file copy.
        try Task.checkCancellation()

        // Avoid silently overwriting an existing ROM that may have different content.
        // Generate a unique destination path by appending a counter suffix when needed.
        let destURL = uniqueDestinationURL(in: destDir, for: filename)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        // Check cancellation before the Realm write.
        try Task.checkCancellation()

        // If the existing record is a placeholder or its local file is missing, update
        // it to point to the newly imported copy.
        if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
           !existing.isInvalidated {
            // Existing record is a placeholder or its local file is missing — keep
            // the newly imported ROM and update the Realm record so caches, sync,
            // and metadata enrichment see the correct on-disk path.
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

        // Create a minimal PVGame; the main app directory-watcher fills in metadata.
        let romFile = PVFile(withURL: destURL)
        // Derive title from the actual on-disk filename (may differ from the user-supplied
        // name after uniqueDestinationURL appends a collision suffix).
        let actualFilename = destURL.lastPathComponent
        let game = PVGame()
        game.md5Hash = md5
        game.systemIdentifier = systemID
        game.system = pvSystem
        game.title = (actualFilename as NSString).deletingPathExtension
        game.requiresSync = true
        game.isDownloaded = true
        game.file = romFile
        // romPath is used by caches, sync, and metadata enrichment — keep it in sync.
        game.romPath = romFile.partialPath

        try realm.write {
            realm.add(romFile)
            realm.add(game)
        }

        ILOG("FileProvider: imported \(filename) md5=\(md5) system=\(systemID)")
        return FileProviderItem(game: game.asDomain(), romURL: destURL)
    }

    /// Returns a URL in `directory` for `filename` that does not yet exist on disk.
    ///
    /// If `<directory>/<filename>` is free it is returned as-is.  Otherwise a numeric
    /// suffix is appended before the extension until a free slot is found, e.g.
    /// `game.sfc` → `game-2.sfc` → `game-3.sfc` …
    ///
    /// The filename is stripped to its last path component before use to prevent
    /// path-traversal attacks (e.g. a crafted name containing `../`).
    private func uniqueDestinationURL(in directory: URL, for filename: String) -> URL {
        // Strip any directory components to prevent path traversal via `..` or `/`.
        let safeFilename = (filename as NSString).lastPathComponent
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

    /// Computes an uppercase hex-encoded MD5 hash by streaming the file in 1 MiB chunks,
    /// avoiding loading large ROM files entirely into memory.
    ///
    /// Uppercase output matches the convention used throughout the codebase (PVHashing,
    /// CloudSyncManager, RomsDatastore) so that `PVGame.md5Hash` primary-key lookups
    /// succeed without case-normalisation at the call site.
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
            // Use a no-copy raw buffer pointer to avoid a per-chunk Data allocation.
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: n))
        }

        return hasher.finalize().map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - Private: item resolution

    private func resolveItem(for identifier: NSFileProviderItemIdentifier) -> FileProviderItem? {
        if identifier == .rootContainer {
            return FileProviderItem(root: ())
        }

        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            let raw = identifier.rawValue

            if raw.hasPrefix(FileProviderItem.systemIdentifierPrefix) {
                let sysID = String(raw.dropFirst(FileProviderItem.systemIdentifierPrefix.count))
                guard let pvSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: sysID),
                      !pvSystem.isInvalidated else { return nil }
                return FileProviderItem(system: pvSystem.asDomain())
            }

            if raw.hasPrefix(FileProviderItem.gameIdentifierPrefix) {
                let md5 = String(raw.dropFirst(FileProviderItem.gameIdentifierPrefix.count))
                guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
                      !pvGame.isInvalidated else { return nil }
                return FileProviderItem(game: pvGame.asDomain(), romURL: pvGame.file?.url)
            }
        } catch {
            ELOG("FileProvider: resolveItem error — \(error)")
        }

        return nil
    }
}
