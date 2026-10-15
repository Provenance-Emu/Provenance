//
//  ListenerTests.swift
//  PVLibrarySharingTests
//
//  HTTP framing, the LAN filter, and the listener over a real socket with
//  URLSession: keep-alive, request bodies, and Range on a streamed file.
//

import XCTest
@testable import PVLibrarySharing

final class HTTPFramingTests: XCTestCase {
    func testParsesHeadPathQueryAndKeepAlive() throws {
        let head = try HTTP1.parseHead(Data("GET /api/continuity/library/file?key=id%3AGMSE01%7Cd0&path=Software%2Fa%20b.iso HTTP/1.1\r\nHost: x\r\nRange: bytes=5-\r\n".utf8))
        XCTAssertTrue(head.keepAlive)
        let request = HTTP1.request(head: head, body: nil, remoteAddress: nil)
        XCTAssertEqual(request.path, "/api/continuity/library/file")
        XCTAssertEqual(request.query["key"], "id:GMSE01|d0")
        XCTAssertEqual(request.query["path"], "Software/a b.iso")
        XCTAssertEqual(request.header("RANGE"), "bytes=5-")

        let closing = try HTTP1.parseHead(Data("POST / HTTP/1.1\r\nConnection: close\r\nContent-Length: 2\r\n".utf8))
        XCTAssertFalse(closing.keepAlive)
        XCTAssertEqual(closing.contentLength, 2)
    }

    func testRefusesMalformedChunkedAndHugeBodies() {
        XCTAssertThrowsError(try HTTP1.parseHead(Data("NONSENSE\r\n".utf8)))
        XCTAssertThrowsError(try HTTP1.parseHead(Data("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n".utf8))) {
            XCTAssertEqual($0 as? HTTP1.ParseError, .unsupportedTransferEncoding)
        }
        XCTAssertThrowsError(try HTTP1.parseHead(Data("POST / HTTP/1.1\r\nContent-Length: 99999999\r\n".utf8))) {
            XCTAssertEqual($0 as? HTTP1.ParseError, .bodyTooLarge)
        }
    }

    func testResponseHeadCarriesLengthAndConnection() {
        let head = String(bytes: HTTP1.responseHead(.error(404, "x"), contentLength: 13, keepAlive: false), encoding: .utf8) ?? ""
        XCTAssertTrue(head.hasPrefix("HTTP/1.1 404 Not Found\r\n"))
        XCTAssertTrue(head.contains("Content-Length: 13\r\n"))
        XCTAssertTrue(head.contains("Connection: close\r\n"))
        XCTAssertTrue(head.hasSuffix("\r\n\r\n"))
    }

    /// Peers advertise base URLs with and without a trailing slash; routes
    /// must never gain a double slash (macOS 15 / iOS 17-18 Foundation keeps it).
    func testRoutesJoinWithOneSlash() {
        for base in ["http://icube.local/", "http://icube.local", "http://10.0.0.2:8080/"] {
            let url = URL(string: base)!.appendingRoute("/api/continuity/library/catalog")  // swiftlint:disable:this force_unwrapping
            XCTAssertFalse(url.absoluteString.contains("//api"), url.absoluteString)
            XCTAssertEqual(url.path, "/api/continuity/library/catalog")
        }
        let file = ContinuityRoutes.libraryFileURL(base: URL(string: "http://icube.local/")!, key: "k", relativePath: "a b")  // swiftlint:disable:this force_unwrapping
        XCTAssertEqual(file.path, "/api/continuity/library/file")
    }

    func testByteRanges() {
        XCTAssertEqual(ByteRange.parse("bytes=10-"), ByteRange(offset: 10))
        XCTAssertEqual(ByteRange.parse("bytes=10-19")?.length(totalSize: 100), 10)
        XCTAssertEqual(ByteRange.parse("bytes=10-19")?.contentRange(totalSize: 100), "bytes 10-19/100")
        XCTAssertNil(ByteRange.parse("bytes=0-1,5-6"))
        XCTAssertNil(ByteRange.parse("bytes=-5"))
        XCTAssertNil(ByteRange(offset: 100).length(totalSize: 100))
    }
}

final class LANFilterTests: XCTestCase {
    private func ip(_ text: String) -> IPAddressBytes {
        IPAddressBytes(string: text) ?? IPAddressBytes([0, 0, 0, 0])!  // swiftlint:disable:this force_unwrapping
    }

    private var home: [LocalInterfaceAddress] {
        [
            LocalInterfaceAddress(name: "en0", address: ip("192.168.1.20"), netmask: ip("255.255.255.0")),
            LocalInterfaceAddress(name: "en0", address: ip("2001:db8:1:2::20"), netmask: ip("ffff:ffff:ffff:ffff::"))
        ]
    }

    func testAllowsLoopbackLinkLocalAndOnLinkPrefixes() {
        for allowed in ["127.0.0.1", "::1", "169.254.3.4", "fe80::1%en0", "192.168.1.77", "2001:db8:1:2::99", "::ffff:192.168.1.5"] {
            XCTAssertTrue(LANFilter.isAllowed(ip(allowed), interfaces: home), allowed)
        }
    }

    func testRefusesAddressesFromOutsideTheLAN() {
        for refused in ["192.168.2.1", "8.8.8.8", "2001:db8:9:9::1", "::ffff:10.0.0.1"] {
            XCTAssertFalse(LANFilter.isAllowed(ip(refused), interfaces: home), refused)
        }
    }

