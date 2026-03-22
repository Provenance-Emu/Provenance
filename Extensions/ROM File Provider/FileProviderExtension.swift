//
//  FileProviderExtension.swift
//  ROM File Provider
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import FileProvider
import RealmSwift
import PVLibrary
import PVRealm
import PVLogging

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
/// ## Read-only
/// `createItem`, `modifyItem`, and `deleteItem` are not implemented in v1.
/// The extension is purely read-only; write support (drag-in from Files) is
/// deferred to a follow-up.
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
        guard raw.hasPrefix("game:") else {
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }

        let md5 = String(raw.dropFirst("game:".count))

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
                completionHandler(nil, nil, NSFileProviderError(.serverUnreachable))
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

    // MARK: - Mutation (read-only — not supported in v1)

    func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        // Return the template unchanged so the system knows we acknowledge the call.
        completionHandler(itemTemplate, [], false, nil)
        return Progress()
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
        completionHandler(nil, [], false, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: nil))
        return Progress()
    }

    func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: nil))
        return Progress()
    }

    // MARK: - Enumeration

    func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }

    // MARK: - Private

    /// Resolves an `NSFileProviderItemIdentifier` to a `FileProviderItem` backed by the Realm database.
    private func resolveItem(for identifier: NSFileProviderItemIdentifier) -> FileProviderItem? {
        if identifier == .rootContainer {
            return FileProviderItem(root: ())
        }

        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            let raw = identifier.rawValue

            if raw.hasPrefix("system:") {
                let sysID = String(raw.dropFirst("system:".count))
                guard let pvSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: sysID),
                      !pvSystem.isInvalidated else { return nil }
                return FileProviderItem(system: pvSystem.asDomain())
            }

            if raw.hasPrefix("game:") {
                let md5 = String(raw.dropFirst("game:".count))
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
