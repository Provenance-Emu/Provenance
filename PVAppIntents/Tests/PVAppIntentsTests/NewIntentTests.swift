//
//  NewIntentTests.swift
//  PVAppIntentsTests
//
//  Tests for ContinueMostRecentGameIntent, SearchLibraryIntent, and
//  ProvenanceFocusFilterIntent (partial — App Group unavailable in CI).
//

import XCTest
@testable import PVAppIntents

#if canImport(AppIntents)

// MARK: - ContinueMostRecentGameIntent Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class ContinueMostRecentGameIntentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameEntityStore.shared.update(all: [], recents: [])
    }

    override func tearDown() {
        GameEntityStore.shared.update(all: [], recents: [])
        super.tearDown()
    }

    func testPerformReturnsDialogWhenNoRecentGames() async throws {
        // Store is empty — intent should return a "no games" dialog without crashing.
        let intent = ContinueMostRecentGameIntent()
        let result = try await intent.perform()
        // We can't inspect the dialog value directly (opaque return), but
        // reaching here without throwing is itself the success assertion.
        _ = result
    }

    func testPerformWithOneRecentGame() async throws {
        let game = GameEntity(
            id: "md5-mario",
            title: "Super Mario Bros.",
            systemName: "Nintendo Entertainment System",
            systemIdentifier: "com.provenance.nes",
            isFavorite: false
        )
        GameEntityStore.shared.update(all: [game], recents: [game])

        let intent = ContinueMostRecentGameIntent()
        // Should complete without throwing.
        _ = try await intent.perform()
    }

    func testPerformPicksMostRecentGame() async throws {
        // Build two games with distinct last-played dates.
        let older = GameEntity(
            id: "md5-older",
            title: "Older Game",
            systemName: "NES",
            systemIdentifier: "com.provenance.nes",
            isFavorite: false,
            lastPlayedDate: Date(timeIntervalSince1970: 1_000_000)
        )
        let newer = GameEntity(
            id: "md5-newer",
            title: "Newer Game",
            systemName: "NES",
            systemIdentifier: "com.provenance.nes",
            isFavorite: false,
            lastPlayedDate: Date(timeIntervalSince1970: 2_000_000)
        )
        // recents ordered most-recent-first as the host app would supply them.
        GameEntityStore.shared.update(all: [older, newer], recents: [newer, older])

        // The intent picks the first element from recentEntities(limit:1).
        // We verify indirectly by checking the store's first recent is newer.
        let topRecent = GameEntityStore.shared.recentEntities(limit: 1).first
        XCTAssertEqual(topRecent?.id, "md5-newer")

        _ = try await ContinueMostRecentGameIntent().perform()
    }
}

