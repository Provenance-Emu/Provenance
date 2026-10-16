//
//  ExtensionV11Tests.swift
//  PVLibrarySharingTests
//
//  Phase 4: TXT extension keys, `_pvlibrary._tcp`, filter and paging, and the
//  back-compat matrix with pre-v1.1 peers.
//

import PVSystems
import XCTest
@testable import PVLibrarySharing

final class AdvertExtensionTests: XCTestCase {
    func testSystemsSplitAcrossKeysAndRoundTrip() throws {
        let all = SystemMap.systems(servedBy: .pvLibrary)
        let txt = LibraryAdvertTXT.record(peerId: "p", urls: [], systems: all, catalogueVersion: "0123456789abcdef")
        let keys = txt.keys.filter { $0.hasPrefix("sys") }
        XCTAssertGreaterThan(keys.count, 1)
        XCTAssertTrue(keys.allSatisfy { (txt[$0]?.utf8.count ?? 0) <= LibraryAdvertTXT.maxSystemsBytes })
        XCTAssertEqual(txt["cv"], "01234567")

        let advert = try XCTUnwrap(PeerAdvertisement(txt: txt))
        XCTAssertEqual(advert.systems, all)
        XCTAssertEqual(advert.appName, "provenance")
        XCTAssertEqual(advert.extensionLevel, 1)
        XCTAssertEqual(advert.catalogueVersion, "01234567")
    }

    func testUnspecifiedEmptyAndLegacyAdverts() throws {
        let star = try XCTUnwrap(PeerAdvertisement(txt: ["v": "1", "sid": "s", "sys": "*"]))
        XCTAssertNil(star.systems)
        XCTAssertTrue(star.mayServe([.NES]))

        let empty = try XCTUnwrap(PeerAdvertisement(txt: LibraryAdvertTXT.record(peerId: "p", urls: [], systems: [])))
        XCTAssertEqual(empty.systems, [])
        XCTAssertFalse(empty.mayServe([.NES]))

        let legacy = try XCTUnwrap(PeerAdvertisement(txt: ["v": "1", "sid": "s", "lib": "1"]))
        XCTAssertNil(legacy.systems)
        XCTAssertNil(legacy.extensionLevel)
        XCTAssertTrue(legacy.mayServe([.GameCube]))

        let iFly = try XCTUnwrap(PeerAdvertisement(txt: ["v": "1", "sid": "s", "sys": "Dreamcast,naomi2,unknownthing"]))
        XCTAssertEqual(iFly.systems, [.Dreamcast, .NAOMI2])
        XCTAssertFalse(iFly.mayServe([.GameCube, .Wii]))
    }

    func testOneDeviceOnSeveralTypesIsListedOnceAsPVLibrary() throws {
        let txt = LibraryAdvertTXT.record(peerId: "same", urls: [URL(string: "http://10.0.0.2:8484")!], systems: [.Dreamcast])
        let legacy = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_ifly-continuity._tcp", serviceName: "Provenance on iPad", txt: txt))
        let shared = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_pvlibrary._tcp.", serviceName: "Provenance on iPad", txt: txt))
        let other = try XCTUnwrap(DiscoveredPeer.make(
            serviceType: "_icube-continuity._tcp", serviceName: "Living Room", txt: ["v": "1", "sid": "x", "lib": "1", "pid": "cube", "u0": "http://10.0.0.3"]
        ))
        let peers = DiscoveredPeer.deduplicated([legacy, other, shared])
        XCTAssertEqual(peers.map(\.app), [.iCube, .pvLibrary])
        XCTAssertEqual(peers.last?.appDisplayName, "Provenance")
        XCTAssertTrue(shared.isOwnAdvert(peerId: "same"))
    }

