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
import PVPrimitives

/// Enumerates items in the Provenance ROM library for the Files.app file provider.
///
/// Root lists category folders (**Systems**, **Publishers**, **Years**, **Regions**, **Ratings**).
/// Canonical ROM files (`game:<md5>`) live only under **Systems**; other axes use symlink rows.
///
/// Realm access is centralized in ``RomFileProviderLibrary`` (CPDI snapshots, same App Group as Spotlight / Top Shelf).
final class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {

    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let anchor = NSFileProviderSyncAnchor(Data("provenance-v2".utf8))
    private static let pageSize = 100

    private var cachedLocalSystemIDs: Set<String>?
    private var cachedCanonicalGames: [(game: Game, url: URL)]?
    private var cachedLocalRows: [RomFileProviderLibrary.LocalEntry]?

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let offset = decodePageOffset(page)
        do {
            let (items, total) = try buildItems(offset: offset, limit: Self.pageSize)
            observer.didEnumerate(items)
            let nextOffset = offset <= Int.max - Self.pageSize ? offset + Self.pageSize : Int.max
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
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(anchor)
    }

    private func decodePageOffset(_ page: NSFileProviderPage) -> Int {
        let initialByName = NSFileProviderPage.initialPageSortedByName as Data
        let initialByDate = NSFileProviderPage.initialPageSortedByDate as Data
        if page.rawValue == initialByName || page.rawValue == initialByDate {
            return 0
        }
        let rawData = page.rawValue
        guard rawData.count == MemoryLayout<UInt64>.size else { return 0 }
        var raw: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &raw) { rawData.copyBytes(to: $0) }
        let value = UInt64(littleEndian: raw)
        return value > UInt64(Int.max) ? Int.max : Int(value)
    }

    private func encodePageOffset(_ offset: Int) -> NSFileProviderPage {
        var value = UInt64(offset).littleEndian
        let data = withUnsafeBytes(of: &value) { Data($0) }
        return NSFileProviderPage(data)
    }

    // MARK: - CPDI local entry cache

    private func loadLocalRowsIfNeeded() -> [RomFileProviderLibrary.LocalEntry] {
        if let cached = cachedLocalRows { return cached }
        let rows = RomFileProviderLibrary.loadAllLocalEntries()
        cachedLocalRows = rows
        return rows
    }

    // MARK: - buildItems

    private func buildItems(offset: Int, limit: Int) throws -> ([FileProviderItem], Int) {
        let raw = enumeratedItemIdentifier.rawValue

        if enumeratedItemIdentifier == .rootContainer {
            let cats = RomFileProviderRootCategory.allCases
                .sorted { $0.folderDisplayName.localizedCaseInsensitiveCompare($1.folderDisplayName) == .orderedAscending }
                .map { FileProviderItem(category: $0) }
            return pageSlice(items: cats, offset: offset, limit: limit)
        }

        if let cat = RomFileProviderRootCategory(rawValue: raw) {
            return try buildCategoryContents(cat: cat, offset: offset, limit: limit)
        }

        if raw.hasPrefix(FileProviderItem.systemIdentifierPrefix) {
            let systemIdentifier = String(raw.dropFirst(FileProviderItem.systemIdentifierPrefix.count))
            return buildCanonicalGameItems(systemIdentifier: systemIdentifier, offset: offset, limit: limit)
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.publisherAllGamesPrefix) {
            let enc = String(raw.dropFirst(RomFileProviderVirtualPath.publisherAllGamesPrefix.count))
            guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { throw NSFileProviderError(.noSuchItem) }
            return try buildSymlinkGameItems(
                rows: RomFileProviderLibrary.sortedByGameTitle(loadLocalRowsIfNeeded().filter { $0.publisherKey == groupingKey }),
                parentRaw: raw,
                parentIdentifier: enumeratedItemIdentifier,
                offset: offset,
                limit: limit
            )
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.publisherSystemPrefix) {
            let rest = String(raw.dropFirst(RomFileProviderVirtualPath.publisherSystemPrefix.count))
            guard let colon = rest.firstIndex(of: ":") else { throw NSFileProviderError(.noSuchItem) }
            let enc = String(rest[..<colon])
            let systemId = String(rest[rest.index(after: colon)...])
            guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { throw NSFileProviderError(.noSuchItem) }
            let filtered = RomFileProviderLibrary.sortedByGameTitle(loadLocalRowsIfNeeded().filter { $0.publisherKey == groupingKey && $0.game.systemIdentifier == systemId })
            return try buildSymlinkGameItems(rows: filtered, parentRaw: raw, parentIdentifier: enumeratedItemIdentifier, offset: offset, limit: limit)
        }

        if raw.hasPrefix(RomFileProviderVirtualPath.publisherFolderPrefix) {
            let enc = String(raw.dropFirst(RomFileProviderVirtualPath.publisherFolderPrefix.count))
            guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { throw NSFileProviderError(.noSuchItem) }
            return try buildPublisherInterior(groupingKey: groupingKey, encodedSegment: enc, offset: offset, limit: limit)
        }

        if raw.hasPrefix("year:") {
            let yearKey = String(raw.dropFirst("year:".count))
            let filtered = RomFileProviderLibrary.sortedByGameTitle(loadLocalRowsIfNeeded().filter { $0.yearKey == yearKey })
            return try buildSymlinkGameItems(rows: filtered, parentRaw: raw, parentIdentifier: enumeratedItemIdentifier, offset: offset, limit: limit)
        }

        if raw.hasPrefix("region:") {
            let enc = String(raw.dropFirst("region:".count))
            guard let groupingKey = RomFileProviderVirtualPath.decodeSegment(enc) else { throw NSFileProviderError(.noSuchItem) }
            let filtered = RomFileProviderLibrary.sortedByGameTitle(loadLocalRowsIfNeeded().filter { $0.regionKey == groupingKey })
            return try buildSymlinkGameItems(rows: filtered, parentRaw: raw, parentIdentifier: enumeratedItemIdentifier, offset: offset, limit: limit)
        }

        if raw.hasPrefix("rating:") {
            let key = String(raw.dropFirst("rating:".count))
            let filtered = RomFileProviderLibrary.sortedByGameTitle(loadLocalRowsIfNeeded().filter { $0.ratingKey == key })
            return try buildSymlinkGameItems(rows: filtered, parentRaw: raw, parentIdentifier: enumeratedItemIdentifier, offset: offset, limit: limit)
        }

        throw NSFileProviderError(.noSuchItem)
    }

    private func pageSlice(items: [FileProviderItem], offset: Int, limit: Int) -> ([FileProviderItem], Int) {
        let total = items.count
        guard offset < total else { return ([], total) }
        let end = min(offset + limit, total)
        return (Array(items[offset..<end]), total)
    }

    private func buildCategoryContents(cat: RomFileProviderRootCategory, offset: Int, limit: Int) throws -> ([FileProviderItem], Int) {
        switch cat {
        case .systems:
            return buildSystemFolderItems(offset: offset, limit: limit)
        case .publishers:
            let rows = loadLocalRowsIfNeeded()
            var titles: [String: String] = [:]
            for row in rows where titles[row.publisherKey] == nil {
                titles[row.publisherKey] = row.publisherTitle
            }
            let keys = titles.keys.sorted { k1, k2 in
                (titles[k1] ?? "").localizedCaseInsensitiveCompare(titles[k2] ?? "") == .orderedAscending
            }
            let parent = NSFileProviderItemIdentifier(cat.rawIdentifier)
            let items = keys.compactMap { key -> FileProviderItem? in
                guard let title = titles[key] else { return nil }
                return FileProviderItem(publisherFolderGroupingKey: key, title: title, parentItemIdentifier: parent)
            }
            return pageSlice(items: items, offset: offset, limit: limit)
        case .years:
            let rows = loadLocalRowsIfNeeded()
            var seen = Set<String>()
            for row in rows { seen.insert(row.yearKey) }
            let sortedKeys = seen.sorted { a, b in
                if a == "Unknown" { return false }
                if b == "Unknown" { return true }
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
            let parent = NSFileProviderItemIdentifier(cat.rawIdentifier)
            let items = sortedKeys.map { FileProviderItem(yearFolder: $0, parentItemIdentifier: parent) }
            return pageSlice(items: items, offset: offset, limit: limit)
        case .regions:
            let rows = loadLocalRowsIfNeeded()
            var map: [String: String] = [:]
            for row in rows where map[row.regionKey] == nil {
                map[row.regionKey] = row.regionTitle
            }
            let keys = map.keys.sorted { k1, k2 in
                (map[k1] ?? "").localizedCaseInsensitiveCompare(map[k2] ?? "") == .orderedAscending
            }
            let parent = NSFileProviderItemIdentifier(cat.rawIdentifier)
            let items = keys.compactMap { key -> FileProviderItem? in
                guard let title = map[key] else { return nil }
                return FileProviderItem(regionFolderGroupingKey: key, title: title, parentItemIdentifier: parent)
            }
            return pageSlice(items: items, offset: offset, limit: limit)
        case .ratings:
            let rows = loadLocalRowsIfNeeded()
            var seen = Set<String>()
            for row in rows { seen.insert(row.ratingKey) }
            let order = ["unrated", "0", "1", "2", "3", "4", "5"]
            let sortedKeys = order.filter { seen.contains($0) } + seen.filter { !order.contains($0) }.sorted()
            let parent = NSFileProviderItemIdentifier(cat.rawIdentifier)
            let items = sortedKeys.map { key -> FileProviderItem in
                FileProviderItem(
                    ratingFolderKey: key,
                    title: RomFileProviderLibrary.ratingFolderLabel(forKey: key),
                    parentItemIdentifier: parent
                )
            }
            return pageSlice(items: items, offset: offset, limit: limit)
        }
    }

    private func buildSystemFolderItems(offset: Int, limit: Int) -> ([FileProviderItem], Int) {
        if cachedLocalSystemIDs == nil {
            cachedLocalSystemIDs = Set(loadLocalRowsIfNeeded().map { $0.game.systemIdentifier })
        }
        guard let localSystemIDs = cachedLocalSystemIDs, !localSystemIDs.isEmpty else { return ([], 0) }

        let systems = RomFileProviderLibrary.realm.objects(PVSystem.self)
            .filter("identifier IN %@", Array(localSystemIDs))
            .sorted(byKeyPath: "name", ascending: true)

        let total = systems.count
        guard offset < total else { return ([], total) }
        let end = min(offset + limit, total)
        let parent = NSFileProviderItemIdentifier(RomFileProviderRootCategory.systems.rawIdentifier)
        let items = (offset..<end).compactMap { i -> FileProviderItem? in
            let pvSystem = systems[i]
            guard !pvSystem.isInvalidated else { return nil }
            return FileProviderItem(system: pvSystem.asDomain(), parentItemIdentifier: parent)
        }
        return (items, total)
    }

    private func buildCanonicalGameItems(systemIdentifier: String, offset: Int, limit: Int) -> ([FileProviderItem], Int) {
        if cachedCanonicalGames == nil {
            let localGames = RomFileProviderLibrary.sortedByGameTitle(
                loadLocalRowsIfNeeded().filter { $0.game.systemIdentifier == systemIdentifier }
            ).map { ($0.game, $0.romURL) }
            cachedCanonicalGames = localGames
        }
        guard let localGames = cachedCanonicalGames else { return ([], 0) }
        let total = localGames.count
        let page = localGames.dropFirst(offset).prefix(limit)
        let items = page.map { pair -> FileProviderItem in
            FileProviderItem(game: pair.game, romURL: pair.url)
        }
        return (Array(items), total)
    }

    private func buildPublisherInterior(groupingKey: String, encodedSegment: String, offset: Int, limit: Int) throws -> ([FileProviderItem], Int) {
        let rows = loadLocalRowsIfNeeded().filter { $0.publisherKey == groupingKey }
        let pubFolderId = NSFileProviderItemIdentifier(RomFileProviderVirtualPath.publisherFolderPrefix + encodedSegment)
        let allGames = FileProviderItem(
            publisherAllGamesFolderGroupingKey: groupingKey,
            parentItemIdentifier: pubFolderId
        )

        var systemIds = Set<String>()
        for row in rows { systemIds.insert(row.game.systemIdentifier) }

        var children: [FileProviderItem] = [allGames]
        if !systemIds.isEmpty {
            let systems = RomFileProviderLibrary.realm.objects(PVSystem.self)
                .filter("identifier IN %@", Array(systemIds))
                .sorted(byKeyPath: "name", ascending: true)
            for pvSystem in systems {
                guard !pvSystem.isInvalidated else { continue }
                children.append(FileProviderItem(
                    publisherSystemFolderGroupingKey: groupingKey,
                    system: pvSystem.asDomain(),
                    parentItemIdentifier: pubFolderId
                ))
            }
        }
        return pageSlice(items: children, offset: offset, limit: limit)
    }

    private func buildSymlinkGameItems(
        rows: [RomFileProviderLibrary.LocalEntry],
        parentRaw: String,
        parentIdentifier: NSFileProviderItemIdentifier,
        offset: Int,
        limit: Int
    ) throws -> ([FileProviderItem], Int) {
        let total = rows.count
        guard offset < total else { return ([], total) }
        let end = min(offset + limit, total)
        let slice = rows[offset..<end]
        let items = slice.map { row -> FileProviderItem in
            let md5Key = row.game.md5.uppercased()
            let sid = RomFileProviderVirtualPath.symlinkIdentifier(gameMD5: md5Key, parentItemRaw: parentRaw)
            return FileProviderItem(
                symlinkTo: row.game,
                romURL: row.romURL,
                symlinkRawId: sid,
                targetGameMD5: md5Key,
                parentItemIdentifier: parentIdentifier
            )
        }
        return (Array(items), total)
    }
}
