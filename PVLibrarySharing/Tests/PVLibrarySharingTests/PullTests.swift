//
//  PullTests.swift
//  PVLibrarySharingTests
//
//  Phase 2: pull manifests, resumable downloads, staging.
//  Fixtures ifly-pull-manifest.json and icube-library-manifest.json follow each
//  app's `ContinuityManifest` + `FileDescriptor` as their `encoded()` writes them
//  (ISO 8601 dates, sorted keys). Hashes, sizes and names are made up.
//

import PVSystems
import XCTest
@testable import PVLibrarySharing

/// A GDI set (index + two tracks) plus a BIOS and a VMU the copy must skip.
struct GameSet {
    let files: [String: Data]
    let wire: [ContinuityPullManifest.Descriptor]

    static func make() -> GameSet {
        let gdi = Data("2\n1 0 4 2352 track01.bin 0\n2 600 0 2352 track02.bin 0\n".utf8)
        let track01 = Data((0..<5_000).map { UInt8($0 % 251) })
        let track02 = Data((0..<20_000).map { UInt8($0 % 241) })
        let bios = Data(repeating: 0xBB, count: 64)
        let vmu = Data(repeating: 0x55, count: 32)
        let files = [
            "ROMs/Ikaruga/Ikaruga.gdi": gdi,
            "ROMs/Ikaruga/track01.bin": track01,
            "ROMs/Ikaruga/track02.bin": track02,
            "BIOS/dc_boot.bin": bios,
            "flycast/vmu.bin": vmu
        ]
        func descriptor(_ kind: String, _ path: String) -> ContinuityPullManifest.Descriptor {
            ContinuityPullManifest.Descriptor(
                kind: kind, relativePath: path, sha256: sha256Hex(files[path, default: Data()]),
                size: Int64(files[path, default: Data()].count), required: true
            )
        }
        return GameSet(files: files, wire: [
            descriptor("gameFile", "ROMs/Ikaruga/Ikaruga.gdi"),
            descriptor("gameFile", "ROMs/Ikaruga/track02.bin"),
            descriptor("gameFile", "ROMs/Ikaruga/track01.bin"),
            descriptor("vmuPerGame", "flycast/vmu.bin")
        ] + [descriptor("bios", "BIOS/dc_boot.bin")].map { $0 })
    }

    /// iFly's pull manifest JSON: `bios` separate from `files`.
    func iFlyJSON(version: Int = 1) -> Data {
        let files = wire.filter { $0.kind != "bios" }
        let bios = wire.filter { $0.kind == "bios" }
        let object: [String: Any] = [
            "version": version, "sessionId": "s", "mintedAt": "2026-10-15T09:00:00Z",
            "sourceDevice": ["name": "iPad", "platform": "iOS", "appVersion": "2.4"],
            "game": ["displayName": "Ikaruga", "platform": "dreamcast"],
            "files": files.map(Self.json), "bios": bios.map(Self.json), "optionalExtras": []
        ]
        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: object)
    }

    private static func json(_ descriptor: ContinuityPullManifest.Descriptor) -> [String: Any] {
        ["kind": descriptor.kind, "relativePath": descriptor.relativePath, "sha256": descriptor.sha256,
         "size": descriptor.size, "required": descriptor.required ?? true]
    }
}

/// Pull-manifest decoding (both dialects).
final class PullManifestTests: XCTestCase {
    // MARK: - Fixture decode

    func testIFlyPullFixtureKeepsGameFilesAndSkipsBIOSAndSaves() throws {
        let manifest = try JSONDecoder().decode(ContinuityPullManifest.self, from: Fixture.data("ifly-pull-manifest"))
            .remoteManifest(itemId: "id")
        XCTAssertEqual(manifest.gameFiles.map(\.relativePath), [
            "ROMs/Ikaruga/Ikaruga.gdi", "ROMs/Ikaruga/track01.bin", "ROMs/Ikaruga/track03.bin"
        ])
        XCTAssertEqual(Set(manifest.skippedFiles.map(\.kind)), ["bios", "vmuPerGame"])
        XCTAssertEqual(manifest.primaryGameFile?.relativePath, "ROMs/Ikaruga/Ikaruga.gdi")
        // Hashes are compared lower-case.
        XCTAssertEqual(manifest.gameFiles[0].sha256, String(repeating: "a", count: 64))
        XCTAssertEqual(manifest.gameBytes, 92 + 1_425_312 + 1_185_760_800)
    }

