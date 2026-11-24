import Foundation
import PVRemoteLibrary
import PVSystems
import XCTest
@testable import PVLibrarySharing

/// A peer with one two-file game, served from memory.
private actor StubPeer: LibrarySource {
    nonisolated let app: PeerApp = .iFly
    static let disc = Data("disc image".utf8)
    static let index = Data("index".utf8)
    let item = RemoteLibraryItem(
        id: "abc|dc|10", title: "Sonic", platform: "dreamcast", systemIdentifier: .Dreamcast,
        md5: "ABCDEF", sizeBytes: 10, artKey: "abc", source: .iFly, gameID: "MK-51000", discNumber: 1
    )
    let unsupported = RemoteLibraryItem(
        id: "x", title: "Unknown", platform: "zx81", systemIdentifier: nil, md5: nil, sizeBytes: 1, artKey: nil, source: .iFly
    )

    func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        RemoteCatalogue(deviceName: "iFly on iPad", items: [item, unsupported], source: .iFly)
    }

    func artwork(for item: RemoteLibraryItem) async throws -> Data? {
        item.artKey == nil ? nil : Data("cover".utf8)
    }

    func pullManifest(
        for item: RemoteLibraryItem, progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteManifest {
        RemoteManifest(itemId: item.id, files: [
            RemoteFile(kind: RemoteFile.gameFileKind, relativePath: "sonic.gdi", sha256: sha256Hex(Self.index), size: Int64(Self.index.count)),
            RemoteFile(kind: RemoteFile.gameFileKind, relativePath: "track01.bin", sha256: sha256Hex(Self.disc), size: Int64(Self.disc.count))
        ])
    }

    func download(
        _ file: RemoteFile, of manifest: RemoteManifest, to partialFile: URL, resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse {
        let data = file.relativePath == "sonic.gdi" ? Self.index : Self.disc
        try data.write(to: partialFile)
        progress(Int64(data.count))
        return LibraryDownloadResponse(status: 200, writtenFrom: 0, bytesOnDisk: Int64(data.count))
    }
}

final class LibrarySourceBridgeTests: XCTestCase {
    private let sourceID = LibrarySourceID(rawValue: "peer:ipad")

    private func bridge(_ peer: StubPeer) throws -> LibrarySourceBridge {
        LibrarySourceBridge(
            source: peer,
            info: LibrarySourceInfo(id: sourceID, kind: .peer, name: "iFly on iPad", symbol: "opticaldisc"),
            staging: LibraryStaging(root: try makeTemporaryFolder()), peerKey: "ipad"
        )
    }

    func testAPeerCatalogueIsOnePageInTheSharedModel() async throws {
        let bridge = try bridge(StubPeer())
        let page = try await bridge.page(CatalogueQuery(), after: nil)
        XCTAssertNil(page.next)
        XCTAssertEqual(page.games.map(\.title), ["Sonic", "Unknown"])
        let game = try XCTUnwrap(page.games.first)
        XCTAssertEqual(game.source, sourceID)
        XCTAssertEqual(game.sourceGameID, "abc|dc|10")
        XCTAssertEqual(game.system, .Dreamcast)
        XCTAssertEqual(game.md5, "abcdef")
        XCTAssertEqual(game.gameID, "MK-51000")
        XCTAssertEqual(game.discNumber, 1)
        XCTAssertNil(page.games[1].system)
        XCTAssertTrue(bridge.capabilities.isEmpty)
    }

    func testTheSystemFilterIsAppliedForPeers() async throws {
        let bridge = try bridge(StubPeer())
        let dreamcast = try await bridge.page(CatalogueQuery(systems: [.Dreamcast]), after: nil)
        XCTAssertEqual(dreamcast.games.map(\.title), ["Sonic"])
        let none = try await bridge.page(CatalogueQuery(systems: [.SNES]), after: nil)
        XCTAssertTrue(none.games.isEmpty)
        let after = try await bridge.page(CatalogueQuery(), after: CatalogueCursor("anything"))
        XCTAssertTrue(after.games.isEmpty)
    }

    func testArtworkComesFromThePeer() async throws {
        let bridge = try bridge(StubPeer())
        let games = try await bridge.page(CatalogueQuery(), after: nil).games
        let withArt = try await bridge.artwork(for: games[0], etag: nil)
        XCTAssertEqual(withArt, .image(Data("cover".utf8), etag: nil))
        let without = try await bridge.artwork(for: games[1], etag: nil)
        XCTAssertEqual(without, ArtworkResult.none)
    }

    func testFetchPullsVerifiedFilesWithTheIndexFirst() async throws {
        let bridge = try bridge(StubPeer())
        let game = try await bridge.page(CatalogueQuery(), after: nil).games[0]
        let fetched = try await bridge.fetch(game, into: try makeTemporaryFolder()) { _ in }
        XCTAssertEqual(fetched.files.map(\.lastPathComponent), ["sonic.gdi", "track01.bin"])
        XCTAssertEqual(try Data(contentsOf: fetched.files[1]), StubPeer.disc)
        XCTAssertTrue(fetched.files.allSatisfy { $0.path.hasPrefix(fetched.directory.path) })
    }

    func testAGameFromTheCacheCanStillBeFetched() async throws {
        let listing = try bridge(StubPeer())
        let game = try await listing.page(CatalogueQuery(), after: nil).games[0]
        // A new bridge has listed nothing: this is a relaunch with a cached catalogue.
        let fresh = try bridge(StubPeer())
        let fetched = try await fresh.fetch(game, into: try makeTemporaryFolder()) { _ in }
        XCTAssertEqual(fetched.files.count, 2)
    }

    func testAnItemSurvivesTheRoundTripThroughTheSharedModel() {
        let item = RemoteLibraryItem(
            id: "k", title: "T", platform: "gc", systemIdentifier: .GameCube, md5: "aa", sizeBytes: 5,
            artKey: "k", source: .iCube, gameID: "GM4E01", discNumber: 2, revision: 1
        )
        XCTAssertEqual(RemoteLibraryItem(LibraryGame(item, source: sourceID), app: .iCube), item)
    }
}
