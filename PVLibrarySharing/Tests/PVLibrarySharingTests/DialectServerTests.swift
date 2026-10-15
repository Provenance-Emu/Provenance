//
//  DialectServerTests.swift
//  PVLibrarySharingTests
//
//  Phase 3: Provenance's iFly and iCube dialect servers, driven by
//  Provenance's own clients (which pin each peer's client behaviour) and
//  checked against each peer's strict decoders.
//

import PVSystems
import XCTest
@testable import PVLibrarySharing

final class IFlyDialectServerTests: XCTestCase {
    private var fixture: ServerFixture!
    private let base = URL(string: "http://provenance.local:8484")!
    private let client = PeerIdentity(id: "ifly-device", name: "iFly on iPhone")

    override func setUpWithError() throws {
        fixture = try ServerFixture()
    }

    override func tearDown() {
        fixture.cleanUp()
    }

    private func source(_ server: IFlyDialectServer) -> IFlyContinuitySource {
        IFlyContinuitySource(
            baseURLs: [base], identity: client,
            transport: InProcessTransport { await server.handle($0) },
            pollInterval: 0.01, approvalTimeout: 5
        )
    }

    func testListsOnlyDreamcastFamilyGames() async throws {
        let catalogue = try await source(fixture.iFlyServer()).catalogue { _ in }
        XCTAssertEqual(Set(catalogue.items.map(\.title)), ["Ikaruga", "Rez"])
        XCTAssertEqual(Set(catalogue.items.compactMap(\.systemIdentifier)), [.Dreamcast])
        XCTAssertEqual(catalogue.deviceName, "Joe's iPad")
        // The md5 travels lower-case, so iFly's own md5 badge can match.
        XCTAssertEqual(catalogue.items.first { $0.title == "Rez" }?.md5, "bbbb1111bbbb1111bbbb1111bbbb1111")
    }

    func testLibraryManifestDecodesWithIFlysOwnFields() async throws {
        let server = fixture.iFlyServer()
        let transport = InProcessTransport { await server.handle($0) }
        let token = try await authenticate(transport)
        let response = try await transport.send(.authorizedGet(url: base.appendingPathComponent(TestPaths.iFlyManifest), token: token))
        let manifest = try JSONDecoder().decode(IFlyStrict.LibraryManifest.self, from: response.body)
        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.peerId, "provenance-host")
        XCTAssertEqual(manifest.games.map(\.saveStateCount), [0, 0])
        XCTAssertEqual(Set(manifest.games.map(\.platform)), ["Dreamcast"])
        XCTAssertEqual(response.header("ETag"), manifest.catalogVersion)

