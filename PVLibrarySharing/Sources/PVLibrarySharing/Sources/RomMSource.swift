//
//  RomMSource.swift
//  PVLibrarySharing
//
//  A RomM server as a PVRemoteLibrary source. Lives here, not in that package,
//  until the server client package has version tags a versioned package can use.
//

import Foundation
import PVRemoteLibrary
import PVSystems
import RomMClient

/// A RomM server as a library source.
///
/// RomM lists games per platform, so the catalogue walks the platforms that map
/// to a system, one page of one platform at a time.
public actor RomMSource: RemoteLibrarySource {
    public nonisolated let info: LibrarySourceInfo
    public nonisolated let capabilities: SourceCapabilities = [.serverSearch, .paging]

    private let client: RomMClient
    private let systemFor: @Sendable (RomMPlatform) -> SystemIdentifier?
    private let pageSize: Int
    private var platforms: [RomMPlatform]?
    private var native: [String: RomMGame] = [:]

    /// - Parameter systemFor: the app's mapping from a RomM platform to a system; nil hides the platform.
    public init(
        client: RomMClient, pageSize: Int = 50,
        systemFor: @escaping @Sendable (RomMPlatform) -> SystemIdentifier?
    ) {
        self.client = client
        self.pageSize = pageSize
        self.systemFor = systemFor
        let origin = client.address.baseURL
        info = LibrarySourceInfo(
            id: LibrarySourceID(rawValue: "romm:" + origin.absoluteString), kind: .romm,
            name: origin.host ?? origin.absoluteString, symbol: "externaldrive.connected.to.line.below"
        )
    }

    public func page(_ query: PVRemoteLibrary.CatalogueQuery, after cursor: PVRemoteLibrary.CatalogueCursor?) async throws -> PVRemoteLibrary.CataloguePage {
        let wanted = try await mappedPlatforms().filter { query.systems?.contains($0.system) ?? true }
        let position = cursor.flatMap(Position.init) ?? Position(platform: 0, offset: 0)
        guard position.platform < wanted.count else { return CataloguePage(games: []) }
        let (platform, system) = wanted[position.platform]
        let page = try await client.games(platformID: platform.id, search: query.search, offset: position.offset, limit: pageSize)
        let games = page.items.filter(\.isDownloadable).map { game -> LibraryGame in
            let entry = LibraryGame(
                source: info.id, sourceGameID: String(game.id), title: game.title, system: system,
                platformName: platform.title, sizeBytes: game.fsSizeBytes, fileName: game.fsName,
                artKey: game.coverPath == nil ? nil : String(game.id)
            )
            native[entry.id] = game
            return entry
        }
        let next: Position?
        if let offset = page.nextOffset, offset > position.offset {
            next = Position(platform: position.platform, offset: offset)
        } else if position.platform + 1 < wanted.count {
            next = Position(platform: position.platform + 1, offset: 0)
        } else {
            next = nil
        }
        return CataloguePage(games: games, next: next?.cursor)
    }

    public func artwork(for game: LibraryGame, etag: String?) async throws -> ArtworkResult {
        guard let native = native[game.id], let data = try await client.cover(for: native) else { return .none }
        return .image(data, etag: nil)
    }

    public func fetch(
        _ game: LibraryGame, into directory: URL, progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchedGame {
        // A game restored from the cached catalogue has no native value until its page is loaded again.
        guard let native = native[game.id] else { throw RomMError.invalidContent }
        progress(.preparing)
        let download = try await client.download(native)
        do {
            // The files come from a server: check a cue, gdi or m3u names only files that came with it.
            try ECSDownloadedGame.validate(files: download.files)
        } catch {
            try? FileManager.default.removeItem(at: download.directory)
            throw error
        }
        return FetchedGame(directory: download.directory, files: Self.primaryFirst(download.files, gameFileName: native.fsName))
    }

    /// The file the importer should open, first: the set's index (m3u, cue, gdi, ccd)
    /// when there is one, else the file RomM names for the game. The rest keep their order.
    static func primaryFirst(_ files: [URL], gameFileName: String) -> [URL] {
        let index = RemoteManifest.indexExtensions.lazy.compactMap { ext in
            files.first { $0.pathExtension.lowercased() == ext }
        }.first
        guard let primary = index ?? files.first(where: { $0.lastPathComponent == gameFileName }) else { return files }
        return [primary] + files.filter { $0 != primary }
    }

    private func mappedPlatforms() async throws -> [(platform: RomMPlatform, system: SystemIdentifier)] {
        let all: [RomMPlatform]
        if let platforms {
            all = platforms
        } else {
            all = try await client.platforms().filter { $0.romCount > 0 }
            platforms = all
        }
        return all.compactMap { platform in systemFor(platform).map { (platform, $0) } }
    }

    private struct Position {
        var platform: Int
        var offset: Int

        init(platform: Int, offset: Int) {
            self.platform = platform
            self.offset = offset
        }

        init?(_ cursor: PVRemoteLibrary.CatalogueCursor) {
            let parts = cursor.rawValue.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            self.init(platform: parts[0], offset: parts[1])
        }

        var cursor: PVRemoteLibrary.CatalogueCursor { PVRemoteLibrary.CatalogueCursor("\(platform):\(offset)") }
    }
}