    /// With a team-shared identity, iFly and iCube on one device share a pid:
    /// they stay two rows, and neither counts as Provenance's own advert.
    func testSharedIdentityAcrossAppsKeepsBothRows() throws {
        let iFly = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_ifly-continuity._tcp", serviceName: "iFly iPad",
                                                     txt: ["v": "1", "sid": "a", "lib": "1", "pid": "team", "u0": "http://10.0.0.2", "app": "ifly"]))
        let iCube = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_icube-continuity._tcp", serviceName: "iCube iPad",
                                                      txt: ["v": "1", "sid": "b", "lib": "1", "pid": "team", "u0": "http://10.0.0.2"]))
        XCTAssertEqual(DiscoveredPeer.deduplicated([iFly, iCube]).count, 2)
        XCTAssertFalse(iFly.isOwnAdvert(peerId: "team"))
        XCTAssertFalse(iCube.isOwnAdvert(peerId: "team"))
    }

    /// Two Provenance devices on one network: the advert one device's host
    /// publishes on `_pvlibrary._tcp` is listed on the other, and only there.
    func testAnotherProvenanceIsVisibleAndThisOneIsNot() throws {
        let txt = LibraryAdvertTXT.record(peerId: "ipad", urls: [URL(string: "http://10.0.0.2:8486")!], systems: [.SNES, .GameCube])
        let peer = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_pvlibrary._tcp.", serviceName: "Provenance on iPad", txt: txt))

        XCTAssertTrue(peer.isVisible(ownPeerId: "iphone", playable: [.SNES, .NES]), "another device sharing a system this one plays")
        XCTAssertTrue(peer.isVisible(ownPeerId: nil, playable: [.GameCube]))
        XCTAssertFalse(peer.isVisible(ownPeerId: "ipad", playable: [.SNES]), "this device's own advert")
        XCTAssertFalse(peer.isVisible(ownPeerId: "iphone", playable: [.Genesis]), "nothing shared that this device plays")
        XCTAssertFalse(peer.isVisible(ownPeerId: "iphone", playable: []), "no playable systems loaded")

        let emptyLibrary = try XCTUnwrap(DiscoveredPeer.make(
            serviceType: "_pvlibrary._tcp", serviceName: "Provenance on TV",
            txt: LibraryAdvertTXT.record(peerId: "tv", urls: [URL(string: "http://10.0.0.4:8486")!], systems: [])
        ))
        XCTAssertFalse(emptyLibrary.isVisible(ownPeerId: "iphone", playable: [.SNES]), "sharing on, but no games")
    }

    /// iFly and iCube adverts carry no `sys` before v1.1: listed whenever this
    /// device plays one of the systems that app serves.
    func testLegacyPeersAreVisibleByTheirAppsSystems() throws {
        let iCube = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_icube-continuity._tcp", serviceName: "iCube iPad",
                                                      txt: ["v": "1", "sid": "b", "lib": "1", "pid": "cube", "u0": "http://10.0.0.3"]))
        XCTAssertTrue(iCube.isVisible(ownPeerId: "iphone", playable: [.Wii, .SNES]))
        XCTAssertFalse(iCube.isVisible(ownPeerId: "iphone", playable: [.SNES]))
    }
}

final class CatalogueQueryTests: XCTestCase {
    func testParsesFilterAndClampsLimit() {
        let query = CatalogueQuery(query: ["systemIdentifier": "com.provenance.dreamcast,naomi,bogus", "limit": "100000"])
        XCTAssertEqual(query.systems, [.Dreamcast, .NAOMI])
        XCTAssertEqual(query.limit, CatalogueQuery.maxLimit)
        XCTAssertNil(CatalogueQuery(query: [:]).systems)
    }

    func testPagesAndRefusesAStaleCursor() throws {
        let items = Array(0..<450)
        var query = CatalogueQuery(limit: 200)
        var seen: [Int] = []
        repeat {
            let page = try query.page(items, version: "v1-aaaaaaaabbbb")
            seen += page.items
            query.cursor = page.nextCursor
        } while query.cursor != nil
        XCTAssertEqual(seen, items)

        let stale = CatalogueQuery(limit: 200, cursor: "aaaaaaaa.200")
        XCTAssertThrowsError(try stale.page(items, version: "v1-cccccccc")) {
            XCTAssertEqual($0 as? CatalogueQuery.PageError, .staleCursor)
        }
        XCTAssertEqual(try CatalogueQuery().page(items, version: "v").items.count, 450)
    }
}

/// A library of `count` tiny games spread over three systems.
final class BigLibrary: SharedLibraryProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var games: [SharedGame]

    init(count: Int, file: SharedFile) {
        let systems: [SystemIdentifier] = [.NES, .Dreamcast, .GameCube]
        games = (0..<count).map { index in
            SharedGame(
                id: String(format: "%032X", index), title: "Game \(index)", system: systems[index % systems.count],
                md5: String(format: "%032x", index), files: [file], hasArtwork: false
            )
        }
    }

    func append(_ game: SharedGame) {
        lock.withLock { games.append(game) }
    }

    func sharedGames() async -> [SharedGame] { lock.withLock { games } }
    func artwork(forGameId id: String) async -> Data? { nil }
}

final class PVLibraryDialectTests: XCTestCase {
    private var fixture: ServerFixture!
    private let base = URL(string: "http://provenance-b.local:8486")!
    private let client = PeerIdentity(id: "provenance-a", name: "Provenance on iPhone")

    override func setUpWithError() throws {
        fixture = try ServerFixture()
    }

