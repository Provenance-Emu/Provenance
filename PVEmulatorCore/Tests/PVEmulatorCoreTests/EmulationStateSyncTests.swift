//
//  EmulationStateSyncTests.swift
//  PVEmulatorCoreTests
//

import Combine
@testable import PVEmulatorCore
import XCTest

final class EmulationStateSyncTests: XCTestCase {
    /// The cache is created by its first reader. That read used to return the defaults, so a
    /// running game reported `isOn == false` once and the pause menu request was ignored.
    @MainActor
    func testFirstReadReportsTheCurrentState() {
        var running = EmulationState.State()
        running.isOn = true
        running.systemName = "com.provenance.gba"
        let subject = CurrentValueSubject<EmulationState.State, Never>(running)

        let sync = EmulationStateSync(subject: subject)

        XCTAssertTrue(sync.isOn)
        XCTAssertEqual(sync.systemName, "com.provenance.gba")
    }

    @MainActor
    func testLaterChangesArrive() async {
        let subject = CurrentValueSubject<EmulationState.State, Never>(EmulationState.State())
        let sync = EmulationStateSync(subject: subject)
        XCTAssertFalse(sync.isOn)

        var running = EmulationState.State()
        running.isOn = true
        subject.send(running)
        let delivered = expectation(description: "main queue delivered the change")
        DispatchQueue.main.async { delivered.fulfill() }
        await fulfillment(of: [delivered], timeout: 2)

        XCTAssertTrue(sync.isOn)
    }
}