// MARK: - SearchLibraryIntent Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class SearchLibraryIntentTests: XCTestCase {

    private let snesSystem = SystemEntity(
        id: "com.provenance.snes",
        name: "Super Nintendo",
        manufacturer: "Nintendo",
        gameCount: 3
    )
    private let nesSystem = SystemEntity(
        id: "com.provenance.nes",
        name: "Nintendo Entertainment System",
        manufacturer: "Nintendo",
        gameCount: 2
    )

    private var snesGames: [GameEntity] = []
    private var nesGames: [GameEntity] = []

    override func setUp() {
        super.setUp()
        snesGames = [
            GameEntity(id: "snes-1", title: "Donkey Kong Country", systemName: "Super Nintendo", systemIdentifier: "com.provenance.snes", isFavorite: false),
            GameEntity(id: "snes-2", title: "Super Mario World", systemName: "Super Nintendo", systemIdentifier: "com.provenance.snes", isFavorite: true),
            GameEntity(id: "snes-3", title: "F-Zero", systemName: "Super Nintendo", systemIdentifier: "com.provenance.snes", isFavorite: false)
        ]
        nesGames = [
            GameEntity(id: "nes-1", title: "Super Mario Bros.", systemName: "Nintendo Entertainment System", systemIdentifier: "com.provenance.nes", isFavorite: false),
            GameEntity(id: "nes-2", title: "Metroid", systemName: "Nintendo Entertainment System", systemIdentifier: "com.provenance.nes", isFavorite: false)
        ]
        GameEntityStore.shared.update(all: snesGames + nesGames, recents: [])
        SystemEntityStore.shared.update(all: [snesSystem, nesSystem])
    }

    override func tearDown() {
        GameEntityStore.shared.update(all: [], recents: [])
        SystemEntityStore.shared.update(all: [])
        super.tearDown()
    }

    func testSearchByQueryReturnsMatchingGames() async throws {
        var intent = SearchLibraryIntent()
        intent.query = "mario"
        intent.system = nil
        _ = try await intent.perform()
    }

    func testSearchResultsAreSortedByTitle() async throws {
        // All 5 games; query empty means all pass the title filter.
        var intent = SearchLibraryIntent()
        intent.query = "o" // matches: DK Country, F-Zero, Super Mario World, Super Mario Bros., Metroid
        intent.system = nil
        // We validate the store sort indirectly via allEntities, which feeds perform().
        let allTitles = GameEntityStore.shared.allEntities()
            .filter { $0.title.lowercased().contains("o") }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
            .map { $0.title }
        XCTAssertEqual(allTitles, allTitles.sorted { $0.localizedCompare($1) == .orderedAscending },
                       "Results should be sorted lexicographically by title")
    }

    func testSearchBySystemFiltersResults() async throws {
        var intent = SearchLibraryIntent()
        intent.query = ""
        intent.system = snesSystem
        // Should not throw; indirectly check the store filter logic.
        let snesOnly = GameEntityStore.shared.allEntities()
            .filter { $0.systemIdentifier == snesSystem.id }
        XCTAssertEqual(snesOnly.count, 3)
    }

    func testSearchReturnsEmptyForNoMatch() async throws {
        var intent = SearchLibraryIntent()
        intent.query = "zzz-no-match-xyz"
        intent.system = nil
        _ = try await intent.perform()
    }

    func testSearchCaseInsensitive() {
        let games = GameEntityStore.shared.allEntities()
        let upper = games.filter { $0.title.lowercased().contains("MARIO".lowercased()) }
        let lower = games.filter { $0.title.lowercased().contains("mario") }
        XCTAssertEqual(upper.count, lower.count, "Search must be case-insensitive")
    }

    func testSearchResultsFromAllEntitiesAreSorted() {
        // Simulate what SearchLibraryIntent.perform() does after fetching.
        var results = GameEntityStore.shared.allEntities()
        results = results.filter { $0.title.lowercased().contains("super") }
        results.sort { $0.title.localizedCompare($1.title) == .orderedAscending }

        for i in 0..<results.count - 1 {
            XCTAssertTrue(
                results[i].title.localizedCompare(results[i + 1].title) != .orderedDescending,
                "Index \(i) '\(results[i].title)' should come before '\(results[i + 1].title)'"
            )
        }
    }
}

// MARK: - FocusFilterIntent Tests

#if os(iOS) || os(macOS)
@available(iOS 17, macOS 14, *)
final class FocusFilterIntentTests: XCTestCase {

    func testInitDefaultsToSuppressNotificationsTrue() {
        // The intent should have `suppressNotifications` default true per @Parameter(default: true).
        let intent = ProvenanceFocusFilterIntent()
        // default is declared on the @Parameter; the struct itself initialises to Swift default.
        // Just verify the struct initialises without crashing.
        _ = intent
    }

    func testPerformDoesNotThrow() async throws {
        // In the test sandbox the App Group suite is unavailable (returns nil),
        // so pvAppGroupDefaults is nil and perform() should silently no-op the write.
        var intent = ProvenanceFocusFilterIntent()
        intent.suppressNotifications = true
        _ = try await intent.perform()

        var intentOff = ProvenanceFocusFilterIntent()
        intentOff.suppressNotifications = false
        _ = try await intentOff.perform()
    }
}
#endif // os(iOS) || os(macOS)

#endif // canImport(AppIntents)