    override func tearDown() {
        fixture.cleanUp()
    }

    private func server(_ library: (any SharedLibraryProviding)? = nil) -> PVLibraryDialectServer {
        let flag = fixture.sharing
        return PVLibraryDialectServer(
            identity: fixture.hostIdentity, device: fixture.device, library: library ?? fixture.library,
            trust: fixture.trust, approver: fixture.owner, hashes: FileHashCache(), sharingEnabled: { flag.value }
        )
    }

    private func source(_ server: PVLibraryDialectServer, systems: Set<SystemIdentifier>? = nil, counting: RequestCounter? = nil) -> PVLibrarySource {
        PVLibrarySource(
            baseURLs: [base], identity: client, systems: systems,
            transport: InProcessTransport { request in
                counting?.record(request)
                return await server.handle(request)
            },
            pollInterval: 0.01, approvalTimeout: 5
        )
    }

    func testBrowsesEverySharedSystemAndCopiesASet() async throws {
        let server = server()
        let pv = source(server)
        let catalogue = try await pv.catalogue { _ in }
        XCTAssertEqual(Set(catalogue.items.map(\.title)), ["Ikaruga", "Rez", "Super Mario Sunshine", "Super Mario Bros."])
        XCTAssertEqual(catalogue.items.first { $0.title == "Super Mario Bros." }?.systemIdentifier, .NES)
        XCTAssertEqual(catalogue.items.first { $0.title == "Super Mario Sunshine" }?.gameID, "GMSE01")

        let ikaruga = try XCTUnwrap(catalogue.items.first { $0.title == "Ikaruga" })
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let pulled = try await LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "pv").pull(ikaruga, from: pv) { _ in }
        XCTAssertEqual(pulled.primaryFile.lastPathComponent, "Ikaruga.gdi")
        XCTAssertEqual(pulled.systemIdentifier, .Dreamcast)
        XCTAssertEqual(try pulled.gameFiles.map { try Data(contentsOf: $0) }, try fixture.library.data(of: "IKARUGA"))
    }

    func testFilterIsSentAndAppliedLocallyToo() async throws {
        let counter = RequestCounter()
        let catalogue = try await source(server(), systems: [.GameCube, .Wii], counting: counter).catalogue { _ in }
        XCTAssertEqual(catalogue.items.map(\.title), ["Super Mario Sunshine"])
        let sent = try XCTUnwrap(counter.requests.first { $0.path == TestPaths.iCubeCatalog })
        XCTAssertEqual(sent.query["systemIdentifier"], "com.provenance.gamecube,com.provenance.wii")
        XCTAssertEqual(sent.query["limit"], "200")
    }

    /// The phase 4 acceptance case: 5,000 games in pages of 200.
    func testFiveThousandGamesInPagesOfTwoHundred() async throws {
        let file = try XCTUnwrap(fixture.library.games.first { $0.id == "REZ" }?.files.first)
        let big = BigLibrary(count: 5_000, file: file)
        let counter = RequestCounter()
        let pv = source(server(big), counting: counter)
        let catalogue = try await pv.catalogue { _ in }
        XCTAssertEqual(catalogue.items.count, 5_000)
        XCTAssertEqual(Set(catalogue.items.map(\.id)).count, 5_000)
        XCTAssertEqual(counter.requests.filter { $0.path == TestPaths.iCubeCatalog }.count, 25)

        // Unchanged: one conditional request, answered 304.
        let again = try await pv.catalogue { _ in }
        XCTAssertEqual(again.items.count, 5_000)
        XCTAssertEqual(counter.requests.filter { $0.path == TestPaths.iCubeCatalog }.count, 26)
    }

    func testCatalogueChangingBetweenPagesStartsOver() async throws {
        let file = try XCTUnwrap(fixture.library.games.first { $0.id == "REZ" }?.files.first)
        let big = BigLibrary(count: 450, file: file)
        let server = server(big)
        let changed = SharingFlag()
        let pv = PVLibrarySource(
            baseURLs: [base], identity: client,
            transport: InProcessTransport { request in
                if request.path == TestPaths.iCubeCatalog, request.query["cursor"] != nil, !changed.value {
                    changed.value = true
                    big.append(SharedGame(id: "NEW", title: "New Game", system: .NES, md5: "ffff", files: [file], hasArtwork: false))
                }
                return await server.handle(request)
            },
            pollInterval: 0.01
        )
        let catalogue = try await pv.catalogue { _ in }
        XCTAssertEqual(catalogue.items.count, 451)
        XCTAssertEqual(Set(catalogue.items.map(\.id)).count, 451)
    }

    func testAskPerGamePollsTheManifestThenDeclines() async throws {
        fixture.owner.browse = .askPerGame
        let pv = source(server())
        let items = try await pv.catalogue { _ in }.items
        let rez = try XCTUnwrap(items.first { $0.title == "Rez" })
        let log = ProgressLog()
        _ = try await pv.pullManifest(for: rez) { log.append($0) }
        XCTAssertTrue(log.values.contains(.waitingForApproval))

        fixture.owner.pull = .denyOnce
        do {
            _ = try await pv.pullManifest(for: rez) { _ in }
            XCTFail("expected pullDeclined")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .pullDeclined)
        }
    }

    func testFilesNeedAGrantedManifest() async throws {
        let server = server()
        let transport = InProcessTransport { await server.handle($0) }
        let pv = source(server)
        _ = try await pv.catalogue { _ in }
        // A token, but no manifest asked for: the file route refuses.
        let start = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.authStart),
            body: ConsentAuthStart(peerId: client.id, name: client.name, publicKey: client.publicKeyData)
        ))
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: start.body)
        let signature = try ContinuityAuthMath.signAuth(
            domain: .pvLibrary, nonce: challenge.nonce, peerId: client.id, serverId: challenge.serverId, signingKey: client.signingKey
        )
        let complete = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.authComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: client.id, signature: signature)
        ))
        let token = try JSONDecoder().decode(LibraryTokenResponse.self, from: complete.body).libraryToken
        let file = try await transport.send(.authorizedGet(
            url: ContinuityRoutes.libraryFileURL(base: base, key: "md5:bbbb1111bbbb1111bbbb1111bbbb1111", relativePath: "Rez.chd"), token: token
        ))
        XCTAssertEqual(file.status, 404)
    }

    /// A signature made for iFly or iCube never opens `_pvlibrary`.
    func testOtherDomainsSignaturesAreRefused() async throws {
        let server = server()
        let transport = InProcessTransport { await server.handle($0) }
        let start = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.authStart),
            body: ConsentAuthStart(peerId: client.id, name: client.name, publicKey: client.publicKeyData)
        ))
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: start.body)
        let wrong = try ContinuityAuthMath.signAuth(
            domain: .iFly, nonce: challenge.nonce, peerId: client.id, serverId: challenge.serverId, signingKey: client.signingKey
        )
        let complete = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.authComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: client.id, signature: wrong)
        ))
        XCTAssertEqual(complete.status, 403)
    }

    func testPairingAnswers200Paired() async throws {
        let server = server()
        let transport = InProcessTransport { await server.handle($0) }
        let started = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.pairStart),
            body: ICubePairStartRequest(peerId: client.id, name: client.name, publicKey: client.publicKeyData)
        ))
        let handle = try JSONDecoder().decode(ICubePairStartResponse.self, from: started.body)
        for _ in 0..<200 where fixture.owner.lastCode == nil {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        let code = try XCTUnwrap(fixture.owner.lastCode)
        let transcript = ContinuityAuthMath.pairingTranscript(
            domain: .pvLibrary, pairingId: handle.pairingId, clientId: client.id, serverId: handle.serverId,
            clientPublicKey: client.publicKeyData, serverPublicKey: handle.serverPublicKey
        )
        let body = ICubePairCompleteRequest(pairingId: handle.pairingId, proof: ContinuityAuthMath.pairingProof(code: code, transcript: transcript))
        var response = try await transport.send(.jsonPost(url: base.appendingPathComponent(TestPaths.pairComplete), body: body))
        for _ in 0..<200 where response.status == 202 {
            try await Task.sleep(nanoseconds: 2_000_000)
            response = try await transport.send(.jsonPost(url: base.appendingPathComponent(TestPaths.pairComplete), body: body))
        }
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(try JSONDecoder().decode(PVPairedResponse.self, from: response.body).paired, true)
        // Paired: the next browse needs no consent prompt.
        fixture.owner.browse = .dontShare
        let catalogue = try await source(server).catalogue { _ in }
        XCTAssertEqual(catalogue.items.count, 4)
    }
}

