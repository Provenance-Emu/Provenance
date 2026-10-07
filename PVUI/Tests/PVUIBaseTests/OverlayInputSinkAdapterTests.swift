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
}
