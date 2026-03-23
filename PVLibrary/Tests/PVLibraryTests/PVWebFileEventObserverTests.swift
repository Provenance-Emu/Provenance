//
//  PVWebFileEventObserverTests.swift
//  PVLibraryTests
//
//  Tests for PVWebFileEventObserver — the bridge between web-server
//  file-lifecycle notifications and Realm library state.
//

import XCTest
import RealmSwift
import PVPrimitives
@testable import PVLibrary
@testable import PVRealm

final class PVWebFileEventObserverTests: XCTestCase {

    // Use a fresh in-memory Realm for every test.
    private var realmConfig: Realm.Configuration!
    private var observer: PVWebFileEventObserver!
    // Temp-directory prefixes injected into the observer so tests can classify
    // paths without iCloud-blocking Paths.* calls.
    private var romsPrefix: String!
    private var savesPrefix: String!
    private var biosPrefix: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        realmConfig = Realm.Configuration(
            inMemoryIdentifier: "PVWebFileEventObserverTests-\(UUID().uuidString)",
            objectTypes: [PVGame.self, PVSaveState.self, PVBIOS.self,
                          PVSystem.self, PVCore.self, PVFile.self,
                          PVImageFile.self, PVRecentGame.self, PVCheats.self]
        )

        let tmp = NSTemporaryDirectory() + "PVWebFileEventObserverTests-\(UUID().uuidString)/"
        romsPrefix  = tmp + "ROMs/"
        savesPrefix = tmp + "SaveStates/"
        biosPrefix  = tmp + "BIOS/"

