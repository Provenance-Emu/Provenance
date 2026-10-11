//
//  OrphanedSaveStateRepairTests.swift
//  PVLibraryTests
//
//  Save states whose core row was deleted (Lite shares the library and used to prune the
//  native cores it doesn't ship) get their core back from the best evidence available:
//  the save's JSON sidecar, then a unique version match, then a unique available core.
//

import XCTest
import RealmSwift
import PVRealm
@testable import PVLibrary

final class OrphanedSaveStateRepairTests: XCTestCase {

    private let system = "com.provenance.gamecube"
    private let nativeID = "com.provenance.core.dolphin"
    private let libretroID = "dolphin.libretro.framework"

    private var realm: Realm!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        let gameCube = PVSystem()
        gameCube.identifier = system
        try realm.write {
            realm.add(gameCube)
            for (identifier, version) in [(nativeID, "2512"), (libretroID, "5.0")] {
                let core = PVCore()
                core.identifier = identifier
                core.projectVersion = version
                core.supportedSystems.append(gameCube)
                realm.add(core)
            }
        }
    }

    private func core(_ identifier: String) -> PVCore? {
        realm.object(ofType: PVCore.self, forPrimaryKey: identifier)
    }

    private func addOrphan(version: String?) throws -> PVSaveState {
        let game = PVGame()
        game.md5Hash = UUID().uuidString
        game.systemIdentifier = system
        let state = PVSaveState()
        state.game = game
        state.createdWithCoreVersion = version
        try realm.write { realm.add(state) }
        return state
    }

    private func repair(available: Set<String>? = nil, sidecar: String? = nil) throws -> Int {
        var repaired = 0
        try realm.write {
            repaired = OrphanedSaveStateRepair.repair(
                in: realm,
                isAvailable: { available?.contains($0.identifier) ?? true },
                sidecarCoreIdentifier: { _ in sidecar })
        }
        return repaired
    }

    func testSidecarCoreWins() throws {
        let state = try addOrphan(version: "5.0")

        XCTAssertEqual(try repair(sidecar: nativeID), 1)
        XCTAssertEqual(state.core?.identifier, nativeID)
    }

    func testVersionPicksBetweenCandidates() throws {
        let state = try addOrphan(version: "2512")

        XCTAssertEqual(try repair(), 1)
        XCTAssertEqual(state.core?.identifier, nativeID)
    }

    func testUnavailableCoreIsNeverChosen() throws {
        let state = try addOrphan(version: "2512")

        XCTAssertEqual(try repair(available: []), 0)
        XCTAssertNil(state.core)
    }

    func testVersionOfAnUnavailableCoreBlocksTheFallback() throws {
        // The version names native Dolphin, which this build lacks: the save must wait for a
        // build that has it rather than land on the one core that is available.
        let state = try addOrphan(version: "2512")

        XCTAssertEqual(try repair(available: [libretroID]), 0)
        XCTAssertNil(state.core)
    }

    func testSingleAvailableCandidateIsUsed() throws {
        let state = try addOrphan(version: nil)

        XCTAssertEqual(try repair(available: [libretroID]), 1)
        XCTAssertEqual(state.core?.identifier, libretroID)
    }

    func testAmbiguousSaveStaysOrphaned() throws {
        let state = try addOrphan(version: "unknown")

        XCTAssertEqual(try repair(), 0)
        XCTAssertNil(state.core)
    }

    func testSecondRunIsANoOp() throws {
        _ = try addOrphan(version: "2512")

        XCTAssertEqual(try repair(), 1)
        XCTAssertEqual(try repair(), 0)
    }

    func testPruneKeepsCoresThatRecentGamesUse() throws {
        let recent = PVRecentGame()
        recent.core = core(nativeID)
        try realm.write { realm.add(recent) }

        let stale = PVEmulatorConfiguration.staleCores(in: realm, validIdentifiers: [])

        XCTAssertEqual(stale.map(\.identifier), [libretroID])
    }
}
