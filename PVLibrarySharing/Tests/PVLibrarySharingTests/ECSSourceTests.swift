//
//  ECSSourceTests.swift
//  PVLibrarySharingTests
//
//  Phase 5: emulator-content-server through `LibrarySource`, against a fake
//  that answers like `apps/server/src/routes.ts` (shapes from
//  packages/protocol/openapi/openapi.yaml).
//

import PVSystems
import XCTest
@testable import PVLibrarySharing

/// A content server in memory: one library, three items, Range-aware content.
final class FakeContentServer: @unchecked Sendable {
    let rom = Data((0..<40_000).map { UInt8($0 % 211) })
    let bios = Data(repeating: 0xB1, count: 512)
    var major = 1
    var maxPageSize = 2
    var canMintDeviceTokens = true
    var ignoresRange = false
    private let lock = NSLock()
    private(set) var logins = 0
    private var validTokens: Set<String> = []

    func expireTokens() {
        lock.withLock { validTokens.removeAll() }
    }

    private func json(_ object: Any, status: Int = 200) -> ServerResponse {
        // swiftlint:disable:next force_try
        .json(try! JSONSerialization.data(withJSONObject: object), status: status)
    }

    func handle(_ request: ServerRequest) -> ServerResponse {
        lock.lock()
        defer { lock.unlock() }
        switch (request.method, request.path) {
        case ("GET", "/api/v1/capabilities"):
            return json(["protocol": ["major": major, "minor": 0, "path": "/api/v1"], "minClientVersion": "1.0",
                         "features": [:], "limits": ["maxUploadBytes": 1, "maxPageSize": maxPageSize], "authentication": ["bearer"]])
        case ("POST", "/api/v1/auth/login"):
            guard let body = request.body, let login = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  login["username"] == "joe", login["password"] == "hunter2" else {
                return .error(401, "Username or password is incorrect")
            }
            logins += 1
            validTokens.insert("session-\(logins)")
            return json(["token": "session-\(logins)", "tokenType": "Bearer", "userId": "u1", "expiresAt": "2027-01-01T00:00:00Z"])
        case ("POST", "/api/v1/device-tokens"):
            guard authorized(request) else { return .error(401, "Bearer token is required") }
            guard canMintDeviceTokens else { return .error(403, "admin scope required") }
            validTokens.insert("device-\(logins)")
            return json(["id": "t1", "token": "device-\(logins)", "scopes": ["read"]], status: 201)
        default:
            break
        }
        guard authorized(request) else { return .error(401, "Bearer token is required") }
        switch request.path {
        case "/api/v1/libraries":
            return json(["items": [["id": "lib1", "name": "Library", "ownerId": "u1", "revision": 1, "createdAt": "x"]], "nextCursor": NSNull()])
        case "/api/v1/items":
            let all: [[String: Any]] = [
                ["id": "i1", "libraryId": "lib1", "systemIdentifier": "com.provenance.snes", "title": "Chrono Trigger", "md5": "aa"],
                ["id": "i2", "libraryId": "lib1", "systemIdentifier": "com.provenance.dreamcast", "title": "Rez", "md5": NSNull()],
                ["id": "i3", "libraryId": "lib1", "systemIdentifier": "com.provenance.wii", "title": "Zack & Wiki", "md5": NSNull()]
            ]
            let start = Int(request.query["cursor"] ?? "0") ?? 0
            let end = min(start + maxPageSize, all.count)
            return json(["items": Array(all[start..<end]), "nextCursor": end < all.count ? String(end) as Any : NSNull()])
        case "/api/v1/items/i1/manifest":
            return json(["version": 1, "itemId": "i1", "revision": 3, "files": [
                ["id": "f1", "kind": "rom", "relativePath": "Chrono Trigger.sfc", "sha256": sha256Hex(rom), "md5": NSNull(), "crc": NSNull(),
                 "size": rom.count, "required": true, "contentPath": "/api/v1/files/f1/content"],
                ["id": "f2", "kind": "bios", "relativePath": "bios.bin", "sha256": sha256Hex(bios), "md5": NSNull(), "crc": NSNull(),
                 "size": bios.count, "required": false, "contentPath": "/api/v1/files/f2/content"]
            ]])
        case "/api/v1/files/f1/content":
            return content(rom, request)
        case "/api/v1/files/f2/content":
            return content(bios, request)
        default:
            return .error(404, "not found")
        }
    }

    private func authorized(_ request: ServerRequest) -> Bool {
        guard let token = ServerTokens.bearer(request.header("Authorization")) else { return false }
        return validTokens.contains(token)
    }

    private func content(_ data: Data, _ request: ServerRequest) -> ServerResponse {
        if !ignoresRange, let range = ByteRange.parse(request.header("Range")), let length = range.length(totalSize: Int64(data.count)) {
            let slice = data.subdata(in: Int(range.offset)..<Int(range.offset + length))
            return ServerResponse(status: 206, headers: ["Content-Range": range.contentRange(totalSize: Int64(data.count)) ?? ""], body: .data(slice))
        }
        return ServerResponse(status: 200, body: .data(data))
    }
}

