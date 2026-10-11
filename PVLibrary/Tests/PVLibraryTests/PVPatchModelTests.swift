//
//  PVPatchModelTests.swift
//  PVLibraryTests
//

import XCTest
import RealmSwift
import PVPatching
@testable import PVLibrary
import PVRealm

final class PVPatchModelTests: XCTestCase {
    private var previousConfig: Realm.Configuration!
    private var realm: Realm!

    override func setUpWithError() throws {
        previousConfig = Realm.Configuration.defaultConfiguration
        let config = Realm.Configuration(
            inMemoryIdentifier: "PVPatchModelTests-\(UUID().uuidString)"
        )
        Realm.Configuration.defaultConfiguration = config
        realm = try Realm(configuration: config)
    }

    override func tearDownWithError() throws {
        realm = nil
        Realm.Configuration.defaultConfiguration = previousConfig
    }

    func testPatchPrimaryKeyIsIdempotentAcrossReimport() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVPatchIdem-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let patchURL = dir.appendingPathComponent("hack.bps")
        try Data("BPS1".utf8).write(to: patchURL)

        let file1 = PVFile(withURL: patchURL)
        let patch1 = PVPatch(file: file1, format: .bps, title: "Hack")
        try realm.write { realm.add(patch1, update: .modified) }

        let file2 = PVFile(withURL: patchURL)
        let patch2 = PVPatch(file: file2, format: .bps, title: "Hack Again")
        XCTAssertEqual(patch1.id, patch2.id)

        try realm.write { realm.add(patch2, update: .modified) }
        XCTAssertEqual(realm.objects(PVPatch.self).count, 1)
    }

    func testVariantFlagsDefaultHidden() throws {
        let game = PVGame()
        game.md5Hash = "ABCDEF"
        game.title = "Base"
        game.systemIdentifier = "SNES"
        game.isPatchVariant = true
        game.isHiddenPatchVariant = true
        game.baseGameMD5 = "BASEMD5"
        game.patchID = "patches/hack.bps"

        try realm.write { realm.add(game) }

        let fetched = realm.object(ofType: PVGame.self, forPrimaryKey: "ABCDEF")
        XCTAssertEqual(fetched?.isPatchVariant, true)
        XCTAssertEqual(fetched?.isHiddenPatchVariant, true)
        XCTAssertEqual(fetched?.baseGameMD5, "BASEMD5")

        let visible = realm.objects(PVGame.self).filter("isHiddenPatchVariant == false")
        XCTAssertEqual(visible.count, 0)
    }

    func testMatchStateDefaultsPendingWithoutGame() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVPatchPending-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("p.ips")
        try? Data([0]).write(to: url)

        let patch = PVPatch(file: PVFile(withURL: url), format: .ips, title: "P")
        XCTAssertEqual(patch.matchState, .pending)
        XCTAssertEqual(patch.isDefaultLaunch, false)
        XCTAssertEqual(patch.showAsLibraryTile, false)
    }

    func testDeletePatchSkipsStandaloneLinkedGame() {
        XCTAssertFalse(PatchRepository.shouldDeleteVariantGame(isPatchVariant: nil))
        XCTAssertFalse(PatchRepository.shouldDeleteVariantGame(isPatchVariant: false))
        XCTAssertTrue(PatchRepository.shouldDeleteVariantGame(isPatchVariant: true))
    }
}
