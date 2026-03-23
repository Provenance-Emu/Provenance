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
/// - `modifyItem` — handles renames (`.filename`) and content replacement (`.contents`).
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
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
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

        return progress
    }

    // MARK: - Mutation: modify

    /// Handles rename and content-replacement of a ROM file.
    ///
    /// Supported `changedFields`:
    /// - `.filename` — renames the file on disk and updates the Realm record.
    /// - `.contents` — atomically replaces the file content (e.g. overwrite with patched ROM).
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

            // Content replacement — atomically overwrite the existing ROM file.
            if changedFields.contains(.contents), let newURL = newContents {
                if let existingURL = pvGame.file?.url {
                    var resultURL: NSURL?
                    try FileManager.default.replaceItem(
                        at: existingURL,
                        withItemAt: newURL,
                        backupItemName: nil,
                        options: [],
                        resultingItemURL: &resultURL
                    )
                    ILOG("FileProvider: replaced content for \(pvGame.title)")
                }
            }

            // Rename — move the file and update the Realm partial-path.
            if changedFields.contains(.filename) {
                let newFilename = item.filename
                if let existingURL = pvGame.file?.url {
                    let destURL = existingURL.deletingLastPathComponent()
                        .appendingPathComponent(newFilename)
                    if existingURL.path != destURL.path {
                        try FileManager.default.moveItem(at: existingURL, to: destURL)
                        if let pvFile = pvGame.file {
                            let newPartial = pvFile.relativeRoot.createRelativePath(fromURL: destURL)
                            try realm.write {
                                pvFile.partialPath = newPartial
                                pvGame.title = (newFilename as NSString).deletingPathExtension
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

            // Remove the Realm record and its associated PVFile.
            try realm.write {
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

        // Destination: <romsRoot>/<systemID>/<filename>
        let destDir = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: systemID)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        guard let md5 = streamingMD5(for: destURL) else {
            try? FileManager.default.removeItem(at: destURL)
            ELOG("FileProvider: failed to compute MD5 for \(filename)")
            throw NSFileProviderError(.serverUnreachable)
        }

        // Return existing entry if this ROM was already in the library.
        if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: md5),
           !existing.isInvalidated {
            ILOG("FileProvider: ROM already exists (md5=\(md5))")
            return FileProviderItem(game: existing.asDomain(), romURL: destURL)
        }

        // Create a minimal PVGame; the main app directory-watcher fills in metadata.
        let romFile = PVFile(withURL: destURL)
        let game = PVGame()
        game.md5Hash = md5
        game.systemIdentifier = systemID
        game.system = pvSystem
        game.title = (filename as NSString).deletingPathExtension
        game.requiresSync = true
        game.isDownloaded = true
        game.file = romFile

        try realm.write {
            realm.add(romFile)
            realm.add(game)
        }

        ILOG("FileProvider: imported \(filename) md5=\(md5) system=\(systemID)")
        return FileProviderItem(game: game.asDomain(), romURL: destURL)
    }

    /// Computes a lowercase hex-encoded MD5 hash by streaming the file in 1 MiB chunks,
    /// avoiding loading large ROM files entirely into memory.
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
            hasher.update(data: UnsafeBufferPointer(start: buffer, count: n))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