    func testBaseURLsPreferWiFiIPv4() {
        let interfaces = home + [LocalInterfaceAddress(name: "bridge100", address: ip("10.0.0.1"), netmask: ip("255.255.255.0"))]
        XCTAssertEqual(LANFilter.baseURLs(port: 8484, interfaces: interfaces, hostName: "localhost").map(\.absoluteString), [
            "http://192.168.1.20:8484", "http://10.0.0.1:8484"
        ])
        // Router-less peer-to-peer: no IPv4, but the .local name still reaches us.
        XCTAssertEqual(LANFilter.baseURLs(port: 8484, interfaces: [], hostName: "Joes-iPad.local").map(\.absoluteString), [
            "http://Joes-iPad.local:8484"
        ])
    }

    func testAdvertTXTMatchesTheContinuityCodec() throws {
        let txt = LibraryAdvertTXT.record(
            peerId: "pid-1", urls: [URL(string: "http://192.168.1.20:8484")!], systems: [.Dreamcast, .NAOMI], sessionId: "sid-1"
        )
        XCTAssertEqual(txt, [
            "v": "1", "sid": "sid-1", "lib": "1", "pid": "pid-1", "u0": "http://192.168.1.20:8484",
            "app": "provenance", "lx": "1", "sys": "dreamcast,naomi"
        ])
        // iFly and iCube drop a record without `v` and `sid`, and read `u<digit>` as URLs: no new key may start that way.
        XCTAssertFalse(txt.keys.contains { $0.hasPrefix("u") && $0.dropFirst().first?.isNumber == true && !$0.hasPrefix("u0") })
        // Provenance's own browser accepts it as a library peer.
        let peer = try XCTUnwrap(DiscoveredPeer.make(serviceType: "_ifly-continuity._tcp.", serviceName: "Provenance iPad", txt: txt))
        XCTAssertEqual(peer.advertisement.peerId, "pid-1")
        XCTAssertNil(txt["tok"])
    }
}

#if canImport(Network)
final class ListenerLoopbackTests: XCTestCase {
    private var listener: LibraryHTTPListener?
    private var folder: URL!

    override func setUpWithError() throws {
        folder = try makeTemporaryFolder()
    }

    override func tearDown() {
        listener?.stop()
        try? FileManager.default.removeItem(at: folder)
    }

    /// A free-ish port well away from the app's 8484.
    private var firstPort: UInt16 { UInt16.random(in: 41_000...49_000) }

    func testServesJSONBodiesKeepAliveAndRangedFilesOverRealSockets() async throws {
        let payload = Data((0..<600_000).map { UInt8($0 % 251) })
        let file = folder.appendingPathComponent("game.iso")
        try payload.write(to: file)
        let listener = LibraryHTTPListener(name: "test", interfaces: { [] }) { request in
            switch request.path {
            case "/echo":
                return .json(request.body ?? Data())
            case "/file":
                return .file(file, size: Int64(payload.count), rangeHeader: request.header("Range"))
            default:
                return .error(404, "nope")
            }
        }
        self.listener = listener
        let port = try await listener.start(firstPort: firstPort)
        let base = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))
        let transport = URLSessionLibraryTransport(session: URLSession(configuration: .ephemeral))

        let echo = try await transport.send(.jsonPost(url: base.appendingPathComponent("echo"), body: ["hello": "world"]))
        XCTAssertEqual(echo.status, 200)
        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: echo.body), ["hello": "world"])
        let missing = try await transport.send(LibraryHTTPRequest(url: base.appendingPathComponent("nothing")))
        XCTAssertEqual(missing.status, 404)

        // Resume a half-downloaded file through the streaming download path.
        let partial = folder.appendingPathComponent("copy.part")
        try payload.prefix(250_000).write(to: partial)
        let result = try await transport.download(
            LibraryHTTPRequest(url: base.appendingPathComponent("file")), to: partial, resumeOffset: 250_000
        ) { _ in }
        XCTAssertEqual(result.status, 206)
        XCTAssertEqual(result.writtenFrom, 250_000)
        XCTAssertEqual(try Data(contentsOf: partial), payload)
    }

    /// The whole iFly dialect over a real socket: Provenance's client copies
    /// a GDI set from Provenance's server.
    func testIFlyCopyOverRealHTTP() async throws {
        let fixture = try ServerFixture()
        defer { fixture.cleanUp() }
        let server = fixture.iFlyServer()
        let listener = LibraryHTTPListener(name: "ifly", interfaces: { [] }) { await server.handle($0) }
        self.listener = listener
        let port = try await listener.start(firstPort: firstPort)
        let source = IFlyContinuitySource(
            baseURLs: [try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))],
            identity: PeerIdentity(id: "ifly-device", name: "iFly"), pollInterval: 0.01
        )
        let items = try await source.catalogue { _ in }.items
        let pulled = try await LibraryPuller(staging: LibraryStaging(root: folder), peerKey: "real")
            .pull(try XCTUnwrap(items.first { $0.title == "Ikaruga" }), from: source) { _ in }
        XCTAssertEqual(try pulled.gameFiles.map { try Data(contentsOf: $0) }, try fixture.library.data(of: "IKARUGA"))
    }
}
#endif
