//
//  OverlayInputSinkAdapterTests.swift
//  PVUIBaseTests
//
//  The programmatic overlay's sink speaks skin tokens; the adapter forwards them to
//  `DeltaSkinInputHandler` unchanged.
//

import Foundation
import Testing
import PVSystems
import PVTouchOverlay
@testable import PVUIBase

@Suite("OverlayInputSinkAdapter") @MainActor
struct OverlayInputSinkAdapterTests {
    final class SpyHandler: DeltaSkinInputHandler {
        var pressed: [String] = []
        var released: [String] = []
        var sticks: [(id: String, horizontal: Float, vertical: Float)] = []
        var ndsTouches: [CGPoint] = []
        var ndsReleases = 0

        override func buttonPressed(_ buttonId: String) { pressed.append(buttonId) }
        override func buttonReleased(_ buttonId: String) { released.append(buttonId) }
        override func analogStickMoved(_ stickId: String, x: Float, y: Float) {
            sticks.append((stickId, x, y))
        }
        override func ndsBottomScreenTouched(at normalizedPoint: CGPoint) { ndsTouches.append(normalizedPoint) }
        override func ndsBottomScreenTouchReleased() { ndsReleases += 1 }
    }

    @Test("Tokens pass straight through; sticks use the thumbstick ids; actions map to skin function tokens")
    func passthrough() throws {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        adapter.overlayPress(OverlayInputID(system: .SNES, token: "a"))
        adapter.overlayRelease(OverlayInputID(system: .SNES, token: "a"))
        adapter.overlayStick(.left, x: 0.5, y: -0.25)
        adapter.overlayAction(.quickSave)
        adapter.overlayAction(.menu)
        #expect(spy.pressed == ["a", "quicksave", "menu"])
        // menu fires the handler's menuButtonHandler on press, so it gets no release.
        #expect(spy.released == ["a", "quicksave"])
        let stick = try #require(spy.sticks.first)
        #expect(spy.sticks.count == 1)
        #expect(stick.id == "leftThumbstick" && stick.horizontal == 0.5 && stick.vertical == -0.25)
    }

    @Test("A PlayStation stick click reaches the handler as the L3/R3 skin tokens")
    func stickClick() throws {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        let psx = try #require(SystemOverlayBindings.binding(for: .PSX))
        adapter.overlayPress(psx.inputID(.l3))
        adapter.overlayRelease(psx.inputID(.l3))
        adapter.overlayPress(psx.inputID(.r3))
        #expect(spy.pressed == ["l3", "r3"])
        #expect(spy.released == ["l3"])
    }

    @Test("Analog triggers press at a positive value and release at zero")
    func analogTrigger() {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        adapter.overlayAnalogTrigger(OverlayInputID(system: .GameCube, token: "l"), value: 1)
        adapter.overlayAnalogTrigger(OverlayInputID(system: .GameCube, token: "l"), value: 0)
        #expect(spy.pressed == ["l"])
        #expect(spy.released == ["l"])
    }

    @Test("Actions with no handler token are dropped instead of reaching the gameplay path")
    func unsupportedActions() {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        adapter.overlayAction(.toggleKeyboard)
        adapter.overlayAction(.toggleMouse)
        adapter.overlayAction(.flip)
        adapter.overlayAction(.diskSide)
        adapter.overlayHardwareSwitch(descriptorID: "tvType", isOn: true)
        #expect(spy.pressed.isEmpty)
        #expect(spy.released.isEmpty)
    }

    @Test("DS screen surface forwards normalized points and release")
    func dsSurface() {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        adapter.overlaySurface(.dsScreen, normalized: CGPoint(x: 0.25, y: 0.75), phase: .began)
        adapter.overlaySurface(.dsScreen, normalized: CGPoint(x: 0.5, y: 0.5), phase: .moved)
        adapter.overlaySurface(.dsScreen, normalized: .zero, phase: .ended)
        adapter.overlaySurface(.wiiPointer, normalized: CGPoint(x: 0.1, y: 0.1), phase: .began)
        #expect(spy.ndsTouches == [CGPoint(x: 0.25, y: 0.75), CGPoint(x: 0.5, y: 0.5)])
        #expect(spy.ndsReleases == 1)
    }

    @Test("The keypad action only runs the keypad toggle: the core never sees it")
    func keypadAction() {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        var toggles = 0
        adapter.onKeypadToggle = { toggles += 1 }
        adapter.overlayAction(.keypad)
        adapter.overlayAction(.keypad)
        #expect(toggles == 2)
        #expect(spy.pressed.isEmpty && spy.released.isEmpty)
    }

    @Test("The service action presses at once and releases after the switch timing, not in the same tick")
    func serviceAction() async throws {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        adapter.overlayAction(.service)
        #expect(spy.pressed == ["service"])
        #expect(spy.released.isEmpty)
        try await Task.sleep(for: .seconds(HardwareSwitchTiming.pressDuration * 4))
        #expect(spy.released == ["service"])
    }

    @Test("Batch 1 console switches reach the handler as the latch tokens the 2600 resolves")
    func consoleSwitchTokens() {
        let spy = SpyHandler()
        let adapter = OverlayInputSinkAdapter(handler: spy)
        for entry in OverlayHardwareSwitch.all {
            adapter.overlayPress(OverlayInputID(system: .Atari2600, token: entry.token))
        }
        #expect(spy.pressed == ["leftdiff", "rightdiff", "tvtype"])
    }

    @Test("WonderSwan d-pad directions resolve to the X cluster, PS3 shape names stay shape names")
    func batch2Normalisation() {
        let handler = DeltaSkinInputHandler()
        for system in [SystemIdentifier.WonderSwan, .WonderSwanColor] {
            let directions = ["up", "right", "down", "left"].map { handler.normalizeSkinButtonId($0, for: system) }
            #expect(directions == ["x1", "x2", "x3", "x4"], "\(system)")
            // The Y cluster the second d-pad presses is left alone.
            let cluster = ["y1", "y2", "y3", "y4"].map { handler.normalizeSkinButtonId($0, for: system) }
            #expect(cluster == ["y1", "y2", "y3", "y4"], "\(system)")
        }
        for system in [SystemIdentifier.PS2, .PS3, .PSP] {
            let shapes = ["triangle", "square", "circle", "cross"].map { handler.normalizeSkinButtonId($0, for: system) }
            #expect(shapes == ["triangle", "square", "circle", "cross"], "\(system)")
            #expect(handler.normalizeSkinButtonId("x", for: system) == "triangle")
        }
    }
}
