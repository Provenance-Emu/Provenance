//
//  LaunchGateTests.swift
//  PVUIBaseTests
//
//  The single in-flight launch slot behind SceneCoordinator's "game already
//  launching" prompt, and the alert reset that prompt's retry relies on.
//

import Foundation
import Testing
@testable import PVUIBase

struct LaunchGateTests {

    @Test func beginClaimsTheSlot() {
        var gate = LaunchGate()
        let id = gate.begin()
        #expect(gate.ownerID == id)
    }

    @Test func ownerReleasesTheSlot() {
        var gate = LaunchGate()
        let id = gate.begin()
        let released = gate.finish(id)
        #expect(released)
        #expect(gate.ownerID == nil)
    }

    /// A launch cancelled and replaced by another must not release the
    /// replacement's slot when its own task finally ends.
    @Test func replacedLaunchCannotReleaseTheNewOne() {
        var gate = LaunchGate()
        let stale = gate.begin()
        gate.cancel()
        let current = gate.begin()

        let staleReleased = gate.finish(stale)
        #expect(!staleReleased)
        #expect(gate.ownerID == current)
        let currentReleased = gate.finish(current)
        #expect(currentReleased)
        #expect(gate.ownerID == nil)
    }

    @Test func cancelReleasesWhateverOwnsTheSlot() {
        var gate = LaunchGate()
        _ = gate.begin()
        gate.cancel()
        #expect(gate.ownerID == nil)
    }
}

@MainActor
struct RetroAlertStateResetTests {

    /// Waits past the alert's exit-animation reset.
    private func waitForReset() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    @Test func hideResetsTheAlert() async throws {
        let state = RetroAlertState()
        state.show(title: "First", message: "m", primaryButtonTitle: "OK", primaryAction: {})
        state.hide()
        try await waitForReset()
        #expect(state.title.isEmpty)
        #expect(state.onPrimaryAction == nil)
    }

    /// An alert shown right after another hides (as the launch prompt's retry
    /// does) must survive the first alert's delayed reset.
    @Test func alertShownAfterHideSurvivesTheReset() async throws {
        let state = RetroAlertState()
        state.show(title: "First", message: "m", primaryButtonTitle: "OK", primaryAction: {})
        state.hide()
        state.show(title: "Second", message: "m", primaryButtonTitle: "Go", primaryAction: {})
        try await waitForReset()
        #expect(state.isPresented)
        #expect(state.title == "Second")
        #expect(state.onPrimaryAction != nil)
    }
}
