//
//  CheatCatalogTests.swift
//  PVUIBaseTests
//
//  The cheats menu's one list: saved cheats, the bundled database's and the
//  online sources' merged without duplicates, and the loader that fills it.
//

import Foundation
import Testing
import PVLibrary
@testable import PVUIBase

private func entry(
    _ name: String,
    _ code: String,
    device: String = "Game Genie",
    format: String? = nil,
    category: String = "General",
    online: Bool = false
) -> CheatDatabaseEntry {
    CheatDatabaseEntry(
        id: code.count,
        cheatName: name,
        cheatCode: code,
        cheatDescription: nil,
        deviceName: device,
        deviceFormat: format,
        category: category,
        romTitle: "Test Game",
        isOnlineResult: online
    )
}

private func saved(_ id: String, _ name: String, _ code: String, enabled: Bool = false) -> SavedCheatSnapshot {
    SavedCheatSnapshot(id: id, name: name, code: code, codeType: "Game Genie", isEnabled: enabled)
}

struct CheatCatalogMergeTests {

    @Test func ordersSavedThenBundledThenOnline() {
        let items = CheatCatalog.merge(
            saved: [saved("s1", "Mine", "AAAA-AAAA")],
            bundled: [entry("Bundled", "BBBB-BBBB")],
            online: [entry("Online", "CCCC-CCCC", online: true)]
        )
        #expect(items.map(\.name) == ["Mine", "Bundled", "Online"])
        #expect(items.map(\.source) == [.saved, .bundled, .online])
    }

    @Test func nothingFromADatabaseIsEnabled() {
        let items = CheatCatalog.merge(
            saved: [],
            bundled: [entry("A", "1111")],
            online: [entry("B", "2222", online: true)]
        )
        #expect(items.allSatisfy { !$0.isEnabled })
        #expect(items.allSatisfy { $0.savedID == nil })
    }

    @Test func savedCheatKeepsItsStateAndHidesTheSameDatabaseCode() {
        let items = CheatCatalog.merge(
            saved: [saved("s1", "Infinite Lives", "SXIOPO", enabled: true)],
            bundled: [entry("Infinite lives (database)", "SXIOPO")],
            online: [entry("Lives", "sxiopo", online: true)]
        )
        #expect(items.count == 1)
        #expect(items[0].isEnabled)
        #expect(items[0].savedID == "s1")
        #expect(items[0].name == "Infinite Lives")
    }

    @Test func onlineDuplicateOfBundledIsDropped() {
        let items = CheatCatalog.merge(
            saved: [],
            bundled: [entry("Bundled name", "7E0DBE:09")],
            online: [entry("Online name", "7E0DBE:09", online: true), entry("Other", "7E0DBF:01", online: true)]
        )
        #expect(items.map(\.name) == ["Bundled name", "Other"])
    }

    /// Saved codes are stored normalized (upper case, separators as "+"), while
    /// databases keep the code as published.
    @Test func comparesCodesIgnoringCaseAndSeparators() {
        let items = CheatCatalog.merge(
            saved: [saved("s1", "Mine", "8009A5C4+0063+8009A5C6+0009")],
            bundled: [entry("Same, spaced", "8009a5c4 0063\n8009A5C6 0009")],
            online: [entry("Same, comma", "8009A5C4 0063, 8009A5C6 0009", online: true)]
        )
        #expect(items.count == 1)
    }

    @Test func duplicatesWithinOneSourceAreDropped() {
        let items = CheatCatalog.merge(
            saved: [],
            bundled: [entry("First", "ABCD-1234"), entry("Second", "abcd-1234")],
            online: []
        )
        #expect(items.map(\.name) == ["First"])
    }

    @Test func everySavedCheatIsKeptEvenWithTheSameCode() {
        let items = CheatCatalog.merge(
            saved: [saved("s1", "One", "AAAA"), saved("s2", "Two", "AAAA")],
            bundled: [],
            online: []
        )
        #expect(items.map(\.savedID) == ["s1", "s2"])
        #expect(Set(items.map(\.id)).count == 2)
    }

    @Test func entriesWithoutACodeAreDropped() {
        let items = CheatCatalog.merge(
            saved: [],
            bundled: [entry("Empty", ""), entry("Blank", "   "), entry("Real", "AAAA")],
            online: []
        )
        #expect(items.map(\.name) == ["Real"])
    }

    @Test func idsAreUnique() {
        let items = CheatCatalog.merge(
            saved: [saved("s1", "One", "AAAA")],
            bundled: [entry("B1", "BBBB"), entry("B2", "CCCC")],
            online: [entry("O1", "DDDD", online: true), entry("O2", "BBBB", online: true)]
        )
        #expect(Set(items.map(\.id)).count == items.count)
        #expect(items.count == 4)
    }

