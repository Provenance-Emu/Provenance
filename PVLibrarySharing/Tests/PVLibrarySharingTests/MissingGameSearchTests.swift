import XCTest
import PVSystems
@testable import PVLibrarySharing

private actor FakeSource: LibrarySource {
    nonisolated let app: PeerApp = .pvLibrary
    var items: [RemoteLibraryItem]
    var manifests: [String: RemoteManifest] = [:]
    var delay: Duration = .zero
    var fails = false
    private(set) var catalogueCalls = 0
    private(set) var manifestCalls = 0
    private let log: CallLog?
    private let name: String

    init(_ name: String, items: [RemoteLibraryItem] = [], log: CallLog? = nil) {
        self.name = name
        self.items = items
        self.log = log
    }

    func set(delay: Duration) { self.delay = delay }
    func setFails() { fails = true }
    func set(manifest: RemoteManifest, for id: String) { manifests[id] = manifest }

    func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        catalogueCalls += 1
        await log?.add(name)
        if delay > .zero { try await Task.sleep(for: delay) }
        if fails { throw LibrarySharingError.unreachable }
        return RemoteCatalogue(deviceName: name, items: items, source: app)
    }

    func artwork(for item: RemoteLibraryItem) async throws -> Data? { nil }

    func pullManifest(
        for item: RemoteLibraryItem, progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteManifest {
        manifestCalls += 1
        guard let manifest = manifests[item.id] else { throw LibrarySharingError.itemUnavailable }
        return manifest
    }

    func download(
        _ file: RemoteFile, of manifest: RemoteManifest, to partialFile: URL, resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse {
        throw LibrarySharingError.fileUnavailable(file.fileName)
    }
}

private actor CallLog {
    private(set) var names: [String] = []
    func add(_ name: String) { names.append(name) }
}

final class MissingGameSearchTests: XCTestCase {
    private let md5 = "0123456789abcdef0123456789abcdef"
    private let fileName = "Mario Kart 64 (USA).z64"

    private var query: MissingGameQuery {
        MissingGameQuery(
            md5: md5, system: .N64, title: "Mario Kart 64 (USA)",
            files: [MissingGameFile(name: fileName, size: 100, isPrimary: true)], isSingleFileImage: true
        )
    }

    private func item(_ id: String, title: String = "Mario Kart 64 (USA)", md5: String? = nil) -> RemoteLibraryItem {
        RemoteLibraryItem(
            id: id, title: title, platform: "n64", systemIdentifier: .N64, md5: md5, sizeBytes: 100,
            artKey: nil, source: .pvLibrary
        )
    }

    private func manifest(_ id: String, name: String, size: Int64) -> RemoteManifest {
        RemoteManifest(itemId: id, files: [
            RemoteFile(kind: RemoteFile.gameFileKind, relativePath: name, sha256: "aa", size: size)
        ])
    }

    private func entry(_ source: FakeSource, _ name: String, rank: Int = 1) -> SearchSource {
        SearchSource(source: source, name: name, identity: "id-" + name, rank: rank)
    }

    private func hint(_ identity: String, item: String, standIn: String?) -> GameSourceHint {
        GameSourceHint(app: .pvLibrary, sourceIdentity: identity, remoteItemID: item, files: [], standInMD5: standIn)
    }

    private func find(
        _ sources: [SearchSource], hint: GameSourceHint? = nil
    ) async -> (found: FoundGame?, report: SearchReport) {
        await MissingGameSearch().find(query, hint: hint, in: sources) { _ in }
    }

    /// A source holding a same-name game of another size: a stand-in.
    private func standInSource(_ name: String, log: CallLog? = nil) async -> FakeSource {
        let source = FakeSource(name, items: [item("s")], log: log)
        await source.set(manifest: manifest("s", name: fileName, size: 222), for: "s")
        return source
    }

    func testStopsAtFirstExactMatch() async {
        let first = FakeSource("A", items: [item("a", md5: md5)])
        let second = FakeSource("B", items: [item("b", md5: md5)])
        let result = await find([entry(first, "A"), entry(second, "B")])
        XCTAssertEqual(result.found?.item.id, "a")
        XCTAssertEqual(result.found?.kind, .exact)
        let untouched = await second.catalogueCalls
        XCTAssertEqual(untouched, 0)
        XCTAssertEqual(result.report, SearchReport(asked: ["A"], unreachable: []))
    }

    func testLowerRankIsAskedFirst() async {
        let log = CallLog()
        let server = FakeSource("Server", log: log)
        let local = FakeSource("Local", log: log)
        _ = await MissingGameSearch().find(
            query, hint: nil, in: [entry(server, "Server", rank: 2), entry(local, "Local", rank: 0)]
        ) { _ in }
        let order = await log.names
        XCTAssertEqual(order, ["Local", "Server"])
    }

    func testHintedSourceIsAskedFirst() async {
        let log = CallLog()
        let first = FakeSource("A", log: log)
        let second = FakeSource("B", log: log)
        let hint = hint("id-B", item: "x", standIn: nil)
        _ = await find([entry(first, "A", rank: 0), entry(second, "B", rank: 2)], hint: hint)
        let order = await log.names
        XCTAssertEqual(order, ["B", "A"])
    }

    func testHintItemIsExactWithoutNameMatch() async {
        let source = FakeSource("A", items: [item("remembered", title: "Something Else")])
        let hint = hint("id-A", item: "remembered", standIn: nil)
        let result = await find([entry(source, "A")], hint: hint)
        XCTAssertEqual(result.found?.item.id, "remembered")
        XCTAssertEqual(result.found?.kind, .exact)
    }

    func testHintForAStandInStillAsks() async {
        let source = await standInSource("A")
        let hint = hint("id-A", item: "s", standIn: "ffff")
        let result = await find([entry(source, "A")], hint: hint)
        XCTAssertEqual(result.found?.kind, .standIn)
    }

    func testFallsBackToStandInWhenNoExact() async {
        let first = await standInSource("A")
        let second = FakeSource("B")
        let result = await find([entry(first, "A"), entry(second, "B")])
        XCTAssertEqual(result.found?.kind, .standIn)
        XCTAssertEqual(result.found?.source.name, "A")
        XCTAssertNotNil(result.found?.manifest)
        XCTAssertEqual(result.report.asked, ["A", "B"])
    }

    func testExactLaterBeatsStandInEarlier() async {
        let first = await standInSource("A")
        let second = FakeSource("B", items: [item("b", md5: md5)])
        let result = await find([entry(first, "A"), entry(second, "B")])
        XCTAssertEqual(result.found?.source.name, "B")
        XCTAssertEqual(result.found?.kind, .exact)
    }

    func testSameNameAndSizeIsExact() async {
        let source = FakeSource("A", items: [item("a")])
        await source.set(manifest: manifest("a", name: fileName.uppercased(), size: 100), for: "a")
        let result = await find([entry(source, "A")])
        XCTAssertEqual(result.found?.kind, .exact)
    }

    func testHangingSourceIsDroppedAfterTimeout() async {
        let hanging = FakeSource("A", items: [item("a", md5: md5)])
        await hanging.set(delay: .seconds(5))
        let second = FakeSource("B", items: [item("b", md5: md5)])
        let started = ContinuousClock.now
        let result = await MissingGameSearch(catalogueTimeout: .milliseconds(200))
            .find(query, hint: nil, in: [entry(hanging, "A"), entry(second, "B")]) { _ in }
        XCTAssertEqual(result.found?.source.name, "B")
        XCTAssertEqual(result.report, SearchReport(asked: ["B"], unreachable: ["A"]))
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(3))
    }

    func testThrowingSourceIsUnreachable() async {
        let broken = FakeSource("A")
        await broken.setFails()
        let second = FakeSource("B")
        let result = await find([entry(broken, "A"), entry(second, "B")])
        XCTAssertNil(result.found)
        XCTAssertEqual(result.report, SearchReport(asked: ["B"], unreachable: ["A"]))
    }

    func testOneManifestPerSource() async {
        let source = FakeSource("A", items: [item("1"), item("2"), item("3")])
        _ = await find([entry(source, "A")])
        let calls = await source.manifestCalls
        XCTAssertEqual(calls, 1)
    }

    func testCataloguesAreCachedAcrossCalls() async {
        let source = FakeSource("A")
        let search = MissingGameSearch()
        _ = await search.find(query, hint: nil, in: [entry(source, "A")]) { _ in }
        _ = await search.find(query, hint: nil, in: [entry(source, "A")]) { _ in }
        let calls = await source.catalogueCalls
        XCTAssertEqual(calls, 1)
    }

    func testProgressNamesEachSource() async {
        let log = CallLog()
        let sources = [entry(FakeSource("A"), "A"), entry(FakeSource("B"), "B")]
        _ = await MissingGameSearch().find(query, hint: nil, in: sources) { name in Task { await log.add(name) } }
        try? await Task.sleep(for: .milliseconds(100))
        let names = await log.names
        XCTAssertEqual(Set(names), ["A", "B"])
    }
}