        var again = LibraryHTTPRequest.authorizedGet(url: base.appendingPathComponent(TestPaths.iFlyManifest), token: token)
        again.headers["If-None-Match"] = manifest.catalogVersion
        let notModified = try await transport.send(again)
        XCTAssertEqual(notModified.status, 304)
    }

    private func authenticate(_ transport: LibraryHTTPTransport) async throws -> String {
        let start = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.authStart),
            body: IFlyAuthStartRequest(peerId: client.id, name: client.name, publicKey: client.publicKeyData)
        ))
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: start.body)
        let signature = try ContinuityAuthMath.signAuth(
            domain: .iFly, nonce: challenge.nonce, peerId: client.id, serverId: challenge.serverId, signingKey: client.signingKey
        )
        let completeRequest = try LibraryHTTPRequest.jsonPost(
            url: base.appendingPathComponent(TestPaths.authComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: client.id, signature: signature)
        )
        for _ in 0..<200 {
            let response = try await transport.send(completeRequest)
            if response.status == 200 {
                return try JSONDecoder().decode(LibraryTokenResponse.self, from: response.body).libraryToken
            }
            XCTAssertEqual(response.status, 202)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw LibrarySharingError.approvalTimedOut
    }

    func testCopiesAGDISetPrimaryFirstWithNoBIOSOrSaves() async throws {
        let server = fixture.iFlyServer()
        let transport = InProcessTransport { await server.handle($0) }
        let token = try await authenticate(transport)
        let ikarugaId = "aaaa0000aaaa0000aaaa0000aaaa0000"
        var pull = try LibraryHTTPRequest.jsonPost(url: base.appendingPathComponent(TestPaths.iFlyPull), body: IFlyPullRequest(gameId: ikarugaId))
        pull.headers["Authorization"] = "Bearer \(token)"
        let response = try await transport.send(pull)
        XCTAssertEqual(response.status, 200)

        let manifest = try IFlyStrict.manifest(response.body)
        XCTAssertEqual(manifest.files.map(\.relativePath), [
            "ROMs/Ikaruga/Ikaruga.gdi", "ROMs/Ikaruga/track01.bin", "ROMs/Ikaruga/track02.bin"
        ])
        XCTAssertTrue(manifest.files.allSatisfy { $0.kind == "gameFile" && $0.required })
        XCTAssertTrue(manifest.bios.isEmpty)
        XCTAssertTrue(manifest.optionalExtras.isEmpty)
        XCTAssertEqual(manifest.game.platform, "dreamcast")
        XCTAssertEqual(manifest.files[1].sha256, sha256Hex(try fixture.library.data(of: "IKARUGA")[1]))

        // And Provenance's own client copies it end to end.
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let item = try await source(server).catalogue { _ in }.items.first { $0.title == "Ikaruga" }
        let pulled = try await LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "p")
            .pull(try XCTUnwrap(item), from: source(server)) { _ in }
        XCTAssertEqual(pulled.primaryFile.lastPathComponent, "Ikaruga.gdi")
        XCTAssertEqual(try pulled.gameFiles.map { try Data(contentsOf: $0) }, try fixture.library.data(of: "IKARUGA"))
    }

    func testSingleFileGameIsServedFlatUnderROMs() async throws {
        let server = fixture.iFlyServer()
        let item = try await source(server).catalogue { _ in }.items.first { $0.title == "Rez" }
        let manifest = try await source(server).pullManifest(for: try XCTUnwrap(item)) { _ in }
        XCTAssertEqual(manifest.files.map(\.relativePath), ["ROMs/Rez.chd"])
    }

    func testAskPerGamePromptsPerPullAndDenyDeclines() async throws {
        fixture.owner.browse = .askPerGame
        fixture.owner.pull = .allowOnce
        let server = fixture.iFlyServer()
        let iFly = source(server)
        let items = try await iFly.catalogue { _ in }.items
        let item = try XCTUnwrap(items.first { $0.title == "Rez" })
        let log = ProgressLog()
        _ = try await iFly.pullManifest(for: item) { log.append($0) }
        XCTAssertTrue(log.values.contains(.waitingForApproval))
        XCTAssertEqual(fixture.owner.pullPrompts, ["Rez"])

        fixture.owner.pull = .denyOnce
        do {
            _ = try await iFly.pullManifest(for: item) { _ in }
            XCTFail("expected a declined pull")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .pullDeclined)
        }
    }

    func testDontShareDeniesAndRemembers() async throws {
        fixture.owner.browse = .dontShare
        let server = fixture.iFlyServer()
        do {
            _ = try await source(server).catalogue { _ in }
            XCTFail("expected declined")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .declined)
        }
        let grant = await fixture.trust.grant(forPeerId: client.id)
        XCTAssertEqual(grant, .denied)
    }

    func testSharingOffAnswers404() async throws {
        fixture.sharing.value = false
        do {
            _ = try await source(fixture.iFlyServer()).catalogue { _ in }
            XCTFail("expected sharingUnavailable")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .sharingUnavailable)
        }
    }

    func testFileRouteServesOnlyGrantedPathsWithRange() async throws {
        let server = fixture.iFlyServer()
        let transport = InProcessTransport { await server.handle($0) }
        let token = try await authenticate(transport)
        func get(_ path: String, range: String? = nil) async throws -> LibraryHTTPResponse {
            var request = LibraryHTTPRequest.authorizedGet(
                url: ContinuityRoutes.libraryFileURL(base: base, key: nil, relativePath: path), token: token
            )
            request.headers["Range"] = range
            return try await transport.send(request)
        }
        // Nothing granted yet, and traversal is just "not granted".
        let notGranted = try await get("ROMs/Rez.chd")
        let traversal = try await get("../library/NES/Mario.nes")
        XCTAssertEqual(notGranted.status, 404)
        XCTAssertEqual(traversal.status, 404)

        var pull = try LibraryHTTPRequest.jsonPost(
            url: base.appendingPathComponent(TestPaths.iFlyPull), body: IFlyPullRequest(gameId: "bbbb1111bbbb1111bbbb1111bbbb1111")
        )
        pull.headers["Authorization"] = "Bearer \(token)"
        _ = try await transport.send(pull)

        let partial = try await get("ROMs/Rez.chd", range: "bytes=100-")
        XCTAssertEqual(partial.status, 206)
        XCTAssertEqual(partial.header("Content-Range"), "bytes 100-29999/30000")
        XCTAssertEqual(partial.body, try fixture.library.data(of: "REZ")[0].dropFirst(100))
        let unsatisfiable = try await get("ROMs/Rez.chd", range: "bytes=30000-")
        XCTAssertEqual(unsatisfiable.status, 416)
    }

    func testArtKeyRejectsTraversalAndServesBytes() async throws {
        let server = fixture.iFlyServer()
        let items = try await source(server).catalogue { _ in }.items
        let item = try XCTUnwrap(items.first { $0.title == "Ikaruga" })
        let art = try await source(server).artwork(for: item)
        XCTAssertEqual(art, fixture.library.art)
        let transport = InProcessTransport { await server.handle($0) }
        let token = try await authenticate(transport)
        let bad = try await transport.send(.authorizedGet(
            url: ContinuityRoutes.url(base: base, path: TestPaths.art, key: "../secret"), token: token
        ))
        XCTAssertEqual(bad.status, 400)
    }
}