        observer = PVWebFileEventObserver()
        observer.realmConfiguration = realmConfig
        observer._testRomsPathPrefix  = romsPrefix
        observer._testSavesPathPrefix = savesPrefix
        observer._testBiosPathPrefix  = biosPrefix
    }

    override func tearDownWithError() throws {
        observer.stop()
        observer = nil
        realmConfig = nil
        try super.tearDownWithError()
    }

    // MARK: - Lifecycle

    func testStartRegistersObservers() {
        // Starting an observer should not crash and should enable notification delivery.
        observer.start()
        // Double-start must be a no-op (no assertion here — just ensure no crash).
        observer.start()
    }

    func testStopUnregistersObservers() {
        // Use an inverted expectation: if the handler fires after stop(), the test fails.
        // This verifies that NotificationCenter tokens are actually removed by stop(),
        // not just that "no crash" occurs (which would pass even with a still-active observer).
        let handlerMustNotFire = expectation(description: "delete handler must NOT fire after stop")
        handlerMustNotFire.isInverted = true

        observer.start()
        observer._testOnDeleteHandlerInvoked = { _ in handlerMustNotFire.fulfill() }
        observer.stop()

        // After stop(), the NotificationCenter token has been removed.
        // Posting the notification now must not invoke the handler.
        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileDeleted,
            object: nil,
            userInfo: ["filePath": "/some/nonexistent/path.rom"]
        )
        // Give any (erroneously still-registered) async handler time to fire.
        wait(for: [handlerMustNotFire], timeout: 0.5)
    }

    // MARK: - CloudKit record-presence logic

    /// The observer treats a nil cloudRecordID as "no remote copy" (triggers hard-delete).
    /// An empty-string cloudRecordID must be treated the same way — not as a valid record.
    func testCloudRecordIDEmptyStringTreatedAsAbsent() {
        let nilResult    = hasCloudRecord(cloudRecordID: nil)
        let emptyResult  = hasCloudRecord(cloudRecordID: "")
        let validResult  = hasCloudRecord(cloudRecordID: "record-abc-123")

        XCTAssertFalse(nilResult,   "nil cloudRecordID should be treated as absent")
        XCTAssertFalse(emptyResult, "empty-string cloudRecordID should be treated as absent")
        XCTAssertTrue(validResult,  "non-empty cloudRecordID should be treated as present")
    }

    // MARK: - ROM delete — CloudKit soft-offline path

    /// When a ROM file is deleted and the matching PVGame has a CloudKit record,
    /// the observer marks the game as offline (`isDownloaded = false`, `requiresSync = true`)
    /// rather than deleting the Realm record.
    func testDeleteROMWithCloudRecordMarksSoftOffline() throws {
        let realm = try Realm(configuration: realmConfig)

        let game = PVGame()
        game.title = "Super Mario World"
        game.romPath = "SNES/mario.sfc"
        game.cloudRecordID = "ckrecord-001"
        game.isDownloaded = true
        game.requiresSync = false

        try realm.write { realm.add(game) }

        observer.start()

        let exp = expectation(description: "delete handler completes background work")
        // _testOnDeleteHandlerInvoked fires at the *start* of the handler, before
        // the async dispatch.  Give the background queue time to finish its Realm write.
        observer._testOnDeleteHandlerInvoked = { _ in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                exp.fulfill()
            }
        }

        let deletedPath = romsPrefix + "SNES/mario.sfc"
        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileDeleted,
            object: nil,
            userInfo: ["filePath": deletedPath]
        )

        wait(for: [exp], timeout: 2)

        let freshRealm = try Realm(configuration: realmConfig)
        let found = freshRealm.objects(PVGame.self)
            .filter("romPath == %@", "SNES/mario.sfc")
            .first
        XCTAssertNotNil(found, "Game should still exist in Realm (soft-offline, not hard-deleted)")
        XCTAssertFalse(found?.isDownloaded ?? true, "isDownloaded should be set to false")
        XCTAssertTrue(found?.requiresSync ?? false, "requiresSync should be set to true")
        XCTAssertNil(found?.lastCloudSyncDate, "lastCloudSyncDate should be cleared")
    }

    /// When a ROM file is deleted and the matching PVGame has NO CloudKit record,
    /// the observer hard-deletes the game from Realm.
    func testDeleteROMWithoutCloudRecordHardDeletes() throws {
        let realm = try Realm(configuration: realmConfig)

        let game = PVGame()
        game.title = "Donkey Kong"
        game.romPath = "NES/donkeykong.nes"
        game.cloudRecordID = nil
        game.isDownloaded = true

        try realm.write { realm.add(game) }

        observer.start()

        let exp = expectation(description: "delete handler completes background work")
        observer._testOnDeleteHandlerInvoked = { _ in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                exp.fulfill()
            }
        }

        let deletedPath = romsPrefix + "NES/donkeykong.nes"
        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileDeleted,
            object: nil,
            userInfo: ["filePath": deletedPath]
        )

        wait(for: [exp], timeout: 2)

        let freshRealm = try Realm(configuration: realmConfig)
        let found = freshRealm.objects(PVGame.self)
            .filter("romPath == %@", "NES/donkeykong.nes")
            .first
        XCTAssertNil(found, "Game should be hard-deleted from Realm (no CloudKit record)")
    }

    /// An empty-string cloudRecordID is treated the same as nil —
    /// the game should be hard-deleted, not soft-offlined.
    func testDeleteROMWithEmptyCloudRecordIDHardDeletes() throws {
        let realm = try Realm(configuration: realmConfig)

        let game = PVGame()
        game.title = "Pac-Man"
        game.romPath = "Arcade/pacman.rom"
        game.cloudRecordID = "" // empty string — treated as "no record"
        game.isDownloaded = true

        try realm.write { realm.add(game) }

        observer.start()

        let exp = expectation(description: "delete handler completes")
        observer._testOnDeleteHandlerInvoked = { _ in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        }

        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileDeleted,
            object: nil,
            userInfo: ["filePath": romsPrefix + "Arcade/pacman.rom"]
        )

        wait(for: [exp], timeout: 2)

        let freshRealm = try Realm(configuration: realmConfig)
        XCTAssertNil(freshRealm.objects(PVGame.self).filter("romPath == %@", "Arcade/pacman.rom").first,
                     "Game with empty cloudRecordID should be hard-deleted")
    }

    // MARK: - ROM move path

    /// When a ROM file is moved/renamed, the observer updates `romPath` and
    /// `file.partialPath` in Realm to the new relative path.
    func testMoveROMUpdatesRomPath() throws {
        let realm = try Realm(configuration: realmConfig)

        let oldRelative = "SNES/castlevania.sfc"
        let newRelative = "SNES/Castlevania.sfc"

        let game = PVGame()
        game.title = "Castlevania"
        game.romPath = oldRelative

        try realm.write { realm.add(game) }

        observer.start()

        let exp = expectation(description: "move handler completes background work")
        observer._testOnMoveHandlerInvoked = { _, _ in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        }

        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileMoved,
            object: nil,
            userInfo: [
                "fromPath": romsPrefix + oldRelative,
                "toPath":   romsPrefix + newRelative
            ]
        )

        wait(for: [exp], timeout: 2)

        let freshRealm = try Realm(configuration: realmConfig)
        XCTAssertNil(freshRealm.objects(PVGame.self).filter("romPath == %@", oldRelative).first,
                     "Old romPath should no longer exist in Realm")
        XCTAssertNotNil(freshRealm.objects(PVGame.self).filter("romPath == %@", newRelative).first,
                        "Game should be found under the new romPath")
    }

    // MARK: - No-op / edge cases

    /// Posting a delete notification when no game matches the path should be a no-op.
    func testDeleteUnknownPathIsNoop() throws {
        observer.start()

        let exp = XCTestExpectation(description: "no-op completes")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }

        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileDeleted,
            object: nil,
            userInfo: ["filePath": "/some/nonexistent/rom.sfc"]
        )
        wait(for: [exp], timeout: 1)
    }

    /// Posting a move notification when no game matches the source path should be a no-op.
    func testMoveUnknownPathIsNoop() throws {
        observer.start()

        let exp = XCTestExpectation(description: "no-op completes")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }

        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileMoved,
            object: nil,
            userInfo: ["fromPath": "/some/old.sfc", "toPath": "/some/new.sfc"]
        )
        wait(for: [exp], timeout: 1)
    }

    /// Missing or malformed userInfo keys must not crash the observer.
    func testMalformedDeleteNotificationDoesNotCrash() {
        observer.start()
        // Missing "filePath" key
        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileDeleted,
            object: nil,
            userInfo: [:]
        )
        // No assertion needed — verifying the app doesn't crash is the test.
    }

    func testMalformedMoveNotificationDoesNotCrash() {
        observer.start()
        // Missing "toPath" key
        NotificationCenter.default.post(
            name: Notification.Name.pvWebServerFileMoved,
            object: nil,
            userInfo: ["fromPath": "/some/old.rom"]
        )
    }
}

// MARK: - Helpers

/// Mirrors the CloudKit-presence logic used inside PVWebFileEventObserver.handleFileDeleted.
private func hasCloudRecord(cloudRecordID: String?) -> Bool {
    !(cloudRecordID?.isEmpty ?? true)
}
