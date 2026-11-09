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
    var includeIndexedSource = false
    var indexedDiscGroup = false
    let cue = Data("FILE \"../tracks/Track.bin\" BINARY\n TRACK 01 MODE1/2352\n INDEX 01 00:00:00\n".utf8)
    var repeatCursor = false
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
                         "features": ["rangeRequests": true, "multiRange": false, "resumableUploads": true, "changeFeed": true,
                                      "guestGrants": true, "virtualFormats": [], "webdav": false, "natTraversal": false],
                         "limits": ["maxUploadBytes": 1, "maxPageSize": maxPageSize], "authentication": ["bearer"]])
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
        case "/api/v1/browse-libraries":
            return json(["items": [["id": "lib1", "name": "Library", "ownerId": "u1", "revision": 1, "createdAt": "x"]], "nextCursor": NSNull()])
        case "/api/v1/browse":
            let all: [[String: Any]] = [
                ["id": "i1", "libraryId": "lib1", "systemIdentifier": "com.provenance.snes", "title": "Chrono Trigger", "md5": "aa"],
                ["id": "i2", "libraryId": "lib1", "systemIdentifier": "com.provenance.dreamcast", "title": "Rez", "md5": NSNull()],
                ["id": "i3", "libraryId": "lib1", "systemIdentifier": "com.provenance.wii", "title": "Zack & Wiki", "md5": NSNull()]
            ]
            let start = Int(request.query["cursor"] ?? "0") ?? 0
            let end = min(start + maxPageSize, all.count)
            let complete = all.map { $0.merging(["revision": 1, "createdAt": "x", "updatedAt": "x"]) { a, _ in a } }
            var entries: [[String: Any]] = complete.map { ["entityType": "item", "id": $0["id", default: ""], "name": $0["title", default: ""], "canUpload": false, "canAdopt": false, "item": $0] }
            if includeIndexedSource, start == 0 {
                entries.append(["entityType": "source", "id": "source-1", "name": "Indexed game", "canUpload": false, "canAdopt": false,
                                "source": ["id": "source-1", "rootId": "root", "name": indexedDiscGroup ? "Game.cue" : "Indexed.sfc", "kind": "rom", "size": indexedDiscGroup ? cue.count : rom.count,
                                           "groupFileCount": indexedDiscGroup ? 2 : 0,
                                           "systemId": "com.provenance.snes", "availability": "local", "medium": "disk",
                                           "contentPath": "/api/v1/sources/source-1/content"]])
            }
            var selected = Array(entries[start..<end])
            if includeIndexedSource, start == 0, let indexed = entries.last { selected.append(indexed) }
            return json(["items": selected, "nextCursor": repeatCursor ? "0" : (end < all.count ? String(end) as Any : NSNull())])
        case "/api/v1/items/i1/manifest":
            return json(["version": 1, "itemId": "i1", "revision": 3, "files": [
                ["id": "f1", "kind": "rom", "relativePath": "Chrono Trigger.sfc", "sha256": sha256Hex(rom), "md5": NSNull(), "crc": NSNull(),
                 "size": rom.count, "required": true, "contentPath": "/api/v1/files/f1/content"],
                ["id": "f2", "kind": "bios", "relativePath": "bios.bin", "sha256": sha256Hex(bios), "md5": NSNull(), "crc": NSNull(),
                 "size": bios.count, "required": false, "contentPath": "/api/v1/files/f2/content"]
            ]])
        case "/api/v1/sources/source-1/group":
            return json(["sourceId": "source-1", "error": NSNull(), "files": [
                ["id": "source-1", "name": "Game.cue", "relativePath": "disc/Game.cue", "size": cue.count, "availability": "local"],
                ["id": "source-track", "name": "Track.bin", "relativePath": "tracks/Track.bin", "size": rom.count, "availability": "local"]
            ]])
        case "/api/v1/sources/source-1/content" where indexedDiscGroup:
            return content(cue, request)
        case "/api/v1/files/f1/content", "/api/v1/sources/source-1/content", "/api/v1/sources/source-track/content":
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

    func testCanonicalOriginsRejectCredentialsAndPaths() throws {
        XCTAssertEqual(try ECSConnection.origin(for: " Example.COM ").absoluteString, "http://example.com:8473")
        XCTAssertEqual(try ECSConnection.origin(for: "https://Example.COM/").absoluteString, "https://example.com")
        for address in ["http://user:secret@host", "http://host/ui", "http://host?token=x", "file:///tmp", "http://host:99999"] {
            XCTAssertThrowsError(try ECSConnection.origin(for: address))
        }
    }

    func testLibraryPickerAndSelectedLibrary() async throws {
        let ecs = source(FakeContentServer())
        let libraries = try await ecs.libraries()
        XCTAssertEqual(libraries.map(\.id), ["lib1"])
        let selected = try await ecs.catalogue(libraryID: "lib1") { _ in }
        XCTAssertEqual(selected.items.count, 3)
        let absent = try await ecs.catalogue(libraryID: "missing") { _ in }
        XCTAssertTrue(absent.items.isEmpty)
    }

    func testContentCannotUseAnotherPortOrScheme() async throws {
        let ecs = source(FakeContentServer())
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        for address in ["https://ecs.local:9999/api/v1/files/f1/content", "http://ecs.local:8443/api/v1/files/f1/content"] {
            let file = RemoteFile(kind: "gameFile", relativePath: "x.sfc", sha256: "00", size: 1, contentPath: address)
            do {
                _ = try await ecs.download(file, of: RemoteManifest(itemId: "i1", files: [file]),
                                           to: staging.appendingPathComponent("x.part"), resumeOffset: 0) { _ in }
                XCTFail("expected unsafe path")
            } catch { XCTAssertEqual(error as? LibrarySharingError, .unsafePath(address)) }
        }
    }

    func testIndexedSourceUsesVerifiedStaging() async throws {
        let fake = FakeContentServer()
        fake.includeIndexedSource = true
        let ecs = source(fake)
        let catalogue = try await ecs.catalogue { _ in }
        let indexed = try XCTUnwrap(catalogue.items.first { $0.id == "source:source-1" })
        let manifest = try await ecs.pullManifest(for: indexed) { _ in }
        XCTAssertEqual(manifest.gameFiles.first?.sha256, sha256Hex(fake.rom))
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let pulled = try await LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "ecs").pull(indexed, from: ecs, manifest: manifest) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), fake.rom)
        XCTAssertEqual(pulled.systemIdentifier, .SNES)
    }

    func testIndexedDiscGroupKeepsCompanions() async throws {
        let fake = FakeContentServer()
        fake.includeIndexedSource = true
        fake.indexedDiscGroup = true
        let ecs = source(fake)
        let catalogue = try await ecs.catalogue { _ in }
        let item = try XCTUnwrap(catalogue.items.first { $0.id == "source:source-1" })
        let staging = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let pulled = try await LibraryPuller(staging: LibraryStaging(root: staging), peerKey: "ecs").pull(item, from: ecs) { _ in }
        XCTAssertEqual(pulled.primaryFile.lastPathComponent, "Game.cue")
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), fake.cue)
        XCTAssertEqual(pulled.gameFiles.count, 2)
        XCTAssertNoThrow(try ECSDownloadedGame.validate(pulled))
    }

    func testRepeatedCursorFailsInsteadOfLooping() async throws {
        let fake = FakeContentServer()
        fake.repeatCursor = true
        do {
            _ = try await source(fake).catalogue { _ in }
            XCTFail("expected invalid pagination")
        } catch { XCTAssertEqual(error as? LibrarySharingError, .invalidResponse(status: 200)) }
    }

    func testDiscDescriptorsCannotReadOutsideDownloadedSet() throws {
        let root = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let cue = root.appendingPathComponent("Game.cue")
        let track = root.appendingPathComponent("Track.bin")
        try Data([1, 2, 3]).write(to: track)
        let game = PulledGame(folder: root, gameFiles: [cue, track], primaryFile: cue, systemIdentifier: .PSX, skippedKinds: [])
        try Data("FILE \"Track.bin\" BINARY\n".utf8).write(to: cue)
        XCTAssertNoThrow(try ECSDownloadedGame.validate(game))
        try Data("FILE \"../private.bin\" BINARY\n".utf8).write(to: cue)
        XCTAssertThrowsError(try ECSDownloadedGame.validate(game))
        let playlist = root.appendingPathComponent("Game.m3u")
        try Data("|".utf8).write(to: playlist)
        let empty = PulledGame(folder: root, gameFiles: [playlist], primaryFile: playlist, systemIdentifier: .PSX, skippedKinds: [])
        XCTAssertThrowsError(try ECSDownloadedGame.validate(empty))
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
