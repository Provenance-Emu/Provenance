//
//  LibrarySourceBridge.swift
//  PVLibrarySharing
//
//  Lets a `LibrarySource` feed PVRemoteLibrary's browser, so a peer or content
//  server can be drawn by the app's normal library screens.
//  Design: docs/superpowers/specs/2026-11-23-shared-remote-library-browser-design.md
//

import Foundation
import PVRemoteLibrary
import PVSystems

public extension LibraryGame {
    /// A peer's item in the shared model. The item's own id is kept as `sourceGameID`.
    init(_ item: RemoteLibraryItem, source: LibrarySourceID) {
        self.init(
            source: source, sourceGameID: item.id, title: item.title, system: item.systemIdentifier,
            platformName: item.platform, md5: item.md5, sizeBytes: item.sizeBytes, artKey: item.artKey,
            gameID: item.gameID, discNumber: item.discNumber, revision: item.revision
        )
    }
}

public extension RemoteLibraryItem {
    /// The item a `LibraryGame` was made from, rebuilt for a game that came out of the catalogue cache.
    init(_ game: LibraryGame, app: PeerApp) {
        self.init(
            id: game.sourceGameID, title: game.title, platform: game.platformName, systemIdentifier: game.system,
            md5: game.md5, sizeBytes: game.sizeBytes, artKey: game.artKey, source: app,
            gameID: game.gameID, discNumber: game.discNumber, revision: game.revision
        )
    }
}

/// Adapts any `LibrarySource` to `RemoteLibrarySource`.
///
/// A content server is browsed in pages with its own search; a peer hands over
/// its whole catalogue as one page. Copies go through `LibraryPuller`, so they
/// keep its resume and SHA-256 checks.
public actor LibrarySourceBridge: RemoteLibrarySource {
    public nonisolated let info: LibrarySourceInfo
    public nonisolated let capabilities: SourceCapabilities

    private let source: any LibrarySource
    private let puller: LibraryPuller
    private var items: [String: RemoteLibraryItem] = [:]
    private var serverCursors: [String: ECSSource.CatalogueCursor] = [:]
    private var libraryIDs: [String]?

    /// - Parameters:
    ///   - staging: where copies land before the importer takes them.
    ///   - peerKey: tells peers apart in staging folder names (`DiscoveredPeer.id`).
    public init(source: any LibrarySource, info: LibrarySourceInfo, staging: LibraryStaging, peerKey: String) {
        self.source = source
        self.info = info
        puller = LibraryPuller(staging: staging, peerKey: peerKey)
        capabilities = source is ECSSource ? [.serverSearch, .paging, .temporaryPlay] : []
    }

    /// Limits a content server's catalogue to these libraries; nil browses all of them.
    public func selectLibraries(_ ids: [String]?) {
        libraryIDs = ids
    }

    public func page(_ query: PVRemoteLibrary.CatalogueQuery, after cursor: PVRemoteLibrary.CatalogueCursor?) async throws -> PVRemoteLibrary.CataloguePage {
        guard let server = source as? ECSSource else {
            guard cursor == nil else { return CataloguePage(games: []) }
            let catalogue = try await source.catalogue { _ in }
            let wanted = query.systems.map { catalogue.filtered(to: $0) } ?? catalogue
            return CataloguePage(games: games(wanted.items))
        }
        let page: ECSSource.CataloguePage
        if let cursor {
            // A cursor from before this bridge was made (a relaunch) cannot be continued.
            guard let position = serverCursors.removeValue(forKey: cursor.rawValue) else { return CataloguePage(games: []) }
            page = try await server.browseCatalogue(after: position)
        } else {
            let ids: [String]
            if let libraryIDs {
                ids = libraryIDs
            } else {
                ids = try await server.libraries().map(\.id)
            }
            page = try await server.browseCatalogue(libraryIDs: ids, search: query.search, playableSystems: query.systems)
        }
        let next = page.next.map { position -> PVRemoteLibrary.CatalogueCursor in
            let key = UUID().uuidString
            serverCursors[key] = position
            return CatalogueCursor(key)
        }
        return CataloguePage(games: games(page.catalogue.items), next: next)
    }

    public func artwork(for game: LibraryGame, etag: String?) async throws -> ArtworkResult {
        guard let data = try await source.artwork(for: item(for: game)) else { return .none }
        return .image(data, etag: nil)
    }

    public func fetch(
        _ game: LibraryGame, into directory: URL, progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchedGame {
        let pulled = try await puller.pull(item(for: game), from: source) { event in
            switch event {
            case .preparing:
                progress(.preparing)
            case .downloading(_, _, _, let bytesDone, let totalBytes):
                progress(.downloading(totalBytes > 0 ? Double(bytesDone) / Double(totalBytes) : 0))
            case .verifying:
                progress(.verifying)
            }
        }
        if source.app == .contentServer { try ECSDownloadedGame.validate(pulled) }
        return FetchedGame(directory: pulled.folder, files: [pulled.primaryFile] + pulled.gameFiles.filter { $0 != pulled.primaryFile })
    }

    private func games(_ found: [RemoteLibraryItem]) -> [LibraryGame] {
        found.map { item in
            let game = LibraryGame(item, source: info.id)
            items[game.id] = item
            return game
        }
    }

    private func item(for game: LibraryGame) -> RemoteLibraryItem {
        items[game.id] ?? RemoteLibraryItem(game, app: source.app)
    }
}