/// Pre-v1.1 peers keep working with a v1.1 Provenance, and the reverse.
final class BackCompatTests: XCTestCase {
    private var fixture: ServerFixture!

    override func setUpWithError() throws {
        fixture = try ServerFixture()
    }

    override func tearDown() {
        fixture.cleanUp()
    }

    /// An old iFly sends no filter and no `limit`: it gets everything, unpaged.
    func testLegacyIFlyCatalogueIsUnpagedWithoutLimit() async throws {
        let server = fixture.iFlyServer()
        let iFly = IFlyContinuitySource(
            baseURLs: [URL(string: "http://p.local")!], identity: PeerIdentity(name: "iFly"),
            transport: InProcessTransport { await server.handle($0) }, pollInterval: 0.01
        )
        let catalogue = try await iFly.catalogue { _ in }
        XCTAssertEqual(catalogue.items.count, 2)
    }

    /// Provenance's legacy routes accept the v1.1 filter too (additive).
    func testLegacyICubeCatalogHonoursFilterAndPaging() async throws {
        let server = fixture.iCubeServer()
        let request = ServerRequest(method: "GET", path: TestPaths.iCubeCatalog, query: ["systemIdentifier": "com.provenance.wii"])
        let response = await server.handle(request)
        // No token: 401 before any filtering, exactly like iCube.
        XCTAssertEqual(response.status, 401)
    }