final class ICubeDialectServerTests: XCTestCase {
    private var fixture: ServerFixture!
    private let base = URL(string: "http://provenance.local:8485")!
    private let client = PeerIdentity(id: "icube-device", name: "iCube on Apple TV")

    override func setUpWithError() throws {
        fixture = try ServerFixture()
    }

    override func tearDown() {
        fixture.cleanUp()
    }

    private func source(_ server: ICubeDialectServer) -> ICubeContinuitySource {
        ICubeContinuitySource(
            baseURLs: [base], identity: client,
            transport: InProcessTransport { await server.handle($0) }, pollInterval: 0.01
        )
    }

    private func pair(_ iCube: ICubeContinuitySource) async throws {
        let handle = try await iCube.beginPairing()
        XCTAssertEqual(handle.serverName, "Joe's iPad")
        // Wait for the scripted owner to "show" the code.
        for _ in 0..<200 where fixture.owner.lastCode == nil {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        try await iCube.completePairing(handle, code: try XCTUnwrap(fixture.owner.lastCode))
    }

    func testUnpairedPeerIsToldToPair() async throws {
        do {
            _ = try await source(fixture.iCubeServer()).catalogue { _ in }
            XCTFail("expected notPaired")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .notPaired)
        }
    }

    /// A right code stores the trust and answers iCube's 404, which iCube's
    /// client (and Provenance's) count as paired.
    func testPairingThenBrowseListsOnlyGameCubeAndWii() async throws {
        fixture.owner.pull = .allowAlways
        let server = fixture.iCubeServer()
        let iCube = source(server)
        try await pair(iCube)
        let trusted = await fixture.trust.peer(withId: client.id)
        XCTAssertEqual(trusted?.app, "icube")

        let catalogue = try await iCube.catalogue { _ in }
        XCTAssertEqual(catalogue.items.map(\.title), ["Super Mario Sunshine"])
        XCTAssertEqual(catalogue.items.first?.id, "id:GMSE01|d0|r-1")
        XCTAssertEqual(catalogue.items.first?.systemIdentifier, .GameCube)

        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let pulled = try await LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "p")
            .pull(try XCTUnwrap(catalogue.items.first), from: iCube) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), try fixture.library.data(of: "SUNSHINE")[0])
        XCTAssertEqual(fixture.owner.pullPrompts, ["Super Mario Sunshine"])
    }

    func testWrongCodeIsRetryableThenExpires() async throws {
        let iCube = source(fixture.iCubeServer())
        let handle = try await iCube.beginPairing()
        for _ in 0..<200 where fixture.owner.lastCode == nil {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        let wrong = fixture.owner.lastCode == "000000" ? "111111" : "000000"
        for attempt in 1...3 {
            do {
                try await iCube.completePairing(handle, code: wrong)
                XCTFail("wrong code accepted")
            } catch {
                XCTAssertEqual(error as? LibrarySharingError, attempt < 3 ? .wrongCode : .expired)
            }
        }
    }

    func testCatalogAndManifestDecodeWithICubesOwnDecoders() async throws {
        fixture.owner.pull = .allowAlways
        let server = fixture.iCubeServer()
        let iCube = source(server)
        try await pair(iCube)
        let transport = InProcessTransport { await server.handle($0) }
        let start = try await transport.send(.jsonPost(url: base.appendingPathComponent(TestPaths.authStart), body: ICubeAuthStartRequest(peerId: client.id)))
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: start.body)
        let signature = try ContinuityAuthMath.signAuth(
            domain: .iCube, nonce: challenge.nonce, peerId: client.id, serverId: challenge.serverId, signingKey: client.signingKey
        )
        let complete = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.authComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: client.id, signature: signature)
        ))
        let token = try JSONDecoder().decode(LibraryTokenResponse.self, from: complete.body).libraryToken

        let catalogData = try await transport.send(.authorizedGet(url: base.appendingPathComponent(TestPaths.iCubeCatalog), token: token)).body
        let catalog = try ICubeStrict.decode(ICubeStrict.Catalog.self, catalogData)
        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.entries.map(\.game.platform), ["gc"])

        let key = try XCTUnwrap(catalog.entries.first?.key)
        let manifestData = try await transport.send(.authorizedGet(
            url: ContinuityRoutes.url(base: base, path: TestPaths.iCubeManifest, key: key), token: token
        )).body
        let manifest = try ICubeStrict.decode(ICubeStrict.Manifest.self, manifestData)
        XCTAssertEqual(manifest.files.map(\.relativePath), ["Software/Sunshine.iso"])
        XCTAssertEqual(manifest.files.map(\.kind), ["gameFile"])
        // No owner data: no saves, no memory cards, no BIOS.
        XCTAssertEqual(manifest.files.count, 1)
    }

    func testSharingOffRefusesLibraryButPairingStillAnswers() async throws {
        fixture.sharing.value = false
        let server = fixture.iCubeServer()
        let transport = InProcessTransport { await server.handle($0) }
        let start = try await transport.send(.jsonPost(url: base.appendingPathComponent(TestPaths.authStart), body: ICubeAuthStartRequest(peerId: client.id)))
        XCTAssertEqual(start.status, 403)
        let pairing = try await transport.send(.jsonPost(
            url: base.appendingPathComponent(TestPaths.pairStart),
            body: ICubePairStartRequest(peerId: client.id, name: client.name, publicKey: client.publicKeyData)
        ))
        XCTAssertEqual(pairing.status, 200)
    }
}
