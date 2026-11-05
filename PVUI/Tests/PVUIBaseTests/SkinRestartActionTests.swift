//
//  SkinRestartActionTests.swift
//  PVUIBaseTests
//
//  A skin element id `reset` presses the console's Reset input where the system has one
//  (2600, 5200, 7800); `restart` / `reboot`, and `reset` elsewhere, restart the game.
//

import PVCoreBridge
import PVSystems
import Testing
@testable import PVUIBase

@Suite("Skin restart/reset routing")
struct SkinRestartActionTests {
    private typealias Handler = DeltaSkinInputHandler

    @Test("reset presses the console Reset on systems that have one",
          arguments: [SystemIdentifier.Atari2600, .Atari5200, .Atari7800])
    func resetPressesConsoleReset(system: SystemIdentifier) {
        #expect(Handler.restartAction(forButtonId: "reset", system: system) == .pressConsoleReset)
    }

    @Test("reset restarts the game on systems without a reset input",
          arguments: [SystemIdentifier.NES, .SNES, .Genesis, .MasterSystem, .ColecoVision, .Intellivision, .GBA, .PSX])
    func resetRestartsElsewhere(system: SystemIdentifier) {
        #expect(Handler.restartAction(forButtonId: "reset", system: system) == .restartEmulation)
    }

    @Test("reset restarts the game when the system is unknown")
    func resetWithoutSystem() {
        #expect(Handler.restartAction(forButtonId: "reset", system: nil) == .restartEmulation)
    }

    @Test("restart and reboot always restart the game, even on a console with a Reset switch",
          arguments: ["restart", "reboot"])
    func restartAndRebootNeverPressConsoleReset(id: String) {
        for system: SystemIdentifier? in [.Atari2600, .Atari5200, .Atari7800, .NES, nil] {
            #expect(Handler.restartAction(forButtonId: id, system: system) == .restartEmulation)
        }
    }

    @Test("Matching ignores case")
    func caseInsensitive() {
        #expect(Handler.restartAction(forButtonId: "RESET", system: .Atari2600) == .pressConsoleReset)
        #expect(Handler.restartAction(forButtonId: "Reset", system: .NES) == .restartEmulation)
        #expect(Handler.restartAction(forButtonId: "Restart", system: .Atari7800) == .restartEmulation)
    }

    @Test("Other ids are not restart actions", arguments: ["start", "r", "resetgame", "", "fire1"])
    func otherIds(id: String) {
        #expect(Handler.restartAction(forButtonId: id, system: .Atari2600) == nil)
    }
}
