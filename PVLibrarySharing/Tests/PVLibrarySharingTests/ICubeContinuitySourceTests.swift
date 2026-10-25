//
//  ICubeContinuitySourceTests.swift
//  PVLibrarySharingTests
//

import CryptoKit
import PVSystems
import XCTest
@testable import PVLibrarySharing

final class ICubeContinuitySourceTests: XCTestCase {
    func testAuthChallengeMustMatchSelectedPairedHost() async throws {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "a", serverId: "other-host", nonce: Data([1]))))
        transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "wrong-host-token")))
        transport.script(TestPaths.iCubeCatalog, LibraryHTTPResponse(status: 200, body: try Fixture.data("icube-library-catalog")))
        let source = ICubeContinuitySource(baseURLs: [URL(string: "http://host.local")!], identity: .init(name: "receiver"),
                                          transport: transport, expectedPeerID: "paired-host")
        do { _ = try await source.catalogue { _ in }; XCTFail("Wrong host was accepted") } catch {}
        XCTAssertTrue(transport.requests(to: TestPaths.authComplete).isEmpty)
    }

    func testPairingHandleMustMatchDiscoveredHost() async throws {
        let transport = MockTransport()
        transport.script(TestPaths.pairStart, .json(ICubePairStartResponse(pairingId: "p", serverId: "other-host",
            serverName: "Other", serverPublicKey: Data(repeating: 1, count: 32))))
        let source = ICubeContinuitySource(baseURLs: [URL(string: "http://host.local")!], identity: .init(name: "receiver"),
                                          transport: transport, expectedPeerID: "selected-host")
        do { _ = try await source.beginPairing(); XCTFail("Mismatched pairing host was accepted") } catch {}
    }
    private let base = URL(string: "http://icube.local/")!
    private let nonce = Data([1, 2, 3])
    private let identity = PeerIdentity(id: "provenance-peer", name: "Provenance on iPhone")
    private let serverKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation

    private func makeSource(_ transport: MockTransport, approvalTimeout: TimeInterval = 5) -> ICubeContinuitySource {
        ICubeContinuitySource(
            baseURLs: [base], identity: identity, transport: transport,
            pollInterval: 0.01, approvalTimeout: approvalTimeout
        )
    }

    private func scriptPairStart(_ transport: MockTransport) {
        transport.script(TestPaths.pairStart, .json(ICubePairStartResponse(
            pairingId: "pair-1", serverId: "icube-server", serverName: "Living Room iPad", serverPublicKey: serverKey
        )))
    }

    // MARK: - Fixture decode

    func testCatalogFixtureDecodesAndMaps() throws {
        let catalogue = try ICubeContinuitySource.decodeCatalogue(Fixture.data("icube-library-catalog"))
        XCTAssertEqual(catalogue.deviceName, "Living Room iPad")
        XCTAssertEqual(catalogue.items.map(\.systemIdentifier), [.GameCube, .Wii, .GameCube])
        XCTAssertEqual(catalogue.items.map(\.id), [
            "id:GALE01|d0|r2", "id:RMCE01|d0|r-1", "md5:11112222333344445555666677778888"
        ])

        let melee = catalogue.items[0]
        XCTAssertEqual(melee.title, "Super Smash Bros. Melee")
        XCTAssertEqual(melee.artKey, "id:GALE01|d0|r2", "art is addressed by the stable key")
        XCTAssertEqual(melee.gameID, "GALE01")
        XCTAssertEqual(melee.discNumber, 0)
        XCTAssertEqual(melee.revision, 2)
        XCTAssertEqual(melee.sizeBytes, 1_459_978_240)
        XCTAssertNil(catalogue.items[1].artKey, "hasArtwork false means no art request")
    }

    func testCatalogOutsideVersionOneIsRejected() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Fixture.data("icube-library-catalog")) as? [String: Any])
        json["version"] = 2
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try ICubeContinuitySource.decodeCatalogue(data)) { error in
            XCTAssertEqual(error as? LibrarySharingError, .unsupportedCatalogueVersion(2))
        }
    }

    // MARK: - Pairing

    func testUnpairedPeerIsTold() async {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .status(403))
        await assertThrows(LibrarySharingError.notPaired) { try await self.makeSource(transport).catalogue { _ in } }

        let start = transport.requests(to: TestPaths.authStart).first
        XCTAssertEqual(try start.map(jsonObject)?.keys.sorted(), ["peerId"], "iCube's auth/start body is only {peerId}")
    }

    /// iCube stores the trust first and then answers 404 "no active handoff
    /// session" when idle: that 404 means paired.
    func testPairingPollsThen404MeansPaired() async throws {
        let transport = MockTransport()
        scriptPairStart(transport)
        transport.script(TestPaths.pairComplete, .status(202), .status(404))
        let source = makeSource(transport)

        let handle = try await source.beginPairing()
        XCTAssertEqual(handle.serverName, "Living Room iPad")
        try await source.completePairing(handle, code: "123456")

        let start = try jsonObject(try XCTUnwrap(transport.requests(to: TestPaths.pairStart).first))
        XCTAssertEqual(start["peerId"] as? String, "provenance-peer")
        XCTAssertEqual(start["name"] as? String, "Provenance on iPhone")
        XCTAssertEqual(start["publicKey"] as? String, identity.publicKeyData.base64EncodedString())

        let completes = transport.requests(to: TestPaths.pairComplete)
        XCTAssertEqual(completes.count, 2)
        let body = try jsonObject(try XCTUnwrap(completes.first))
        XCTAssertEqual(body["pairingId"] as? String, "pair-1")
        let transcript = ContinuityAuthMath.pairingTranscript(
            domain: .iCube, pairingId: "pair-1", clientId: identity.id, serverId: "icube-server",
            clientPublicKey: identity.publicKeyData, serverPublicKey: serverKey
        )
        XCTAssertEqual(body["proof"] as? String,
                       ContinuityAuthMath.pairingProof(code: "123456", transcript: transcript).base64EncodedString())
    }

    func testPairingOutcomes() {
        XCTAssertEqual(ICubeContinuitySource.pairingOutcome(forStatus: 200), .paired)
        XCTAssertEqual(ICubeContinuitySource.pairingOutcome(forStatus: 404), .paired)
        XCTAssertEqual(ICubeContinuitySource.pairingOutcome(forStatus: 202), .pending)
        XCTAssertEqual(ICubeContinuitySource.pairingOutcome(forStatus: 401), .failed(.wrongCode))
        XCTAssertEqual(ICubeContinuitySource.pairingOutcome(forStatus: 403), .failed(.declined))
        XCTAssertEqual(ICubeContinuitySource.pairingOutcome(forStatus: 410), .failed(.expired))
    }

    func testWrongCodeIsRetryable() async throws {
        let transport = MockTransport()
        scriptPairStart(transport)
        transport.script(TestPaths.pairComplete, .status(401), .status(200))
        let source = makeSource(transport)
        let handle = try await source.beginPairing()
        await assertThrows(LibrarySharingError.wrongCode) { try await source.completePairing(handle, code: "000000") }
        try await source.completePairing(handle, code: "123456")
    }

    // MARK: - Browse

    func testAuthThenCatalogWithBearer() async throws {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "auth-1", serverId: "icube-server", nonce: nonce)))
        transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "lib-token")))
        transport.script(TestPaths.iCubeCatalog, LibraryHTTPResponse(status: 200, body: try Fixture.data("icube-library-catalog")))
        transport.script(TestPaths.art, LibraryHTTPResponse(status: 200, body: Data([0x89, 0x50])))
        let source = makeSource(transport)

        let catalogue = try await source.catalogue { _ in }
        XCTAssertEqual(catalogue.items.count, 3)

        let complete = try jsonObject(try XCTUnwrap(transport.requests(to: TestPaths.authComplete).first))
        let signature = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(complete["signature"] as? String)))
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: identity.publicKeyData)
        XCTAssertTrue(key.isValidSignature(
            signature, for: Data("icube-continuity-auth-v1|provenance-peer|icube-server|".utf8) + nonce
        ))
        XCTAssertFalse(key.isValidSignature(
            signature, for: Data("ifly-continuity-auth-v1|provenance-peer|icube-server|".utf8) + nonce
        ))
        XCTAssertEqual(transport.requests(to: TestPaths.iCubeCatalog).first?.headers["Authorization"], "Bearer lib-token")

        let art = try await source.artwork(for: catalogue.items[0])
        XCTAssertEqual(art, Data([0x89, 0x50]))
        let artRequest = try XCTUnwrap(transport.requests(to: TestPaths.art).first)
        let components = try XCTUnwrap(URLComponents(url: artRequest.url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "key", value: "id:GALE01|d0|r2")])
    }

    func testMissingArtIsNilNotAnError() async throws {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "a", serverId: "s", nonce: nonce)))
        transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "t")))
        transport.script(TestPaths.art, .status(404))
        let item = RemoteLibraryItem(
            id: "k", title: "T", platform: "gc", systemIdentifier: .GameCube, md5: nil,
            sizeBytes: 1, artKey: "k", source: .iCube
        )
        let art = try await makeSource(transport).artwork(for: item)
        XCTAssertNil(art)
    }
    func testICubeLibraryRejectsUserDataBeforeNormalization() async throws {
        let fields = ["saveState", "optionalExtras", "bios", "files"]
        for field in fields {
            let transport = MockTransport()
            transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "a", serverId: "s", nonce: nonce)))
            transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "t")))
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Fixture.data("icube-library-manifest")) as? [String: Any])
            let descriptor: [String: Any] = ["kind": "gameCubeMemoryCard", "relativePath": "GC/card.raw", "sha256": "aa", "size": 1]
            if field == "files" { json["files"] = (json["files"] as! [[String: Any]]) + [descriptor] }
            else if field == "saveState" { json[field] = descriptor }
            else { json[field] = [descriptor] }
            transport.script(TestPaths.iCubeManifest, LibraryHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: json)))
            let item = RemoteLibraryItem(id: "game", title: "Game", platform: "gc", systemIdentifier: .GameCube,
                                         md5: nil, sizeBytes: 3, artKey: nil, source: .iCube)
            do {
                _ = try await makeSource(transport).pullManifest(for: item) { _ in }
                XCTFail("accepted userdata field \(field)")
            } catch {
                XCTAssertTrue(ICubeContinuitySource.isItemSpecificManifestFailure(error), "\(field): \(error)")
            }
        }
    }

    func testExcludedGameManifestIsItemSpecific() async throws {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "a", serverId: "s", nonce: nonce)))
        transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "t")))
        transport.script(TestPaths.iCubeManifest, .status(404))
        let item = RemoteLibraryItem(id: "game", title: "Game", platform: "gc", systemIdentifier: .GameCube,
                                     md5: nil, sizeBytes: 3, artKey: nil, source: .iCube)
        do {
            _ = try await makeSource(transport).pullManifest(for: item) { _ in }
            XCTFail("an excluded game returned a manifest")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .itemUnavailable)
            XCTAssertTrue(ICubeContinuitySource.isItemSpecificManifestFailure(error))
        }
    }

    func testSessionFailuresAreNotItemSpecific() {
        let sessionWide: [Error] = [
            LibrarySharingError.unreachable, LibrarySharingError.declined,
            CancellationError(), URLError(.timedOut)
        ]
        for error in sessionWide {
            XCTAssertFalse(ICubeContinuitySource.isItemSpecificManifestFailure(error), "\(error)")
        }
    }

}
