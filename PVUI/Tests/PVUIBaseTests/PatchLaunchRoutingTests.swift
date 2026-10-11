//
//  PatchLaunchRoutingTests.swift
//  PVUIBaseTests
//

import Foundation
import Testing
@testable import PVUIBase

/// Documents the intended default-patch / play-original routing contract for SceneCoordinator.
/// Full Realm-backed launch tests require the app host; these guard the gate helpers used by patch launches.
struct PatchLaunchRoutingTests {

    @Test func patchLaunchUsesIndependentLaunchGateSlot() {
        var gate = LaunchGate()
        let first = gate.begin()
        #expect(gate.ownerID == first)
        gate.cancel()
        let second = gate.begin()
        #expect(gate.ownerID == second)
        let finishedSecond = gate.finish(second)
        #expect(finishedSecond)
        #expect(gate.ownerID == nil)
    }

    @Test func concurrentLaunchIsRejectedUntilFinished() {
        var gate = LaunchGate()
        let owner = gate.begin()
        // A second begin while owned replaces via cancel in SceneCoordinator;
        // finish of a stale id must not clear the new owner.
        gate.cancel()
        let replacement = gate.begin()
        let finishedStale = gate.finish(owner)
        #expect(!finishedStale)
        #expect(gate.ownerID == replacement)
        let finishedReplacement = gate.finish(replacement)
        #expect(finishedReplacement)
    }
}