    func testICubeManifestFixtureHasNoBIOSKey() throws {
        let manifest = try JSONDecoder().decode(ContinuityPullManifest.self, from: Fixture.data("icube-library-manifest"))
            .remoteManifest(itemId: "id:GMSE01|d0|r0")
        XCTAssertEqual(manifest.gameFiles.map(\.relativePath), ["Software/Super Mario Sunshine.rvz"])
        XCTAssertTrue(manifest.skippedFiles.isEmpty)
    }

    func testPullManifestVersionOutsideOneIsRejected() {
        let data = GameSet.make().iFlyJSON(version: 2)
        XCTAssertThrowsError(try JSONDecoder().decode(ContinuityPullManifest.self, from: data)) { error in
            XCTAssertEqual(error as? LibrarySharingError, .unsupportedCatalogueVersion(2))
        }
    }

    func testPrimaryFilePrefersPlaylistThenIndexThenFirst() {
        func files(_ names: String...) -> RemoteManifest {
            RemoteManifest(itemId: "x", files: names.map { RemoteFile(kind: "gameFile", relativePath: $0, sha256: "", size: 1) })
        }
        XCTAssertEqual(files("a.bin", "a.cue", "set.m3u").primaryGameFile?.relativePath, "set.m3u")
        XCTAssertEqual(files("track01.bin", "game.GDI").primaryGameFile?.relativePath, "game.GDI")
        XCTAssertEqual(files("game.zip", "game/disc.chd").primaryGameFile?.relativePath, "game.zip")
        XCTAssertNil(RemoteManifest(itemId: "x", files: []).primaryGameFile)
    }
}

final class PullTests: XCTestCase {
    private let iFlyBase = URL(string: "http://ifly.local:8080")!
    private let iCubeBase = URL(string: "http://icube.local:8081")!
    private let identity = PeerIdentity(id: "provenance-peer", name: "Provenance on iPhone")
    private var stagingRoot: URL!