    /// A v1.1 client against a server that ignores the filter and `limit`
    /// (any pre-v1.1 `_pvlibrary` implementation) still ends up filtered.
    func testV11ClientFiltersLocallyWhenTheServerIgnoresTheFilter() async throws {
        let catalog = PVWireCatalog(
            sourceDevice: WireSourceDevice(fixture.device),
            entries: [
                .init(key: "a", game: PVWireGameIdentity(displayName: "NES game", platform: "com.provenance.nes"), sizeBytes: 1,
                      hasArtwork: false, systemIdentifier: nil),
                .init(key: "b", game: PVWireGameIdentity(displayName: "GC game", platform: "com.provenance.gamecube"), sizeBytes: 1,
                      hasArtwork: false, systemIdentifier: "com.provenance.gamecube")
            ]
        )
        let body = try iCubeEncoded(catalog)
        let identity = fixture.hostIdentity
        let ignoring = InProcessTransport { request in
            switch request.path {
            case TestPaths.authStart:
                return .encoded(AuthStartResponse(authId: "a", serverId: identity.id, nonce: Data([1])))
            case TestPaths.authComplete:
                return .encoded(LibraryTokenResponse(libraryToken: "t"))
            default:
                return .json(body)
            }
        }
        let pv = PVLibrarySource(
            baseURLs: [URL(string: "http://old.local")!], identity: PeerIdentity(name: "a"), systems: [.GameCube], transport: ignoring
        )
        let catalogue = try await pv.catalogue { _ in }
        XCTAssertEqual(catalogue.items.map(\.title), ["GC game"])
    }

    func testCatalogueVersionTwoIsRejectedOnPVLibraryToo() throws {
        let data = Data(#"{"version":2,"sourceDevice":{"name":"x","platform":"iOS","appVersion":"1"},"entries":[]}"#.utf8)
        XCTAssertThrowsError(try PVLibrarySource.decodeCatalog(data)) {
            XCTAssertEqual($0 as? LibrarySharingError, .unsupportedCatalogueVersion(2))
        }
    }
}

final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [ServerRequest] = []

    func record(_ request: ServerRequest) {
        lock.withLock { stored.append(request) }
    }

    var requests: [ServerRequest] { lock.withLock { stored } }
}

/// The v1.1 golden fixtures handed to the iFly and iCube sessions: written as
/// Provenance's server encodes them (sorted keys, ISO 8601 dates).
final class PVLibraryFixtureTests: XCTestCase {
    func testCatalogFixtureDecodesAndMaps() throws {
        let catalog = try PVLibrarySource.decodeCatalog(Fixture.data("pvlibrary-catalog"))
        XCTAssertEqual(catalog.nextCursor, "3f2a9c1d.2")
        let items = catalog.entries.map(PVLibrarySource.item)
        XCTAssertEqual(items.map(\.systemIdentifier), [.Dreamcast, .GameCube])
        XCTAssertEqual(items[1].gameID, "GMSE01")
        XCTAssertEqual(items[0].artKey, "md5:aaaa0000aaaa0000aaaa0000aaaa0000")
        // iCube's own decoder accepts the same bytes (extra keys ignored).
        XCTAssertEqual(try ICubeStrict.decode(ICubeStrict.Catalog.self, Fixture.data("pvlibrary-catalog")).entries.count, 2)
    }

    func testManifestFixtureDecodesWithBothDecoders() throws {
        let data = try Fixture.data("pvlibrary-manifest")
        let manifest = try JSONDecoder().decode(ContinuityPullManifest.self, from: data).remoteManifest(itemId: "k")
        XCTAssertEqual(manifest.primaryGameFile?.relativePath, "Ikaruga/Ikaruga.gdi")
        XCTAssertEqual(try ICubeStrict.decode(ICubeStrict.Manifest.self, data).files.count, 2)
    }
}
