//
//  MIDISystemRegistryTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@testable import PVCoreBridge
import PVSystems
import XCTest

final class MIDISystemRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to empty so baseline tests are isolated
        MIDISystemRegistry.shared._reset(to: [])
    }

    override func tearDown() {
        // Restore the real baseline so other tests that query the shared
        // registry after us get correct results
        MIDISystemRegistry.shared._reset(to: MIDISystemRegistry.baseline)
        super.tearDown()
    }

    // MARK: - Baseline

    func testBaselineIsNonEmpty() {
        XCTAssertFalse(MIDISystemRegistry.baseline.isEmpty)
    }

    func testBaselineContainsAtariST() {
        XCTAssertTrue(MIDISystemRegistry.baseline.contains(.AtariST),
                      "Atari ST has built-in MIDI ports — must be in baseline")
    }

    func testBaselineContainsDOS() {
        XCTAssertTrue(MIDISystemRegistry.baseline.contains(.DOS),
                      "DOS had extensive General MIDI support — must be in baseline")
    }

    func testBaselineContainsMSX() {
        XCTAssertTrue(MIDISystemRegistry.baseline.contains(.MSX))
    }

    func testBaselineContainsMSX2() {
        XCTAssertTrue(MIDISystemRegistry.baseline.contains(.MSX2))
    }

    func testBaselineContainsPC98() {
        XCTAssertTrue(MIDISystemRegistry.baseline.contains(.PC98))
    }

    func testBaselineContainsC64() {
        XCTAssertTrue(MIDISystemRegistry.baseline.contains(.C64))
    }

    // MARK: - Registration

    func testRegisterSingleSystem() {
        XCTAssertFalse(MIDISystemRegistry.shared.supportsMIDI(.NES))
        MIDISystemRegistry.shared.register(system: .NES)
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.NES))
    }

    func testRegisterSetOfSystems() {
        let systems: Set<SystemIdentifier> = [.SNES, .Genesis]
        XCTAssertFalse(MIDISystemRegistry.shared.supportsMIDI(.SNES))
        XCTAssertFalse(MIDISystemRegistry.shared.supportsMIDI(.Genesis))
        MIDISystemRegistry.shared.register(systems: systems)
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.SNES))
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.Genesis))
    }

    func testRegisterIsIdempotent() {
        MIDISystemRegistry.shared.register(system: .NES)
        MIDISystemRegistry.shared.register(system: .NES)
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.NES))
        XCTAssertEqual(MIDISystemRegistry.shared.registeredSystems.filter { $0 == .NES }.count, 1)
    }

    // MARK: - Provider protocol

    func testRegisterProviderIngestionFlattensStaticSets() {
        class FakeCore: MIDISystemsProvider {
            static var midiSupportedSystemIdentifiers: Set<SystemIdentifier> {
                [.SNES, .Saturn]
            }
        }
        XCTAssertFalse(MIDISystemRegistry.shared.supportsMIDI(.SNES))
        MIDISystemRegistry.shared.registerProvider(FakeCore.self)
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.SNES))
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.Saturn))
    }

    // MARK: - Snapshot

    func testRegisteredSystemsSnapshotIsIsolated() {
        MIDISystemRegistry.shared.register(system: .NES)
        let snapshot = MIDISystemRegistry.shared.registeredSystems
        MIDISystemRegistry.shared.register(system: .SNES)
        // Snapshot taken before the second registration should not include SNES
        XCTAssertFalse(snapshot.contains(.SNES))
    }

    // MARK: - SystemIdentifier extension

    func testSystemIdentifierExtensionReturnsTrueForRegistered() {
        MIDISystemRegistry.shared.register(system: .NES)
        XCTAssertTrue(SystemIdentifier.NES.supportsMIDI)
    }

    func testSystemIdentifierExtensionReturnsFalseForUnregistered() {
        XCTAssertFalse(SystemIdentifier.NES.supportsMIDI)
    }

    // MARK: - Thread safety (smoke test)

    func testConcurrentRegistrationsDoNotCrash() {
        let expectation = expectation(description: "all concurrent ops complete")
        expectation.expectedFulfillmentCount = 100

        for i in 0..<100 {
            DispatchQueue.global().async {
                // Alternate between single and set registration
                if i % 2 == 0 {
                    MIDISystemRegistry.shared.register(system: .NES)
                } else {
                    MIDISystemRegistry.shared.register(systems: [.SNES, .Genesis])
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
        // Should contain the registered systems after concurrent writes
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.NES))
        XCTAssertTrue(MIDISystemRegistry.shared.supportsMIDI(.SNES))
    }
}