    override func setUpWithError() throws {
        stagingRoot = try makeTemporaryFolder()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: stagingRoot)
    }

    private func iFlySource(_ transport: MockTransport) -> IFlyContinuitySource {
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "a", serverId: "ifly-server", nonce: Data([1]))))
        transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "lib-token")))
        return IFlyContinuitySource(baseURLs: [iFlyBase], identity: identity, transport: transport, pollInterval: 0.01, approvalTimeout: 5)
    }

    private func iCubeSource(_ transport: MockTransport) -> ICubeContinuitySource {
        transport.script(TestPaths.authStart, .json(AuthStartResponse(authId: "a", serverId: "icube-server", nonce: Data([1]))))
        transport.script(TestPaths.authComplete, .json(LibraryTokenResponse(libraryToken: "cube-token")))
        return ICubeContinuitySource(baseURLs: [iCubeBase], identity: identity, transport: transport, pollInterval: 0.01)
    }

    private func item(_ id: String = "0123456789abcdef0123456789abcdef", system: SystemIdentifier? = .Dreamcast, source: PeerApp = .iFly) -> RemoteLibraryItem {
        RemoteLibraryItem(
            id: id, title: "Ikaruga", platform: "Dreamcast", systemIdentifier: system,
            md5: nil, sizeBytes: 0, artKey: nil, source: source
        )
    }

    // MARK: - iFly pull route

    func testIFlyPullPollsThroughApprovalAndSendsGameId() async throws {
        let transport = MockTransport()
        let source = iFlySource(transport)
        let game = GameSet.make()
        transport.script(TestPaths.iFlyPull, .status(202), .status(202), LibraryHTTPResponse(status: 200, body: game.iFlyJSON()))
        let log = ProgressLog()

        let manifest = try await source.pullManifest(for: item("Marvel vs. Capcom 2|Naomi|42")) { log.append($0) }
        XCTAssertEqual(manifest.gameFiles.count, 3)
        XCTAssertTrue(log.values.contains(.waitingForApproval))

        let pulls = transport.requests(to: TestPaths.iFlyPull)
        XCTAssertEqual(pulls.count, 3)
        XCTAssertEqual(pulls[0].method, "POST")
        XCTAssertEqual(pulls[0].headers["Authorization"], "Bearer lib-token")
        XCTAssertEqual(try jsonObject(pulls[0])["gameId"] as? String, "Marvel vs. Capcom 2|Naomi|42")
    }

    func testIFlyPullStatusesMapToCopyErrors() async {
        for (status, expected) in [(403, LibrarySharingError.pullDeclined), (429, .hostLimitReached), (404, .itemUnavailable)] {
            let transport = MockTransport()
            let source = iFlySource(transport)
            transport.script(TestPaths.iFlyPull, .status(status))
            do {
                _ = try await source.pullManifest(for: item()) { _ in }
                XCTFail("expected \(expected) for \(status)")
            } catch {
                XCTAssertEqual(error as? LibrarySharingError, expected, "status \(status)")
            }
        }
    }

    func testIFlyPullReauthenticatesOnceOn401() async throws {
        let transport = MockTransport()
        let source = iFlySource(transport)
        transport.script(TestPaths.iFlyPull, .status(401), LibraryHTTPResponse(status: 200, body: GameSet.make().iFlyJSON()))
        _ = try await source.pullManifest(for: item()) { _ in }
        XCTAssertEqual(transport.requests(to: TestPaths.authStart).count, 2)
    }

    // MARK: - iCube manifest + file routes

    func testICubeManifestUsesKeyAndFileURLCarriesKeyAndPath() async throws {
        let transport = MockTransport()
        let source = iCubeSource(transport)
        let rvz = Data((0..<3_000).map { UInt8($0 % 199) })
        let wire = """
        {"version":1,"sessionId":"s","mintedAt":"2026-10-15T09:00:00Z",
         "sourceDevice":{"name":"TV","platform":"tvOS","appVersion":"1"},
         "game":{"displayName":"Sunshine","platform":"gc"},
         "files":[{"kind":"gameFile","relativePath":"Software/Sunshine.rvz","sha256":"\(sha256Hex(rvz))","size":\(rvz.count),"required":true}]}
        """
        transport.script(TestPaths.iCubeManifest, LibraryHTTPResponse(status: 200, body: Data(wire.utf8)))
        let host = FileHost(files: ["Software/Sunshine.rvz": rvz])
        transport.handle(TestPaths.file) { host.respond($0) }

        let key = "id:GMSE01|d0|r0"
        let puller = LibraryPuller(staging: LibraryStaging(root: stagingRoot), peerKey: "icube:pid")
        let pulled = try await puller.pull(item(key, system: .GameCube, source: .iCube), from: source) { _ in }

        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), rvz)
        XCTAssertEqual(pulled.systemIdentifier, .GameCube)
        XCTAssertEqual(transport.requests(to: TestPaths.iCubeManifest).first?.queryValue("key"), key)
        let fileRequest = try XCTUnwrap(transport.requests(to: TestPaths.file).first)
        XCTAssertEqual(fileRequest.queryValue("key"), key)
        XCTAssertEqual(fileRequest.queryValue("path"), "Software/Sunshine.rvz")
        XCTAssertEqual(fileRequest.headers["Authorization"], "Bearer cube-token")
    }

    func testICubeManifest404IsItemUnavailable() async {
        let transport = MockTransport()
        let source = iCubeSource(transport)
        transport.script(TestPaths.iCubeManifest, .status(404))
        do {
            _ = try await source.pullManifest(for: item(source: .iCube)) { _ in }
            XCTFail("expected itemUnavailable")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .itemUnavailable)
        }
    }

    // MARK: - Puller

    private func makeIFlyCopy(host: FileHost, game: GameSet = .make()) -> (MockTransport, IFlyContinuitySource, LibraryPuller) {
        let transport = MockTransport()
        let source = iFlySource(transport)
        transport.script(TestPaths.iFlyPull, LibraryHTTPResponse(status: 200, body: game.iFlyJSON()))
        transport.handle(TestPaths.file) { host.respond($0) }
        let puller = LibraryPuller(staging: LibraryStaging(root: stagingRoot), peerKey: "ifly:pid")
        return (transport, source, puller)
    }

    func testCopiesGameFilesSmallestFirstAndSkipsBIOSAndSaves() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (transport, source, puller) = makeIFlyCopy(host: host, game: game)

        let pulled = try await puller.pull(item(), from: source) { _ in }

        XCTAssertEqual(pulled.primaryFile.lastPathComponent, "Ikaruga.gdi")
        XCTAssertEqual(pulled.gameFiles.map(\.lastPathComponent), ["Ikaruga.gdi", "track02.bin", "track01.bin"])
        for url in pulled.gameFiles {
            let relative = "ROMs/Ikaruga/\(url.lastPathComponent)"
            XCTAssertEqual(try Data(contentsOf: url), game.files[relative])
        }
        XCTAssertEqual(pulled.skippedKinds, ["bios", "vmuPerGame"])
        XCTAssertEqual(pulled.systemIdentifier, .Dreamcast)
        let requested = transport.requests(to: TestPaths.file).compactMap { $0.queryValue("path") }
        XCTAssertEqual(requested, ["ROMs/Ikaruga/Ikaruga.gdi", "ROMs/Ikaruga/track01.bin", "ROMs/Ikaruga/track02.bin"])
        // No .part left behind.
        let leftovers = FileManager.default.enumerator(atPath: pulled.folder.path)?.allObjects as? [String] ?? []
        XCTAssertFalse(leftovers.contains { $0.hasSuffix(".part") })
    }

    func testResumesFromPartialFileWithRange() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (transport, source, puller) = makeIFlyCopy(host: host, game: game)
        let track = game.files["ROMs/Ikaruga/track02.bin", default: Data()]
        // A previous attempt left half of track02 behind.
        let folder = puller.folder(for: item(), from: .iFly)
        let destination = try XCTUnwrap(LibraryStaging.containedURL(for: "ROMs/Ikaruga/track02.bin", in: folder))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try track.prefix(8_000).write(to: destination.appendingPathExtension("part"))

        let pulled = try await puller.pull(item(), from: source) { _ in }

        let trackRequest = try XCTUnwrap(transport.requests(to: TestPaths.file).first { $0.queryValue("path") == "ROMs/Ikaruga/track02.bin" })
        XCTAssertEqual(trackRequest.headers["Range"], "bytes=8000-")
        XCTAssertEqual(try Data(contentsOf: pulled.gameFiles[1]), track)
    }

    func testRangeIgnoredByServerRestartsFromZero() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        host.ignoresRange = true
        let (_, source, puller) = makeIFlyCopy(host: host, game: game)
        let folder = puller.folder(for: item(), from: .iFly)
        let destination = try XCTUnwrap(LibraryStaging.containedURL(for: "ROMs/Ikaruga/track02.bin", in: folder))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Wrong bytes in the partial: appending would corrupt the file.
        try Data(repeating: 0xFF, count: 8_000).write(to: destination.appendingPathExtension("part"))

        let pulled = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.gameFiles[1]), game.files["ROMs/Ikaruga/track02.bin"])
    }

    func testUnsatisfiableRangeStartsTheFileOver() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (_, source, puller) = makeIFlyCopy(host: host, game: game)
        host.interruptions = [416]
        let pulled = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), game.files["ROMs/Ikaruga/Ikaruga.gdi"])
    }

    func testShortBodyResumesWhereItStopped() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (transport, source, puller) = makeIFlyCopy(host: host, game: game)
        host.truncateNextTo = 10 // the gdi (smallest) drops after 10 bytes
        let pulled = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(try Data(contentsOf: pulled.primaryFile), game.files["ROMs/Ikaruga/Ikaruga.gdi"])
        let gdiRequests = transport.requests(to: TestPaths.file).filter { $0.queryValue("path") == "ROMs/Ikaruga/Ikaruga.gdi" }
        XCTAssertEqual(gdiRequests.map { $0.headers["Range"] }, [nil, "bytes=10-"])
    }

    func testTamperedByteFailsAndDeletesThePartialFile() async throws {
        var game = GameSet.make()
        var files = game.files
        var tampered = files["ROMs/Ikaruga/track01.bin", default: Data()]
        tampered[100] ^= 0x01
        files["ROMs/Ikaruga/track01.bin"] = tampered
        game = GameSet(files: files, wire: game.wire)
        let host = FileHost(files: files)
        let (_, source, puller) = makeIFlyCopy(host: host, game: game)

        do {
            _ = try await puller.pull(item(), from: source) { _ in }
            XCTFail("expected a checksum failure")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .checksumMismatch("track01.bin"))
        }
        let folder = puller.folder(for: item(), from: .iFly)
        let destination = try XCTUnwrap(LibraryStaging.containedURL(for: "ROMs/Ikaruga/track01.bin", in: folder))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathExtension("part").path))
    }

    func testTraversalPathIsRefusedBeforeAnyDownload() async throws {
        let transport = MockTransport()
        let source = iFlySource(transport)
        let wire = """
        {"version":1,"files":[{"kind":"gameFile","relativePath":"../../Documents/evil.gdi","sha256":"00","size":1,"required":true}],"bios":[]}
        """
        transport.script(TestPaths.iFlyPull, LibraryHTTPResponse(status: 200, body: Data(wire.utf8)))
        let puller = LibraryPuller(staging: LibraryStaging(root: stagingRoot), peerKey: "p")
        do {
            _ = try await puller.pull(item(), from: source) { _ in }
            XCTFail("expected unsafePath")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .unsafePath("../../Documents/evil.gdi"))
        }
        XCTAssertTrue(transport.requests(to: TestPaths.file).isEmpty)
    }

    func testNoGameFilesIsNothingToCopy() async {
        let transport = MockTransport()
        let source = iFlySource(transport)
        let wire = #"{"version":1,"files":[],"bios":[{"kind":"bios","relativePath":"BIOS/a.bin","sha256":"00","size":1,"required":true}]}"#
        transport.script(TestPaths.iFlyPull, LibraryHTTPResponse(status: 200, body: Data(wire.utf8)))
        let puller = LibraryPuller(staging: LibraryStaging(root: stagingRoot), peerKey: "p")
        do {
            _ = try await puller.pull(item(), from: source) { _ in }
            XCTFail("expected nothingToCopy")
        } catch {
            XCTAssertEqual(error as? LibrarySharingError, .nothingToCopy)
        }
    }

    /// iFly's pull is metered: a resumed copy reuses the cached manifest.
    func testResumeReusesCachedManifestWithoutAnotherPull() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (transport, source, puller) = makeIFlyCopy(host: host, game: game)
        // First attempt dies on the second file with a server error.
        host.interruptions = []
        transport.handle(TestPaths.file) { request in
            request.queryValue("path") == "ROMs/Ikaruga/track01.bin" ? .status(500) : host.respond(request)
        }
        do {
            _ = try await puller.pull(item(), from: source) { _ in }
            XCTFail("expected the first attempt to fail")
        } catch {}

        transport.handle(TestPaths.file) { host.respond($0) }
        _ = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(transport.requests(to: TestPaths.iFlyPull).count, 1)
        // The gdi verified on the first attempt is not fetched again.
        let gdi = transport.requests(to: TestPaths.file).filter { $0.queryValue("path") == "ROMs/Ikaruga/Ikaruga.gdi" }
        XCTAssertEqual(gdi.count, 1)
    }

    /// A 404 on the file route means the host forgot the grant: pull again, once.
    func testFile404WithCachedManifestPullsAgainOnce() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (transport, source, puller) = makeIFlyCopy(host: host, game: game)
        let folder = puller.folder(for: item(), from: .iFly)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try LibraryPuller.cache(
            try JSONDecoder().decode(ContinuityPullManifest.self, from: game.iFlyJSON()).remoteManifest(itemId: item().id),
            in: folder
        )
        host.interruptions = [404]

        _ = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(transport.requests(to: TestPaths.iFlyPull).count, 1)
    }

    func testFile401ReauthenticatesAndResumes() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (transport, source, puller) = makeIFlyCopy(host: host, game: game)
        host.interruptions = [401]
        _ = try await puller.pull(item(), from: source) { _ in }
        XCTAssertEqual(transport.requests(to: TestPaths.authStart).count, 2)
    }

    func testProgressReportsBytesAndVerification() async throws {
        let game = GameSet.make()
        let host = FileHost(files: game.files)
        let (_, source, puller) = makeIFlyCopy(host: host, game: game)
        let log = PullProgressLog()
        _ = try await puller.pull(item(), from: source) { log.append($0) }
        let total = Int64(game.files.filter { $0.key.hasPrefix("ROMs/") }.values.reduce(0) { $0 + $1.count })
        XCTAssertTrue(log.values.contains(.verifying(file: "track02.bin")))
        guard case let .downloading(_, _, count, done, totalBytes)? = log.values.last(where: {
            if case .downloading = $0 { return true }
            return false
        }) else { return XCTFail("no download progress") }
        XCTAssertEqual(count, 3)
        XCTAssertEqual(totalBytes, total)
        XCTAssertEqual(done, total)
    }

}