    @Test func missingNamesGetAPlaceholder() {
        let items = CheatCatalog.merge(
            saved: [saved("s1", "", "AAAA")],
            bundled: [entry("  ", "BBBB")],
            online: []
        )
        #expect(items.map(\.name) == [CheatCatalog.untitledName, CheatCatalog.untitledName])
    }

    /// The disc-serial lookup answers together with the bundled search, and
    /// its codes still came from the network.
    @Test func anEntryMarkedOnlineIsOnlineWhicheverListItCameIn() {
        let items = CheatCatalog.merge(
            saved: [],
            bundled: [entry("Gecko", "040A1B2C 60000000", device: "Gecko", online: true)],
            online: []
        )
        #expect(items.map(\.source) == [.online])
    }

    @Test func codeTypeUsesTheCoresNameForAKnownDevice() {
        #expect(CheatCatalog.codeType(for: entry("A", "1", device: "GameShark")) == "Game Shark")
        #expect(CheatCatalog.codeType(for: entry("A", "1", device: "GameHacking.org")) == "GameHacking.org")
    }

    @Test func detailLeavesOutTheGeneralCategory() {
        let items = CheatCatalog.merge(
            saved: [],
            bundled: [
                entry("A", "1111", device: "Game Genie", category: "General"),
                entry("B", "2222", device: "Game Genie", format: "XXXX-YYYY", category: "Unlock")
            ],
            online: []
        )
        #expect(items[0].detail == "Game Genie")
        #expect(items[1].detail == "XXXX-YYYY · Unlock")
    }
}

struct CheatCatalogFilterTests {
    private let items = CheatCatalog.merge(
        saved: [saved("s1", "Infinite Lives", "SXIOPO")],
        bundled: [entry("Moon Jump", "AEAEAE", category: "Movement")],
        online: [entry("All Weapons", "7E0DBE:09", device: "Pro Action Replay", online: true)]
    )

    @Test func blankTextKeepsEverything() {
        #expect(CheatCatalog.filter(items, matching: "") == items)
        #expect(CheatCatalog.filter(items, matching: "  ") == items)
    }

    @Test func matchesNameCodeAndDetailIgnoringCase() {
        #expect(CheatCatalog.filter(items, matching: "moon").map(\.name) == ["Moon Jump"])
        #expect(CheatCatalog.filter(items, matching: "7e0d").map(\.name) == ["All Weapons"])
        #expect(CheatCatalog.filter(items, matching: "movement").map(\.name) == ["Moon Jump"])
        #expect(CheatCatalog.filter(items, matching: "zzz") == [])
    }
}

struct CheatCodeNormalizerTests {
    @Test func normalizingTwiceChangesNothing() {
        let once = CheatCodeNormalizer.normalize("8009a5c4 0063\n8009A5C6 0009")
        #expect(once == "8009A5C4+0063+8009A5C6+0009")
        #expect(CheatCodeNormalizer.normalize(once) == once)
    }
}

@MainActor
struct CheatCatalogLoaderTests {
    private struct Offline: Error {}

    /// Counts the online lookups and remembers whether the last one was forced.
    private actor Calls {
        private(set) var online = 0
        private(set) var lastWasForced = false
        func recordOnline(forced: Bool) {
            online += 1
            lastWasForced = forced
        }
    }

    private let query = CheatCatalogQuery(gameMD5: "abc123", gameTitle: "Test Game", systemName: "Test - System", romSerial: nil)

    @Test func loadsBundledAndOnline() async {
        let loader = CheatCatalogLoader(
            query: query,
            cache: CheatCatalogSessionCache(),
            searchBundled: { _ in [entry("B", "1111")] },
            searchOnline: { _, _ in [entry("O", "2222", online: true)] }
        )
        #expect(loader.onlineState == .idle)
        await loader.loadIfNeeded()
        #expect(loader.bundled.map(\.cheatName) == ["B"])
        #expect(loader.online.map(\.cheatName) == ["O"])
        #expect(loader.onlineState == .loaded)
        #expect(!loader.isLoading)
    }

    @Test func offlineKeepsTheBundledCheatsAndReportsFailure() async {
        let loader = CheatCatalogLoader(
            query: query,
            cache: CheatCatalogSessionCache(),
            searchBundled: { _ in [entry("B", "1111")] },
            searchOnline: { _, _ in throw Offline() }
        )
        await loader.loadIfNeeded()
        #expect(loader.bundled.count == 1)
        #expect(loader.online.isEmpty)
        #expect(loader.onlineState == .failed)
        #expect(!loader.isLoading)
    }

