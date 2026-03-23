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
/// - `.rootContainer` — lists all game-console system folders that have ≥ 1 locally-present ROM
/// - `"system:<identifier>"` — lists all locally-present games belonging to that system
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
    private var cachedLocalSystemIDs: Set<String>?
    /// Cached page-source for game enumeration — stores domain snapshots (not live Realm objects).
    private var cachedLocalGames: [(game: Game, url: URL)]?

    // MARK: - Init

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    // MARK: - NSFileProviderEnumerator

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let offset = decodePageOffset(page)

        do {
            let (items, total) = try buildItems(offset: offset, limit: Self.pageSize)
            observer.didEnumerate(items)

            // Advance by pageSize (not items.count) so that any compactMap-filtered
            // invalidated objects don't cause the next offset to stall.
            let nextOffset = offset + Self.pageSize
            if nextOffset < total {
                observer.finishEnumerating(upTo: encodePageOffset(nextOffset))
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

    // MARK: - Private: paging helpers

    /// Decodes a page offset from a page token, returning 0 for initial pages.
    ///
    /// Page tokens are encoded as 8-byte little-endian UInt64. Malformed tokens
    /// (wrong size) are treated as offset 0 rather than crashing.
    private func decodePageOffset(_ page: NSFileProviderPage) -> Int {
        if page == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage ||
           page == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage {
            return 0
        }
        let rawData = page.rawValue
        guard rawData.count == MemoryLayout<UInt64>.size else { return 0 }
        var raw: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &raw) { rawData.copyBytes(to: $0) }
        let value = UInt64(littleEndian: raw)
        return value > UInt64(Int.max) ? Int.max : Int(value)
    }

    /// Encodes a page offset into a page token as an 8-byte little-endian UInt64.
    private func encodePageOffset(_ offset: Int) -> NSFileProviderPage {
        var value = UInt64(offset).littleEndian
        return NSFileProviderPage(Data(bytes: &value, count: MemoryLayout<UInt64>.size))
    }

    // MARK: - Private: item building

    private func buildItems(offset: Int, limit: Int) throws -> ([FileProviderItem], Int) {
        let realm = try Realm(configuration: RealmConfiguration.realmConfig)

        if enumeratedItemIdentifier == .rootContainer {
            return buildSystemItems(realm: realm, offset: offset, limit: limit)
        }

        let raw = enumeratedItemIdentifier.rawValue
        if raw.hasPrefix(FileProviderItem.systemIdentifierPrefix) {
            let systemIdentifier = String(raw.dropFirst(FileProviderItem.systemIdentifierPrefix.count))
            return buildGameItems(systemIdentifier: systemIdentifier, realm: realm, offset: offset, limit: limit)
        }

        throw NSFileProviderError(.noSuchItem)
    }

    /// Returns `FileProviderItem`s for systems that have at least one locally-present ROM,
    /// sorted by system name and paginated to `[offset, offset+limit)`.
    private func buildSystemItems(realm: Realm, offset: Int, limit: Int) -> ([FileProviderItem], Int) {
        if cachedLocalSystemIDs == nil {
            cachedLocalSystemIDs = localGameSystemIdentifiers(realm: realm)
        }
        let localSystemIDs = cachedLocalSystemIDs!
        guard !localSystemIDs.isEmpty else { return ([], 0) }

        let systems = realm.objects(PVSystem.self)
            .filter("identifier IN %@", Array(localSystemIDs))
            .sorted(byKeyPath: "name", ascending: true)

        let total = systems.count
        guard offset < total else { return ([], total) }
        let end = min(offset + limit, total)
        let items = (offset..<end).compactMap { i -> FileProviderItem? in
            let pvSystem = systems[i]
            guard !pvSystem.isInvalidated else { return nil }
            return FileProviderItem(system: pvSystem.asDomain())
        }
        // Advance by the window size (end - offset), not items.count, so that
        // compactMap filtering out invalidated objects doesn't stall pagination.
        return (items, total)
    }

    /// Returns `FileProviderItem`s for locally-present games in the given system,
    /// sorted by title and paginated to `[offset, offset+limit)`.
    ///
    /// Local file presence cannot be queried at the Realm level, so all games are
    /// scanned once for `fileExists` checks on the first call; the result is cached in
    /// `cachedLocalGames` for subsequent pages. Only the page window is converted to items.
    private func buildGameItems(systemIdentifier: String, realm: Realm, offset: Int, limit: Int) -> ([FileProviderItem], Int) {
        if cachedLocalGames == nil {
            let games = realm.objects(PVGame.self)
                .filter("systemIdentifier == %@", systemIdentifier)
                .sorted(byKeyPath: "title", ascending: true)

            // Convert to domain snapshots immediately so no live Realm objects are retained.
            var localGames: [(game: Game, url: URL)] = []
            for pvGame in games {
                guard !pvGame.isInvalidated,
                      let romURL = pvGame.file?.url,
                      FileManager.default.fileExists(atPath: romURL.path) else { continue }
                localGames.append((pvGame.asDomain(), romURL))
            }
            cachedLocalGames = localGames
        }
        let localGames = cachedLocalGames!

        let total = localGames.count
        let page = localGames.dropFirst(offset).prefix(limit)
        let items = page.map { pair -> FileProviderItem in
            FileProviderItem(game: pair.game, romURL: pair.url)
        }
        return (Array(items), total)
    }

    /// Returns the set of system identifiers for which at least one ROM file is present on disk.
    ///
    /// - Note: This performs an O(N) scan with `fileExists` checks across all games on the first
    ///   call per enumerator instance. The result is cached in `cachedLocalSystemIDs` for the
    ///   lifetime of this instance, so subsequent pages are free. A future optimisation could
    ///   store a "locallyPresent" flag in the Realm schema to avoid filesystem I/O entirely.
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
