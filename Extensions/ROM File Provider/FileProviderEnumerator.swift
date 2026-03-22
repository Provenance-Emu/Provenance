//
//  FileProviderEnumerator.swift
//  ROM File Provider
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import FileProvider
import RealmSwift
import PVLibrary
import PVRealm

/// Enumerates items in the Provenance ROM library for the Files.app file provider.
///
/// Supports two container kinds:
/// - `.rootContainer` — lists all game-console system folders that have ≥ 1 game
/// - `"system:<identifier>"` — lists all games belonging to that system
///
/// Realm objects are converted to thread-safe CPDI structs (`System`, `Game`)
/// before being wrapped in `FileProviderItem` so no live Realm references escape
/// the enumeration call.
final class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {

    // MARK: - Properties

    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    /// A stable anchor; real-time change tracking is out-of-scope for v1.
    private let anchor = NSFileProviderSyncAnchor(Data("provenance-v1".utf8))
    /// Maximum number of items returned in a single enumeration page.
    private static let pageSize = 100

    // MARK: - Init

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    // MARK: - NSFileProviderEnumerator

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        // Decode the offset from the page token; treat the initial pages as offset 0.
        let offset: Int
        if page == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage ||
           page == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage {
            offset = 0
        } else {
            offset = page.rawValue.withUnsafeBytes { ptr in
                ptr.load(as: Int.self)
            }
        }

        do {
            let allItems = try buildItems()
            let slice = Array(allItems.dropFirst(offset).prefix(Self.pageSize))
            observer.didEnumerate(slice)

            let nextOffset = offset + slice.count
            if nextOffset < allItems.count {
                var nextValue = nextOffset
                let nextPage = NSFileProviderPage(Data(bytes: &nextValue, count: MemoryLayout<Int>.size))
                observer.finishEnumerating(upTo: nextPage)
            } else {
                observer.finishEnumerating(upTo: nil)
            }
        } catch {
            observer.finishEnumeratingWithError(error)
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        // v1: no incremental change tracking — tell the system there are no pending changes.
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(anchor)
    }

    // MARK: - Private

    private func buildItems() throws -> [FileProviderItem] {
        let realm = try Realm(configuration: RealmConfiguration.realmConfig)

        if enumeratedItemIdentifier == .rootContainer {
            return buildSystemItems(realm: realm)
        }

        let raw = enumeratedItemIdentifier.rawValue
        if raw.hasPrefix("system:") {
            let systemIdentifier = String(raw.dropFirst("system:".count))
            return buildGameItems(systemIdentifier: systemIdentifier, realm: realm)
        }

        return []
    }

    /// Returns one `FileProviderItem` per system that has at least one locally-present ROM.
    private func buildSystemItems(realm: Realm) -> [FileProviderItem] {
        // Collect the set of system identifiers that have at least one game with a local file.
        let localSystemIDs = localGameSystemIdentifiers(realm: realm)
        guard !localSystemIDs.isEmpty else { return [] }

        let systems = realm.objects(PVSystem.self)
            .filter("identifier IN %@", Array(localSystemIDs))
        return systems.compactMap { pvSystem -> FileProviderItem? in
            guard !pvSystem.isInvalidated else { return nil }
            return FileProviderItem(system: pvSystem.asDomain())
        }
    }

    /// Returns one `FileProviderItem` per game in the given system that has a locally-present ROM file.
    private func buildGameItems(systemIdentifier: String, realm: Realm) -> [FileProviderItem] {
        let games = realm.objects(PVGame.self)
            .filter("systemIdentifier == %@", systemIdentifier)
        return games.compactMap { pvGame -> FileProviderItem? in
            guard !pvGame.isInvalidated,
                  let romURL = pvGame.file?.url,
                  FileManager.default.fileExists(atPath: romURL.path) else { return nil }
            return FileProviderItem(game: pvGame.asDomain(), romURL: romURL)
        }
    }

    /// Returns the set of system identifiers for which at least one ROM file is present on disk.
    private func localGameSystemIdentifiers(realm: Realm) -> Set<String> {
        let allGames = realm.objects(PVGame.self)
        var ids = Set<String>()
        for pvGame in allGames {
            guard !pvGame.isInvalidated,
                  let romURL = pvGame.file?.url,
                  FileManager.default.fileExists(atPath: romURL.path) else { continue }
            ids.insert(pvGame.systemIdentifier)
        }
        return ids
    }
}
