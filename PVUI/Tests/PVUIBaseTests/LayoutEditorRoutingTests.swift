//
//  LayoutEditorRoutingTests.swift
//  PVUIBaseTests
//
//  Which layout editor the pause menu and the three-finger hold open, and which
//  controller "Remap Controller" edits.
//

import Foundation
import Testing
@testable import PVUIBase

@Suite("LayoutEditorKind")
struct LayoutEditorKindTests {
    @Test("No skin layer means no editor, whatever else is reported")
    func noSkinLayer() {
        #expect(LayoutEditorKind.resolve(skinLayerEnabled: false, overlayMounted: true, skinLoaded: true) == nil)
        #expect(LayoutEditorKind.resolve(skinLayerEnabled: false, overlayMounted: false, skinLoaded: true) == nil)
    }

    @Test("The mounted overlay wins over a selected packaged skin")
    func overlayWins() {
        #expect(LayoutEditorKind.resolve(skinLayerEnabled: true, overlayMounted: true, skinLoaded: true) == .overlay)
        #expect(LayoutEditorKind.resolve(skinLayerEnabled: true, overlayMounted: true, skinLoaded: false) == .overlay)
    }

    @Test("A loaded packaged skin without the overlay opens the DeltaSkin editor")
    func deltaSkin() {
        #expect(LayoutEditorKind.resolve(skinLayerEnabled: true, overlayMounted: false, skinLoaded: true) == .deltaSkin)
    }

    @Test("A skin layer still loading has nothing to edit yet")
    func stillLoading() {
        #expect(LayoutEditorKind.resolve(skinLayerEnabled: true, overlayMounted: false, skinLoaded: false) == nil)
    }

    @Test("The hold needs three fingers for at least a second and a half")
    func gestureThresholds() {
        #expect(LayoutEditorGesture.touchCount == 3)
        #expect(LayoutEditorGesture.minimumPressDuration >= 1.5)
    }
}

@Suite("RemapControllerResolver")
struct RemapControllerResolverTests {
    private struct Pad: Equatable {
        let name: String
        var remappable = true
    }

    private func resolve(_ assigned: [Int: Pad], _ connected: [Pad]) -> Pad? {
        RemapControllerResolver.controller(assigned: assigned, connected: connected, isRemappable: \.remappable)
    }

    @Test("Player 1's controller comes first")
    func playerOne() {
        let first = Pad(name: "p1"), second = Pad(name: "p2")
        #expect(resolve([2: second, 1: first], [second, first]) == first)
    }

    @Test("Without player 1, the lowest-numbered assigned player")
    func lowestAssigned() {
        let second = Pad(name: "p2"), third = Pad(name: "p3")
        #expect(resolve([3: third, 2: second], [third, second]) == second)
    }

    @Test("Without assigned players, the first connected controller")
    func firstConnected() {
        let pad = Pad(name: "pad"), other = Pad(name: "other")
        #expect(resolve([:], [pad, other]) == pad)
    }

    @Test("Controllers that cannot be remapped are skipped; none left means nil")
    func skipsUnremappable() {
        let remote = Pad(name: "remote", remappable: false), pad = Pad(name: "pad")
        #expect(resolve([1: remote], [remote, pad]) == pad)
        #expect(resolve([1: remote], [remote]) == nil)
        #expect(resolve([:], []) == nil)
    }
}
