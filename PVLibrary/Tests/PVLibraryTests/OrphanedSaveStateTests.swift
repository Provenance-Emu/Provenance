//
//  OrphanedSaveStateTests.swift
//  PVLibraryTests
//
//  Deleting a PVCore row nils the `core` link of every save state on it. The stale-core
//  prune must not delete rows save states still use, and packaging (CloudKit metadata,
//  save bundles) must skip a save state that has already lost its core instead of
//  force-unwrapping it.
//

import XCTest
import RealmSwift
import PVRealm
@testable import PVLibrary

final class OrphanedSaveStateTests: XCTestCase {

    private var realm: Realm!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
    }

    private func addCore(_ identifier: String) throws -> PVCore {
        let core = PVCore()
        core.identifier = identifier
        try realm.write { realm.add(core) }
        return core
    }

    private func addState(core: PVCore?) throws -> PVSaveState {
        let game = PVGame()
        game.md5Hash = UUID().uuidString
        let state = PVSaveState()
        state.game = game
        state.core = core
        try realm.write { realm.add(state) }
        return state
    }

    func testPruneKeepsStaleCoresThatSaveStatesUse() throws {
        let used = try addCore("com.example.core.unbundled")
        _ = try addCore("com.example.phantom")
        _ = try addCore("com.example.core.valid")
        _ = try addState(core: used)

        let stale = PVEmulatorConfiguration.staleCores(in: realm, validIdentifiers: ["com.example.core.valid"])

        XCTAssertEqual(stale.map(\.identifier), ["com.example.phantom"])
    }

    @MainActor // setUp opened the realm on the main thread
    func testPackagingSaveStateWithoutCoreReturnsNil() async throws {
        // Frozen, as the CloudKit syncer hands it over: toPackage runs off the realm's thread.
        let state = try addState(core: nil).freeze()

        let package = try await state.toPackage()

        XCTAssertNil(package)
    }
}
