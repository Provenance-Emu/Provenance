//
//  RetiredCoreMigrationTests.swift
//  PVLibraryTests
//
//  Save states, recents and core preferences on a retired core must move to its
//  replacement, and the retired core must end up disabled.
//

import XCTest
import RealmSwift
import PVRealm
@testable import PVLibrary

final class RetiredCoreMigrationTests: XCTestCase {

    private let retiredID = "com.example.core.retired"
    private let replacementID = "replacement.libretro.framework"
    private let otherID = "com.example.core.other"

    private var realm: Realm!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        try realm.write {
            for (identifier, version) in [(retiredID, "2.1.2"), (replacementID, "3.6.1"), (otherID, "1.0")] {
                let core = PVCore()
                core.identifier = identifier
                core.projectVersion = version
                realm.add(core)
            }
        }
    }

    private func core(_ identifier: String) -> PVCore {
        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: identifier) else {
            fatalError("test core \(identifier) missing")
        }
        return core
    }

    private func addState(core identifier: String, version: String) throws -> PVSaveState {
        let state = PVSaveState()
        state.core = core(identifier)
        state.createdWithCoreVersion = version
        try realm.write { realm.add(state) }
        return state
    }

    private func migrate() throws -> RetiredCoreMigration.Result {
        var result = RetiredCoreMigration.Result()
        try realm.write {
            result = RetiredCoreMigration.migrate(in: realm, replacements: [retiredID: replacementID])
        }
        return result
    }

    func testMovesSaveStatesAndAdoptsReplacementVersion() throws {
        let retiredState = try addState(core: retiredID, version: "2.1.2")
        let otherState = try addState(core: otherID, version: "1.0")

        let result = try migrate()

        XCTAssertEqual(result.saveStates, 1)
        XCTAssertEqual(retiredState.core.identifier, replacementID)
        XCTAssertEqual(retiredState.createdWithCoreVersion, "3.6.1")
        XCTAssertEqual(otherState.core.identifier, otherID)
        XCTAssertEqual(otherState.createdWithCoreVersion, "1.0")
    }

    func testMovesRecentsAndPreferences() throws {
        let recent = PVRecentGame()
        recent.core = core(retiredID)
        let game = PVGame()
        game.md5Hash = "abc"
        game.userPreferredCoreID = retiredID
        let system = PVSystem()
        system.identifier = "com.provenance.jaguar"
        system.userPreferredCoreID = retiredID
        try realm.write { realm.add([recent, game, system] as [Object]) }

        let result = try migrate()

        XCTAssertEqual(result, .init(saveStates: 0, recentGames: 1, gamePreferences: 1, systemPreferences: 1))
        XCTAssertEqual(recent.core?.identifier, replacementID)
        XCTAssertEqual(game.userPreferredCoreID, replacementID)
        XCTAssertEqual(system.userPreferredCoreID, replacementID)
    }

    func testDisablesRetiredCore() throws {
        _ = try migrate()
        XCTAssertTrue(core(retiredID).disabled)
        XCTAssertFalse(core(replacementID).disabled)
    }

    func testSecondRunIsANoOp() throws {
        _ = try addState(core: retiredID, version: "2.1.2")
        _ = try migrate()
        XCTAssertEqual(try migrate(), RetiredCoreMigration.Result())
    }

    func testLeavesRecordsAloneWhileReplacementIsMissing() throws {
        let state = try addState(core: retiredID, version: "2.1.2")
        try realm.write { realm.delete(core(replacementID)) }

        let result = try migrate()

        XCTAssertEqual(result, RetiredCoreMigration.Result())
        XCTAssertEqual(state.core.identifier, retiredID)
        XCTAssertFalse(core(retiredID).disabled)
    }

    func testRetirementWaitsForTheReplacementToBeBundled() {
        XCTAssertEqual(PVCore.retiredCoreReplacements["com.provenance.core.jaguar"], "virtualjaguar.libretro.framework")
        // The test runner bundles no libretro cores, like a Lite build: Jaguar
        // stays on its native core and incoming records keep their identifier.
        XCTAssertFalse(PVCore.isBundledLibretroCore("virtualjaguar.libretro.framework"))
        XCTAssertNil(PVCore.activeRetiredCoreReplacements["com.provenance.core.jaguar"])
        XCTAssertEqual(PVCore.currentIdentifier(for: "com.provenance.core.jaguar"), "com.provenance.core.jaguar")
    }
}
