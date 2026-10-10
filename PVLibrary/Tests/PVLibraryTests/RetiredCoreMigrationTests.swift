//
//  RetiredCoreMigrationTests.swift
//  PVLibraryTests
//
//  Records on a retired core move to its replacement (per system when the entry says so),
//  save states move only when the formats are compatible, and the retired core ends up
//  disabled but is never pruned.
//

import XCTest
import RealmSwift
import PVRealm
import PVSystems
@testable import PVLibrary

final class RetiredCoreMigrationTests: XCTestCase {

    private let retiredID = "com.example.core.retired"
    private let replacementID = "replacement.libretro.framework"
    private let colecoID = "coleco.libretro.framework"
    private let otherID = "com.example.core.other"

    private var realm: Realm!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        try realm.write {
            for (identifier, version) in [(retiredID, "2.1.2"), (replacementID, "3.6.1"), (colecoID, "1.2"), (otherID, "1.0")] {
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

    private func migrate(_ retired: RetiredCore? = nil) throws -> RetiredCoreMigration.Result {
        let entry = retired ?? RetiredCore(replacement: replacementID, migratesSaveStates: true)
        var result = RetiredCoreMigration.Result()
        try realm.write {
            result = RetiredCoreMigration.migrate(in: realm, retiredCores: [retiredID: entry])
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

    func testLeavesSaveStatesWhenFormatsDiffer() throws {
        let state = try addState(core: retiredID, version: "2.1.2")
        let game = PVGame()
        game.md5Hash = "def"
        game.userPreferredCoreID = retiredID
        try realm.write { realm.add(game) }

        let result = try migrate(RetiredCore(replacement: replacementID, migratesSaveStates: false))

        XCTAssertEqual(result.saveStates, 0)
        XCTAssertEqual(result.gamePreferences, 1)
        XCTAssertEqual(state.core.identifier, retiredID)
        XCTAssertEqual(game.userPreferredCoreID, replacementID)
    }

    func testMovesRecentsAndPreferences() throws {
        let recent = PVRecentGame()
        recent.core = core(retiredID)
        let game = PVGame()
        game.md5Hash = "abc"
        game.userPreferredCoreID = retiredID
        let system = PVSystem()
        system.identifier = SystemIdentifier.AtariJaguar.rawValue
        system.userPreferredCoreID = retiredID
        try realm.write { realm.add([recent, game, system] as [Object]) }

        let result = try migrate()

        XCTAssertEqual(result, .init(saveStates: 0, recentGames: 1, gamePreferences: 1, systemPreferences: 1))
        XCTAssertEqual(recent.core?.identifier, replacementID)
        XCTAssertEqual(game.userPreferredCoreID, replacementID)
        XCTAssertEqual(system.userPreferredCoreID, replacementID)
    }

    func testPicksReplacementPerSystem() throws {
        let coleco = PVGame()
        coleco.md5Hash = "c1"
        coleco.systemIdentifier = SystemIdentifier.ColecoVision.rawValue
        coleco.userPreferredCoreID = retiredID
        let sg1000 = PVGame()
        sg1000.md5Hash = "s1"
        sg1000.systemIdentifier = SystemIdentifier.SG1000.rawValue
        sg1000.userPreferredCoreID = retiredID
        let colecoSystem = PVSystem()
        colecoSystem.identifier = SystemIdentifier.ColecoVision.rawValue
        colecoSystem.userPreferredCoreID = retiredID
        try realm.write { realm.add([coleco, sg1000, colecoSystem] as [Object]) }

        _ = try migrate(RetiredCore(replacement: replacementID, systemReplacements: [.ColecoVision: colecoID]))

        XCTAssertEqual(coleco.userPreferredCoreID, colecoID)
        XCTAssertEqual(sg1000.userPreferredCoreID, replacementID)
        XCTAssertEqual(colecoSystem.userPreferredCoreID, colecoID)
    }

    func testWaitsForEveryReplacementToBeRegistered() throws {
        let state = try addState(core: retiredID, version: "2.1.2")
        try realm.write { realm.delete(core(colecoID)) }

        let result = try migrate(RetiredCore(replacement: replacementID, systemReplacements: [.ColecoVision: colecoID], migratesSaveStates: true))

        XCTAssertEqual(result, RetiredCoreMigration.Result())
        XCTAssertEqual(state.core.identifier, retiredID)
        XCTAssertFalse(core(retiredID).disabled)
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

    func testCurrentIdentifierOnlyRemapsCoresWhoseStatesMigrate() {
        let cores = [
            "a": RetiredCore(replacement: "a.libretro.framework", migratesSaveStates: true),
            "b": RetiredCore(replacement: "b.libretro.framework", migratesSaveStates: false),
        ]
        XCTAssertEqual(PVCore.currentIdentifier(for: "a", in: cores), "a.libretro.framework")
        XCTAssertEqual(PVCore.currentIdentifier(for: "b", in: cores), "b")
        XCTAssertEqual(PVCore.currentIdentifier(for: "c", in: cores), "c")
    }

    func testRetiredRowsAreNeverPruned() {
        XCTAssertFalse(PVEmulatorConfiguration.isStaleCore(RetiredCoreID.jaguar, validIdentifiers: []))
        XCTAssertTrue(PVEmulatorConfiguration.isStaleCore("com.example.phantom", validIdentifiers: []))
        XCTAssertFalse(PVEmulatorConfiguration.isStaleCore("com.example.phantom", validIdentifiers: ["com.example.phantom"]))
    }

    func testRetirementWaitsForTheReplacementToBeBundled() {
        XCTAssertEqual(PVCore.retiredCores[RetiredCoreID.jaguar]?.replacement, LibretroCoreID.virtualJaguar)
        // The test runner bundles no libretro cores, like a Lite build: Jaguar
        // stays on its native core and incoming records keep their identifier.
        XCTAssertFalse(PVCore.isBundledLibretroCore(LibretroCoreID.virtualJaguar))
        XCTAssertNil(PVCore.activeRetiredCoreReplacements[RetiredCoreID.jaguar])
        XCTAssertEqual(PVCore.currentIdentifier(for: RetiredCoreID.jaguar), RetiredCoreID.jaguar)
    }
}