    @Test func aBundledSearchErrorStillShowsOnlineCheats() async {
        let loader = CheatCatalogLoader(
            query: query,
            cache: CheatCatalogSessionCache(),
            searchBundled: { _ in throw Offline() },
            searchOnline: { _, _ in [entry("O", "2222", online: true)] }
        )
        await loader.loadIfNeeded()
        #expect(loader.bundled.isEmpty)
        #expect(loader.online.count == 1)
        #expect(loader.onlineState == .loaded)
    }

    @Test func reopeningShowsCachedOnlineCheatsWithoutFetching() async {
        let cache = CheatCatalogSessionCache()
        let calls = Calls()
        let online: CheatCatalogLoader.OnlineSearch = { _, forced in
            await calls.recordOnline(forced: forced)
            return [entry("O", "2222", online: true)]
        }
        let first = CheatCatalogLoader(query: query, cache: cache, searchBundled: { _ in [] }, searchOnline: online)
        await first.loadIfNeeded()
        #expect(await calls.online == 1)

        let second = CheatCatalogLoader(query: query, cache: cache, searchBundled: { _ in [] }, searchOnline: online)
        #expect(second.online.map(\.cheatName) == ["O"])
        #expect(second.onlineState == .loaded)
        await second.loadIfNeeded()
        #expect(await calls.online == 1)
    }

    @Test func refreshFetchesAgainPastTheCache() async {
        let cache = CheatCatalogSessionCache()
        let calls = Calls()
        let loader = CheatCatalogLoader(
            query: query,
            cache: cache,
            searchBundled: { _ in [] },
            searchOnline: { _, forced in
                await calls.recordOnline(forced: forced)
                return [entry("O", "2222", online: true)]
            }
        )
        await loader.loadIfNeeded()
        #expect(await calls.lastWasForced == false)
        await loader.refresh()
        #expect(await calls.online == 2)
        #expect(await calls.lastWasForced)
    }

    @Test func aFailedRefreshKeepsWhatWasShown() async {
        let calls = Calls()
        let loader = CheatCatalogLoader(
            query: query,
            cache: CheatCatalogSessionCache(),
            searchBundled: { _ in [] },
            searchOnline: { _, forced in
                await calls.recordOnline(forced: forced)
                if forced { throw Offline() }
                return [entry("O", "2222", online: true)]
            }
        )
        await loader.loadIfNeeded()
        await loader.refresh()
        #expect(loader.online.map(\.cheatName) == ["O"])
        #expect(loader.onlineState == .failed)
    }

    @Test func aFailedLookupIsNotCached() async {
        let cache = CheatCatalogSessionCache()
        let failing = CheatCatalogLoader(
            query: query,
            cache: cache,
            searchBundled: { _ in [] },
            searchOnline: { _, _ in throw Offline() }
        )
        await failing.loadIfNeeded()
        #expect(cache.online(for: "ABC123") == nil)
    }

    @Test func loadIfNeededRunsOnce() async {
        let calls = Calls()
        let loader = CheatCatalogLoader(
            query: CheatCatalogQuery(gameMD5: nil, gameTitle: nil, systemName: nil, romSerial: nil),
            cache: CheatCatalogSessionCache(),
            searchBundled: { _ in [] },
            searchOnline: { _, forced in
                await calls.recordOnline(forced: forced)
                return []
            }
        )
        await loader.loadIfNeeded()
        await loader.loadIfNeeded()
        #expect(await calls.online == 1)
    }

    @Test func sessionCacheDropsTheOldestGame() {
        let cache = CheatCatalogSessionCache()
        for index in 0...CheatCatalogSessionCache.capacity {
            cache.store([], for: "game\(index)")
        }
        #expect(cache.online(for: "game0") == nil)
        #expect(cache.online(for: "game1") != nil)
        #expect(cache.online(for: "game\(CheatCatalogSessionCache.capacity)") != nil)
    }

    @Test func cacheKeyPrefersTheMD5() {
        #expect(query.cacheKey == "ABC123")
        let untitled = CheatCatalogQuery(gameMD5: "", gameTitle: nil, systemName: nil, romSerial: nil)
        #expect(untitled.cacheKey == nil)
        let titled = CheatCatalogQuery(gameMD5: nil, gameTitle: "Game", systemName: "Sys", romSerial: nil)
        #expect(titled.cacheKey == "Sys|Game")
    }
}