/// Staging layout, cleanup and the download sink.
final class StagingTests: XCTestCase {
    private var stagingRoot: URL!

    override func setUpWithError() throws {
        stagingRoot = try makeTemporaryFolder()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: stagingRoot)
    }

    func testContainedURLRejectsEscapes() {
        let folder = URL(fileURLWithPath: "/tmp/stage/x")
        XCTAssertNotNil(LibraryStaging.containedURL(for: "ROMs/a b/c.gdi", in: folder))
        for bad in ["", "/etc/passwd", "../x", "a/../../x", "a//b", "./a", "a\\b", "a/."] {
            XCTAssertNil(LibraryStaging.containedURL(for: bad, in: folder), bad)
        }
    }

    func testFolderNamesAreHashedPerPeerAndItem() {
        let staging = LibraryStaging(root: stagingRoot)
        let one = staging.folder(peerKey: "ifly:a", app: .iFly, itemId: "Title/With:Slashes|Naomi|1")
        XCTAssertEqual(one.deletingLastPathComponent().standardizedFileURL, stagingRoot.standardizedFileURL)
        XCTAssertTrue(one.lastPathComponent.hasPrefix("ifly-"))
        XCTAssertNotEqual(one, staging.folder(peerKey: "ifly:b", app: .iFly, itemId: "Title/With:Slashes|Naomi|1"))
        XCTAssertEqual(one, staging.folder(peerKey: "ifly:a", app: .iFly, itemId: "Title/With:Slashes|Naomi|1"))
    }

    func testSweepRemovesHandedOffAndAbandonedFolders() throws {
        let staging = LibraryStaging(root: stagingRoot)
        let manager = FileManager.default
        func folder(_ name: String, withFile: Bool) throws -> URL {
            let url = stagingRoot.appendingPathComponent(name)
            try manager.createDirectory(at: url.appendingPathComponent("files"), withIntermediateDirectories: true)
            if withFile { try Data([1]).write(to: url.appendingPathComponent("files/game.iso")) }
            return url
        }
        let emptied = try folder("emptied", withFile: false)
        staging.markHandedOff(emptied)
        let skippedDuplicate = try folder("skipped", withFile: true)
        staging.markHandedOff(skippedDuplicate)
        let inProgress = try folder("progress", withFile: true)

        staging.sweep()
        XCTAssertFalse(manager.fileExists(atPath: emptied.path))
        XCTAssertTrue(manager.fileExists(atPath: skippedDuplicate.path))
        XCTAssertTrue(manager.fileExists(atPath: inProgress.path))

        staging.sweep(now: Date().addingTimeInterval(LibraryStaging.defaultAbandonedAge + 60))
        XCTAssertFalse(manager.fileExists(atPath: skippedDuplicate.path))
        XCTAssertFalse(manager.fileExists(atPath: inProgress.path))
    }

    // MARK: - DownloadSink

    func testSinkWritesNothingForAWrongRange() throws {
        let file = stagingRoot.appendingPathComponent("x.part")
        try Data([1, 2, 3]).write(to: file)
        var sink = DownloadSink(file: file, resumeOffset: 3)
        try sink.begin(status: 206, headers: ["content-range": "bytes 0-9/10"])
        try sink.append(Data(repeating: 9, count: 10))
        let result = try sink.finish()
        XCTAssertNil(result.writtenFrom)
        XCTAssertEqual(try Data(contentsOf: file), Data([1, 2, 3]))
    }

    func testContentRangeStartParses() {
        XCTAssertEqual(DownloadSink.contentRangeStart("bytes 100-199/200"), 100)
        XCTAssertNil(DownloadSink.contentRangeStart("bytes */200"))
        XCTAssertNil(DownloadSink.contentRangeStart(nil))
    }
}

final class PullProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [LibraryPullProgress] = []

    func append(_ value: LibraryPullProgress) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(value)
    }

    var values: [LibraryPullProgress] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