final class ECSSourceTests: XCTestCase {
    private let server = URL(string: "https://ecs.local:8443")!

    private func source(_ fake: FakeContentServer, tokens: any ECSTokenStore = InMemoryECSTokenStore(),
                        password: String? = "hunter2", systems: Set<SystemIdentifier>? = nil) -> ECSSource {
        ECSSource(
            server: server, username: "joe", password: password, deviceName: "Provenance on iPhone", systems: systems,
            tokens: tokens, transport: InProcessTransport { fake.handle($0) }
        )
    }

    func testListsEveryPageAndFiltersLocally() async throws {
        let fake = FakeContentServer()
        let all = try await source(fake).catalogue { _ in }
        XCTAssertEqual(all.items.map(\.title), ["Chrono Trigger", "Rez", "Zack & Wiki"])
        XCTAssertEqual(all.items.map(\.systemIdentifier), [.SNES, .Dreamcast, .Wii])

        let playable = try await source(fake, systems: [.SNES, .Dreamcast]).catalogue { _ in }
        XCTAssertEqual(playable.items.map(\.title), ["Chrono Trigger", "Rez"])
    }

    func testMintsADeviceTokenAndReusesIt() async throws {
        let fake = FakeContentServer()
        let tokens = InMemoryECSTokenStore()
        _ = try await source(fake, tokens: tokens).catalogue { _ in }
        XCTAssertEqual(tokens.token(for: server), "device-1")
        // A later launch with no password uses the stored token.
        _ = try await source(fake, tokens: tokens, password: nil).catalogue { _ in }
        XCTAssertEqual(fake.logins, 1)
    }

    func testReaderWithoutAdminScopeFallsBackToTheSessionToken() async throws {
        let fake = FakeContentServer()
        fake.canMintDeviceTokens = false
        let tokens = InMemoryECSTokenStore()
        _ = try await source(fake, tokens: tokens).catalogue { _ in }
        XCTAssertEqual(tokens.token(for: server), "session-1")
    }

    func testExpiredTokenSignsInAgainOnce() async throws {
        let fake = FakeContentServer()
        let ecs = source(fake)
        _ = try await ecs.catalogue { _ in }
        fake.expireTokens()
        _ = try await ecs.catalogue { _ in }
        XCTAssertEqual(fake.logins, 2)
    }

    func testWrongPasswordAndNewerProtocolFailClearly() async throws {
        do {
            _ = try await source(FakeContentServer(), password: "nope").catalogue { _ in }
            XCTFail("expected signInFailed")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .signInFailed)
        }
        let newer = FakeContentServer()
        newer.major = 2
        do {
            _ = try await source(newer).catalogue { _ in }
            XCTFail("expected unsupportedServer")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .unsupportedServer("protocol 2.0"))
        }
    }

    func testCopiesTheROMResumingWithRangeAndLeavesBIOS() async throws {
        let fake = FakeContentServer()
        let ecs = source(fake)
        let items = try await ecs.catalogue { _ in }.items
        let item = try XCTUnwrap(items.first)
        let manifest = try await ecs.pullManifest(for: item) { _ in }
        XCTAssertEqual(manifest.gameFiles.map(\.relativePath), ["Chrono Trigger.sfc"])
        XCTAssertEqual(manifest.skippedFiles.map(\.kind), ["bios"])

        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let puller = LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "ecs")
        let folder = puller.folder(for: item, from: .contentServer)
        let destination = try XCTUnwrap(LibraryStaging.containedURL(for: "Chrono Trigger.sfc", in: folder))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fake.rom.prefix(15_000).write(to: destination.appendingPathExtension("part"))

        let pulled = try await puller.pull(item, from: ecs) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), fake.rom)
        XCTAssertEqual(pulled.systemIdentifier, .SNES)
        XCTAssertEqual(pulled.skippedKinds, ["bios"])
    }

    /// ECS's rule: a 200 to a ranged request means start again from zero.
    func testRangeIgnoredRestartsFromZero() async throws {
        let fake = FakeContentServer()
        fake.ignoresRange = true
        let ecs = source(fake)
        let items = try await ecs.catalogue { _ in }.items
        let item = try XCTUnwrap(items.first)
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let puller = LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "ecs")
        let destination = try XCTUnwrap(LibraryStaging.containedURL(for: "Chrono Trigger.sfc", in: puller.folder(for: item, from: .contentServer)))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0, count: 15_000).write(to: destination.appendingPathExtension("part"))
        let pulled = try await puller.pull(item, from: ecs) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), fake.rom)
    }

    func testContentPathOnAnotherHostIsRefused() async throws {
        let ecs = source(FakeContentServer())
        let file = RemoteFile(kind: "gameFile", relativePath: "x.sfc", sha256: "00", size: 1, contentPath: "https://evil.example/steal")
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        do {
            _ = try await ecs.download(file, of: RemoteManifest(itemId: "i1", files: [file]),
                                       to: staging.appendingPathComponent("x.part"), resumeOffset: 0) { _ in }
            XCTFail("expected unsafePath")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .unsafePath("https://evil.example/steal"))
        }
    }
}
