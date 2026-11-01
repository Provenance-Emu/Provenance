//
//  DirectCoreInputTests.swift
//  PVUIBaseTests
//
//  `DeltaSkinInputHandler` sends input straight to the core, with no classic on-screen
//  controller in between: keyboard Start/Select, pause-menu hardware switches, and the
//  release of buttons left held when the menu opens.
//

import Foundation
import Testing
import PVCoreBridge
import PVEmulatorCore
import PVSystems
@testable import PVUIBase

/// An Atari 2600 core that records every button edge it receives.
private final class Recording2600Core: PVEmulatorCore, PV2600SystemResponderClient {
    private(set) var edges: [(button: PV2600Button, pressed: Bool)] = []

    func didPush(_ button: PV2600Button, forPlayer player: Int) { edges.append((button, true)) }
    func didRelease(_ button: PV2600Button, forPlayer player: Int) { edges.append((button, false)) }
}

@Suite("Direct core input") @MainActor
struct DirectCoreInputTests {
    private static func makeCore() -> Recording2600Core {
        let core = Recording2600Core()
        core.systemIdentifier = SystemIdentifier.Atari2600.rawValue
        return core
    }

    @Test("Keyboard Start and Select reach the 2600's Reset and Select, as the classic pad sent them")
    func startSelect() {
        let core = Self.makeCore()
        let handler = DeltaSkinInputHandler(emulatorCore: core)
        handler.sendCoreButton("start", isPressed: true)
        handler.sendCoreButton("start", isPressed: false)
        handler.sendCoreButton("select", isPressed: true)
        handler.sendCoreButton("select", isPressed: false)
        #expect(core.edges.map(\.button) == [.reset, .reset, .select, .select])
        #expect(core.edges.map(\.pressed) == [true, false, true, false])
    }

    @Test("A hardware switch id reaches the core as the enum case it names",
          arguments: ["leftdiffa", "leftdiffb", "rightdiffa", "rightdiffb"])
    func hardwareSwitch(id: String) {
        let core = Self.makeCore()
        let handler = DeltaSkinInputHandler(emulatorCore: core)
        handler.sendHardwareSwitch(id, isPressed: true)
        handler.sendHardwareSwitch(id, isPressed: false)
        #expect(core.edges.map(\.button) == [PV2600Button(id), PV2600Button(id)])
        #expect(core.edges.map(\.pressed) == [true, false])
    }

    @Test("Reconnecting after the menu releases a button whose touch-up was lost")
    func reconnectReleasesHeldButtons() {
        let core = Self.makeCore()
        let handler = DeltaSkinInputHandler(emulatorCore: core)
        handler.sendCoreButton("select", isPressed: true)
        NotificationCenter.default.post(name: NSNotification.Name("DeltaSkinInputHandlerReconnect"), object: nil)
        #expect(core.edges.last?.button == .select)
        #expect(core.edges.last?.pressed == false)
    }

    @Test("Reconnecting with nothing held sends the core no edges")
    func reconnectWithNothingHeld() {
        let core = Self.makeCore()
        let handler = DeltaSkinInputHandler(emulatorCore: core)
        handler.sendCoreButton("select", isPressed: true)
        handler.sendCoreButton("select", isPressed: false)
        NotificationCenter.default.post(name: NSNotification.Name("DeltaSkinInputHandlerReconnect"), object: nil)
        #expect(core.edges.count == 2)
    }
}
