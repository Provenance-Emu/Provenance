// CheatCatalogLoader.swift
// PVUI
//
// Looks up the cheats known for the running game when the cheats menu opens:
// the bundled database straight away, the online sources in the background.

import Foundation
import Observation
import PVLibrary
import PVLogging

/// The game the cheats menu is open for, as the cheat sources need it.
struct CheatCatalogQuery: Equatable, Sendable {
    let gameMD5: String?
    let gameTitle: String?
    /// The libretro cheat folder name of the game's system.
    let systemName: String?
    let romSerial: String?

    /// Identifies the game in the session cache; `nil` when nothing identifies it.
    var cacheKey: String? {
        if let gameMD5, !gameMD5.isEmpty { return gameMD5.uppercased() }
        guard let gameTitle, !gameTitle.isEmpty else { return nil }
        return "\(systemName ?? "")|\(gameTitle)"
    }
}

/// The online cheats found for games this session, so that opening the menu
/// again shows them at once. The sources keep their own 24-hour disk cache;
/// this one saves the wait for them to answer.
@MainActor
final class CheatCatalogSessionCache {
    static let shared = CheatCatalogSessionCache()

    /// Games remembered before the oldest is dropped.
    static let capacity = 24

    private var entries: [String: [CheatDatabaseEntry]] = [:]
    private var order: [String] = []

    init() {}

    func online(for key: String) -> [CheatDatabaseEntry]? { entries[key] }

    func store(_ online: [CheatDatabaseEntry], for key: String) {
        order.removeAll { $0 == key }
        order.append(key)
        entries[key] = online
        while order.count > Self.capacity {
            entries.removeValue(forKey: order.removeFirst())
        }
    }
}

/// Loads the cheats on offer for one game and reports how far it is.
@MainActor
@Observable
final class CheatCatalogLoader {
    /// Where the background online lookup stands.
    enum OnlineState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        /// The online sources could not be reached. The list still shows the
        /// saved and bundled cheats, and the cheats fetched earlier if any.
        case failed
    }

    typealias BundledSearch = @Sendable (CheatCatalogQuery) async throws -> [CheatDatabaseEntry]
    /// The flag is true for a refresh the user asked for, which skips the caches.
    typealias OnlineSearch = @Sendable (CheatCatalogQuery, Bool) async throws -> [CheatDatabaseEntry]

    private(set) var bundled: [CheatDatabaseEntry] = []
    private(set) var online: [CheatDatabaseEntry] = []
    private(set) var isLoadingBundled = false
    private(set) var onlineState: OnlineState = .idle

    /// True while either lookup runs.
    var isLoading: Bool { isLoadingBundled || onlineState == .loading }

    private let query: CheatCatalogQuery
    private let cache: CheatCatalogSessionCache
    private let searchBundled: BundledSearch
    private let searchOnline: OnlineSearch
    private var hasLoaded = false

    init(
        query: CheatCatalogQuery,
        cache: CheatCatalogSessionCache = .shared,
        searchBundled: @escaping BundledSearch = CheatCatalogLoader.defaultBundledSearch,
        searchOnline: @escaping OnlineSearch = CheatCatalogLoader.defaultOnlineSearch
    ) {
        self.query = query
        self.cache = cache
        self.searchBundled = searchBundled
        self.searchOnline = searchOnline
        if let key = query.cacheKey, let cached = cache.online(for: key) {
            online = cached
            onlineState = .loaded
        }
    }

    /// Loads both sources the first time the menu appears. Later calls do nothing.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        async let bundledDone: Void = loadBundled()
        // Cheats remembered from earlier this session are already showing.
        if onlineState != .loaded {
            await loadOnline(forceRefresh: false)
        }
        await bundledDone
    }

    /// Fetches the online cheats again, past every cache. The user's refresh.
    func refresh() async {
        hasLoaded = true
        async let bundledDone: Void = loadBundled()
        async let onlineDone: Void = loadOnline(forceRefresh: true)
        _ = await (bundledDone, onlineDone)
    }

    private func loadBundled() async {
        guard !isLoadingBundled else { return }
        isLoadingBundled = true
        defer { isLoadingBundled = false }
        do {
            bundled = try await searchBundled(query)
        } catch {
            WLOG("CheatCatalogLoader: bundled cheat search failed: \(error)")
        }
    }

    private func loadOnline(forceRefresh: Bool) async {
        guard onlineState != .loading else { return }
        onlineState = .loading
        do {
            let found = try await searchOnline(query, forceRefresh)
            online = found
            onlineState = .loaded
            if let key = query.cacheKey {
                cache.store(found, for: key)
            }
        } catch {
            // Quiet by design: no network is an ordinary state for this menu.
            // Whatever was fetched before stays on screen.
            ILOG("CheatCatalogLoader: online cheat lookup failed: \(error.localizedDescription)")
            onlineState = .failed
        }
    }
}

// MARK: - Sources

extension CheatCatalogLoader {
    /// The bundled databases only. The serial is left out so that this never
    /// waits on the network; `defaultOnlineSearch` uses it.
    nonisolated static let defaultBundledSearch: BundledSearch = { query in
        try await CheatDatabase.shared.searchAllCheats(
            byMD5: query.gameMD5,
            title: query.gameTitle,
            systemIdentifier: query.systemName
        )
    }

    /// The libretro cheat repository, GameHacking.org and, for GameCube and
    /// Wii discs, the Gecko code server.
    nonisolated static let defaultOnlineSearch: OnlineSearch = { query, forceRefresh in
        var found: [CheatDatabaseEntry] = []
        var failure: Error?

        if let title = query.gameTitle, !title.isEmpty {
            do {
                found = try await CheatDatabase.shared.searchCheatsOnline(
                    title: title,
                    systemIdentifier: query.systemName,
                    forceRefresh: forceRefresh
                )
            } catch {
                failure = error
            }
        }

        if let serial = query.romSerial, !serial.isEmpty {
            // With no MD5 and no title this runs the disc-serial lookup alone.
            // It ignores its own network errors, so it adds codes or nothing.
            let gecko = (try? await CheatDatabase.shared.searchAllCheats(
                systemIdentifier: query.systemName,
                romSerial: serial
            )) ?? []
            found.append(contentsOf: gecko)
        }

        if found.isEmpty, let failure { throw failure }
        return found
    }
}
