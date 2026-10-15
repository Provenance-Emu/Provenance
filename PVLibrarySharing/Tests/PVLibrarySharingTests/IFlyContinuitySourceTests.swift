//
//  IFlyContinuitySourceTests.swift
//  PVLibrarySharingTests
//

import CryptoKit
import PVSystems
import XCTest
@testable import PVLibrarySharing

final class IFlyContinuitySourceTests: XCTestCase {
    private let base = URL(string: "http://ifly.local:8080")!
    private let nonce = Data([9, 8, 7, 6])
    private let identity = PeerIdentity(id: "provenance-peer", name: "Provenance on iPhone")

    private func makeSource(_ transport: MockTransport, approvalTimeout: TimeInterval = 5) -> IFlyContinuitySource {
        IFlyContinuitySource(
            baseURLs: [base], identity: identity, transport: transport,
            pollInterval: 0.01, approvalTimeout: approvalTimeout
        )
    }

    private func scriptAuth(_ transport: MockTransport, completes: LibraryHTTPResponse...) {
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "auth-1", serverId: "ifly-server", nonce: nonce)))
        for response in completes {
            transport.script(TestPaths.authComplete, response)
        }
    }

    // MARK: - Fixture decode

    func testManifestFixtureDecodesAndMaps() throws {
        let manifest = try JSONDecoder().decode(IFlyLibraryManifest.self, from: Fixture.data("ifly-library-manifest"))
        let catalogue = IFlyContinuitySource.catalogue(from: manifest)

        XCTAssertEqual(catalogue.deviceName, "Joe's iPad")
        XCTAssertEqual(catalogue.items.count, 5)
        XCTAssertEqual(catalogue.items.map(\.systemIdentifier), [.Dreamcast, .NAOMI, .NAOMI2, .Atomiswave, nil])
        XCTAssertEqual(catalogue.supportedItems.count, 4)
        XCTAssertEqual(catalogue.systems, [.Atomiswave, .Dreamcast, .NAOMI, .NAOMI2].sorted())

        let ikaruga = catalogue.items[0]
        XCTAssertEqual(ikaruga.id, "0123456789abcdef0123456789abcdef")
        XCTAssertEqual(ikaruga.artKey, "covers/ikaruga cover+1.jpg")
        XCTAssertEqual(ikaruga.sizeBytes, 1_234_567)
        XCTAssertEqual(ikaruga.source, .iFly)
        // md5 is normalised to lower case.
        XCTAssertEqual(catalogue.items[2].md5, "fedcba9876543210fedcba9876543210")
    }

    /// iFly's `Game.id` is computed and never sent; phase 2's pull must send it.
    func testGameIdFallsBackToTitlePlatformSize() throws {
        let manifest = try JSONDecoder().decode(IFlyLibraryManifest.self, from: Fixture.data("ifly-library-manifest"))
        XCTAssertEqual(manifest.games[1].id, "Marvel vs. Capcom 2|Naomi|42")
        XCTAssertEqual(IFlyContinuitySource.catalogue(from: manifest).items[1].id, "Marvel vs. Capcom 2|Naomi|42")
    }

    // MARK: - Auth

    func testConsentAuthPollsThenFetchesManifestWithBearer() async throws {
        let transport = MockTransport()
        scriptAuth(transport, completes: .status(202), .status(202), .json(LibraryTokenResponse(libraryToken: "lib-token")))
        transport.script(TestPaths.iFlyManifest, LibraryHTTPResponse(
            status: 200, headers: ["Etag": "v1-3f2a"], body: try Fixture.data("ifly-library-manifest")
        ))
        let progressLog = ProgressLog()

        let catalogue = try await makeSource(transport).catalogue { progressLog.append($0) }
        XCTAssertEqual(catalogue.items.count, 5)
        XCTAssertTrue(progressLog.values.contains(.waitingForApproval))

        // auth/start carries name + raw 32-byte public key (base64) so the host can prompt.
        let start = try jsonObject(try XCTUnwrap(transport.requests(to: TestPaths.authStart).first))
        XCTAssertEqual(start["peerId"] as? String, "provenance-peer")
        XCTAssertEqual(start["name"] as? String, "Provenance on iPhone")
        XCTAssertEqual(start["publicKey"] as? String, identity.publicKeyData.base64EncodedString())
        XCTAssertNil(start["icloudHash"])

        // The signature is over the iFly transcript.
        let completes = transport.requests(to: TestPaths.authComplete)
        XCTAssertEqual(completes.count, 3)
        let complete = try jsonObject(try XCTUnwrap(completes.first))
        XCTAssertEqual(complete["authId"] as? String, "auth-1")
        let signature = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(complete["signature"] as? String)))
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: identity.publicKeyData)
        XCTAssertTrue(key.isValidSignature(
            signature, for: Data("ifly-continuity-auth-v1|provenance-peer|ifly-server|".utf8) + nonce
        ))

        let manifestRequest = try XCTUnwrap(transport.requests(to: TestPaths.iFlyManifest).first)
        XCTAssertEqual(manifestRequest.headers["Authorization"], "Bearer lib-token")
        XCTAssertNil(manifestRequest.headers["If-None-Match"])
    }

    func testRepeatFetchSendsETagAndReusesCacheOn304() async throws {
        let transport = MockTransport()
        scriptAuth(transport, completes: .json(LibraryTokenResponse(libraryToken: "lib-token")))
        transport.script(
            TestPaths.iFlyManifest,
            LibraryHTTPResponse(status: 200, headers: ["ETag": "v1-3f2a"], body: try Fixture.data("ifly-library-manifest")),
            LibraryHTTPResponse(status: 304)
        )
        let source = makeSource(transport)
        let first = try await source.catalogue { _ in }
        let second = try await source.catalogue { _ in }

        XCTAssertEqual(first, second)
        XCTAssertEqual(transport.requests(to: TestPaths.iFlyManifest).last?.headers["If-None-Match"], "v1-3f2a")
        XCTAssertEqual(transport.requests(to: TestPaths.authStart).count, 1, "the token is reused")
    }

    func testDontShareIsDeclined() async {
        let transport = MockTransport()
        scriptAuth(transport, completes: .status(403))
        await assertThrows(LibrarySharingError.declined) { try await self.makeSource(transport).catalogue { _ in } }
    }

    func testSharingOffIsUnavailable() async {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .status(404))
        await assertThrows(LibrarySharingError.sharingUnavailable) { try await self.makeSource(transport).catalogue { _ in } }
    }

    func testUnansweredConsentTimesOut() async {
        let transport = MockTransport()
        scriptAuth(transport, completes: .status(202))
        await assertThrows(LibrarySharingError.approvalTimedOut) {
            try await self.makeSource(transport, approvalTimeout: 0).catalogue { _ in }
        }
    }

    func testExpiredTokenReauthenticatesOnce() async throws {
        let transport = MockTransport()
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "auth-1", serverId: "s", nonce: nonce)))
        transport.script(TestPaths.authComplete,
                         .json(LibraryTokenResponse(libraryToken: "old")),
                         .json(LibraryTokenResponse(libraryToken: "new")))
        transport.script(TestPaths.iFlyManifest,
                         .status(401),
                         LibraryHTTPResponse(status: 200, body: try Fixture.data("ifly-library-manifest")))
        _ = try await makeSource(transport).catalogue { _ in }
        XCTAssertEqual(transport.requests(to: TestPaths.iFlyManifest).map { $0.headers["Authorization"] },
                       ["Bearer old", "Bearer new"])
    }

    // MARK: - Art and URLs

    func testArtURLEscapesOpaqueKey() async throws {
        let transport = MockTransport()
        scriptAuth(transport, completes: .json(LibraryTokenResponse(libraryToken: "lib-token")))
        transport.script(TestPaths.art, LibraryHTTPResponse(status: 200, body: Data([1, 2, 3])))
        let item = RemoteLibraryItem(
            id: "x", title: "Ikaruga", platform: "Dreamcast", systemIdentifier: .Dreamcast, md5: nil,
            sizeBytes: 1, artKey: "covers/ikaruga cover+1.jpg", source: .iFly
        )
        let data = try await makeSource(transport).artwork(for: item)
        XCTAssertEqual(data, Data([1, 2, 3]))

        let request = try XCTUnwrap(transport.requests(to: TestPaths.art).first)
        let components = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "key", value: "covers/ikaruga cover+1.jpg")])
        XCTAssertEqual(request.headers["Authorization"], "Bearer lib-token")
    }

    func testFallsBackToNextAdvertisedURL() async throws {
        let transport = MockTransport()
        transport.makeUnreachable(host: "dead.local")
        scriptAuth(transport, completes: .json(LibraryTokenResponse(libraryToken: "t")))
        transport.script(TestPaths.iFlyManifest, LibraryHTTPResponse(status: 200, body: try Fixture.data("ifly-library-manifest")))
        let source = IFlyContinuitySource(
            baseURLs: [URL(string: "http://dead.local:8080")!, base], identity: identity, transport: transport
        )
        _ = try await source.catalogue { _ in }
        XCTAssertTrue(transport.requests.allSatisfy { $0.url.host == "ifly.local" })
    }
}

/// Collects progress callbacks from the source actor.
final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [LibraryBrowseProgress] = []

    func append(_ value: LibraryBrowseProgress) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(value)
    }

    var values: [LibraryBrowseProgress] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

func assertThrows<T>(
    _ expected: LibrarySharingError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> T
) async {
    do {
        _ = try await body()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch let error as LibrarySharingError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("unexpected \(error)", file: file, line: line)
    }
}
