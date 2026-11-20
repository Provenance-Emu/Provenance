import XCTest
import PVSystems
@testable import PVLibrarySharing

private typealias Matcher = MissingGameMatcher

final class MissingGameMatcherTests: XCTestCase {
    private let md5 = "0123456789ABCDEF0123456789ABCDEF"

    private func query(
        system: SystemIdentifier = .N64,
        title: String = "Mario Kart 64 (USA)",
        files: [MissingGameFile] = [MissingGameFile(name: "Mario Kart 64 (USA).z64", size: 100, isPrimary: true)],
        single: Bool = true
    ) -> MissingGameQuery {
        MissingGameQuery(md5: md5, system: system, title: title, files: files, isSingleFileImage: single)
    }

    private func item(
        _ id: String = "1", title: String = "Mario Kart 64 (USA)", system: SystemIdentifier? = .N64,
        md5: String? = nil, size: Int64 = 100
    ) -> RemoteLibraryItem {
        RemoteLibraryItem(
            id: id, title: title, platform: "n64", systemIdentifier: system, md5: md5, sizeBytes: size,
            artKey: nil, source: .pvLibrary
        )
    }

    private func catalogue(_ items: [RemoteLibraryItem]) -> RemoteCatalogue {
        RemoteCatalogue(deviceName: "Mac", items: items, source: .pvLibrary)
    }

    private func manifest(_ files: [(String, Int64)]) -> RemoteManifest {
        RemoteManifest(itemId: "1", files: files.map {
            RemoteFile(kind: RemoteFile.gameFileKind, relativePath: $0.0, sha256: "aa", size: $0.1)
        })
    }

    // MARK: Hash

    func testHashMatchIsCaseInsensitive() {
        let found = Matcher.hashMatches(for: query(), in: catalogue([item(md5: md5.lowercased())]))
        XCTAssertEqual(found.map(\.id), ["1"])
    }

    func testHashMatchRejectsDifferentSize() {
        XCTAssertTrue(Matcher.hashMatches(for: query(), in: catalogue([item(md5: md5, size: 200)])).isEmpty)
    }

    func testHashMatchAcceptsUnknownRemoteSize() {
        XCTAssertEqual(Matcher.hashMatches(for: query(), in: catalogue([item(md5: md5, size: 0)])).count, 1)
    }

    func testHashMatchSkipsMultiFileGames() {
        XCTAssertTrue(Matcher.hashMatches(for: query(single: false), in: catalogue([item(md5: md5)])).isEmpty)
    }

    func testHashMatchNeverCrossesSystems() {
        XCTAssertTrue(Matcher.hashMatches(for: query(), in: catalogue([item(system: .SNES, md5: md5)])).isEmpty)
        XCTAssertTrue(Matcher.hashMatches(for: query(), in: catalogue([item(system: nil, md5: md5)])).isEmpty)
    }

    // MARK: Name

    func testNameCandidatesNormalise() {
        let remote = catalogue([item(title: "mario kart 64 (usa)")])
        let found = Matcher.nameCandidates(for: query(title: "Some Other Title"), in: remote)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(Matcher.normalised("Mario Kart 64 (USA).z64"), "mariokart64usa")
        XCTAssertEqual(Matcher.normalised("Pokémon - Red.gb"), "pokemonred")
    }

    func testNameCandidatesAreNeverFuzzy() {
        let items = [
            item("1", title: "Mario Kart 64 (Europe)"), item("2", title: "Mario Kart 64"),
            item("3", title: "Mario Kart 64 (USA) (Rev 1)")
        ]
        XCTAssertTrue(Matcher.nameCandidates(for: query(), in: catalogue(items)).isEmpty)
    }

    func testNameCandidatesNeverCrossSystems() {
        XCTAssertTrue(Matcher.nameCandidates(for: query(), in: catalogue([item(system: .SNES)])).isEmpty)
    }

    func testNameCandidatesPreferEqualSize() {
        let items = [item("other", size: 999), item("same", size: 100)]
        XCTAssertEqual(Matcher.nameCandidates(for: query(), in: catalogue(items)).map(\.id), ["same", "other"])
    }

    func testEmptyNamesNeverMatch() {
        let empty = query(title: "()", files: [MissingGameFile(name: ".z64", size: 1, isPrimary: true)])
        XCTAssertTrue(Matcher.nameCandidates(for: empty, in: catalogue([item(title: "--")])).isEmpty)
    }

    // MARK: Manifest

    private var cueSet: [MissingGameFile] {
        [MissingGameFile(name: "Game.cue", size: 90, isPrimary: true),
         MissingGameFile(name: "Game (Track 1).bin", size: 5000, isPrimary: false),
         MissingGameFile(name: "Game (Track 2).bin", size: 7000, isPrimary: false)]
    }

    func testClassifyExactForCueBinSet() {
        let remote = manifest([
            ("disc/game.cue", 90), ("disc/Game (Track 1).bin", 5000), ("disc/Game (Track 2).bin", 7000)
        ])
        XCTAssertEqual(Matcher.classify(remote, for: query(files: cueSet, single: false)), .exact)
    }

    func testClassifyStandInWhenSizeDiffers() {
        let remote = manifest([("Game.cue", 90), ("Game (Track 1).bin", 5001), ("Game (Track 2).bin", 7000)])
        XCTAssertEqual(Matcher.classify(remote, for: query(files: cueSet, single: false)), .standIn)
    }

    func testClassifyStandInWhenLocalSizeUnknown() {
        let unknown = [MissingGameFile(name: "Mario Kart 64 (USA).z64", size: 0, isPrimary: true)]
        let remote = manifest([("Mario Kart 64 (USA).z64", 100)])
        XCTAssertEqual(Matcher.classify(remote, for: query(files: unknown)), .standIn)
    }

    func testClassifyStandInForDifferentExtension() {
        XCTAssertEqual(Matcher.classify(manifest([("Mario Kart 64 (USA).n64", 100)]), for: query()), .standIn)
    }

    func testClassifyNilForDifferentFileNamesInSet() {
        let remote = manifest([("Game.cue", 90), ("Game (Track 01).bin", 5000), ("Game (Track 02).bin", 7000)])
        XCTAssertNil(Matcher.classify(remote, for: query(files: cueSet, single: false)))
    }

    func testClassifyExactWhenOnlyThePrimarySizeIsKnown() {
        let files = [MissingGameFile(name: "Game.cue", size: 90, isPrimary: true),
                     MissingGameFile(name: "Game (Track 1).bin", size: 0, isPrimary: false)]
        let remote = manifest([("Game.cue", 90), ("Game (Track 1).bin", 5000)])
        XCTAssertEqual(Matcher.classify(remote, for: query(files: files, single: false)), .exact)
        let other = manifest([("Game.cue", 91), ("Game (Track 1).bin", 5000)])
        XCTAssertEqual(Matcher.classify(other, for: query(files: files, single: false)), .standIn)
    }

    func testClassifyNilForEmptyManifest() {
        XCTAssertNil(Matcher.classify(manifest([]), for: query()))
    }
}
