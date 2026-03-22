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

    // MARK: - Init

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    // MARK: - NSFileProviderEnumerator

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        do {
            let items = try buildItems()
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
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

    /// Returns one `FileProviderItem` per system that has at least one game.
    private func buildSystemItems(realm: Realm) -> [FileProviderItem] {
        let systems = realm.objects(PVSystem.self).filter("games.@count > 0")
        return systems.compactMap { pvSystem -> FileProviderItem? in
            guard !pvSystem.isInvalidated else { return nil }
            return FileProviderItem(system: pvSystem.asDomain())
        }
    }

    /// Returns one `FileProviderItem` per game in the given system.
    private func buildGameItems(systemIdentifier: String, realm: Realm) -> [FileProviderItem] {
        let games = realm.objects(PVGame.self)
            .filter("systemIdentifier == %@", systemIdentifier)
        return games.compactMap { pvGame -> FileProviderItem? in
            guard !pvGame.isInvalidated else { return nil }
            let romURL = pvGame.file?.url
            return FileProviderItem(game: pvGame.asDomain(), romURL: romURL)
        }
    }
}
