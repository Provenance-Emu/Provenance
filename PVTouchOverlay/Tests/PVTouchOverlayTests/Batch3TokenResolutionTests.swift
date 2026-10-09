import Foundation
import Testing
import PVCoreBridge
import PVSystems
@testable import PVTouchOverlay

/// Each token in a batch 3 binding must reach the button its label promises. The enum is the one
/// `DeltaSkinInputHandler` builds for the system, which is not always `controllerType` (TIC-80, Atari ST).
@Suite("Batch 3 token resolution")
struct Batch3TokenResolutionTests {
    /// The button enum the handler dispatches each batch 3 system through.
    private static func buttonType(_ system: SystemIdentifier) -> any EmulatorCoreButton.Type {
        switch system {
        case .AtariST, .DOS, .Quake, .Quake2, .C64, .ZXSpectrum, .Macintosh, .PalmOS, .AppleII, .PC98:
            return PVDOSButton.self
        case .MegaDuck: return PVGBButton.self
        case .FDS: return PVNESButton.self
        case .GameGear: return PVGenesisButton.self
        default: return system.controllerType
        }
    }

    private static func button(_ system: SystemIdentifier, _ token: String) -> Int {
        buttonType(system).init(token).rawValue
    }

    private static func same(_ system: SystemIdentifier, _ token: String, as canonical: String) -> Bool {
        button(system, token) == button(system, canonical)
    }

    private static func tokens(_ system: SystemIdentifier) throws -> [OverlayFamilySlot: String] {
        try #require(SystemOverlayBindings.binding(for: system)).tokens
    }

    @Test("Distinct slots press distinct buttons on every batch 3 pad", arguments: SystemOverlayBindings.batch3Systems)
    func distinctButtons(system: SystemIdentifier) throws {
        let values = try Self.tokens(system).map { Self.button(system, $0.value) }
        #expect(Set(values).count == values.count, "\(system) has two slots on one button")
    }

    @Test("No batch 3 slot token falls back to a d-pad direction", arguments: SystemOverlayBindings.batch3Systems)
    func noDirectionFallback(system: SystemIdentifier) throws {
        let directions = Set(["up", "down", "left", "right"].map { Self.button(system, $0) })
        for (slot, token) in try Self.tokens(system) {
            #expect(!directions.contains(Self.button(system, token)),
                    "\(system) \(slot.rawValue)=\(token) resolves to a d-pad direction")
        }
    }

    @Test("No batch 3 token is one the handler consumes before the core sees it", arguments: SystemOverlayBindings.batch3Systems)
    func noHandlerCommand(system: SystemIdentifier) throws {
        let commands = ["menu", "quicksave", "quickload", "fastforward", "slowmotion", "screenshot", "restart",
                        "reset", "reboot", "quit", "exit"]
        for (slot, token) in try Self.tokens(system) {
            let lowered = token.lowercased()
            #expect(!commands.contains { lowered.contains($0) }, "\(system) \(slot.rawValue)=\(token) is a handler command")
        }
    }

    @Test("DOOM actions are PVDoomButton's own")
    func doom() throws {
        let tokens = try Self.tokens(.DOOM)
        let expected: [(OverlayFamilySlot, String)] = [
            (.a, "use"), (.b, "strafe"), (.x, "fire"), (.y, "run"), (.l, "strafeleft"), (.r, "straferight"),
            (.l2, "weaponprev"), (.r2, "weaponnext"), (.start, "pause"), (.select, "map")
        ]
        for (slot, name) in expected {
            #expect(PVDoomButton(tokens[slot] ?? "").stringValue == name, "\(slot.rawValue)")
        }
    }

    @Test("Wolf3D actions are PVWolf3DButton's own")
    func wolf3D() throws {
        let tokens = try Self.tokens(.Wolf3D)
        let expected: [(OverlayFamilySlot, String)] = [
            (.a, "fire"), (.b, "open"), (.x, "run"), (.y, "strafeon"), (.l, "strafeleft"), (.r, "straferight"),
            (.l2, "weaponprev"), (.r2, "weaponnext"), (.start, "menu"), (.select, "map")
        ]
        for (slot, name) in expected {
            #expect(PVWolf3DButton(tokens[slot] ?? "").stringValue == name, "\(slot.rawValue)")
        }
    }

    @Test("DOS-family pads press fire1, fire2, run, strafe, weapon, pause and select")
    func dos() throws {
        for system in [SystemIdentifier.DOS, .Quake, .Quake2] {
            let tokens = try Self.tokens(system)
            let expected: [(OverlayFamilySlot, PVDOSButton)] = [
                (.a, .fire1), (.b, .fire2), (.x, .run), (.l, .strafeLeft), (.r, .strafeRight),
                (.l2, .weaponPrev), (.r2, .weaponNext), (.start, .pause), (.select, .select)
            ]
            for (slot, button) in expected {
                #expect(PVDOSButton(tokens[slot] ?? "") == button, "\(system) \(slot.rawValue)")
            }
        }
    }

    @Test("Computers press fire1 and fire2; MSX family also pause and select")
    func computers() throws {
        for system in [SystemIdentifier.C64, .ZXSpectrum, .Macintosh, .PalmOS, .AppleII, .AtariST] {
            #expect(Self.same(system, try Self.tokens(system)[.a] ?? "", as: "fire1"), "\(system)")
        }
        for system in [SystemIdentifier.MSX, .MSX2, .EP128, .PC98] {
            let tokens = try Self.tokens(system)
            #expect(Self.same(system, tokens[.a] ?? "", as: "fire1") && Self.same(system, tokens[.b] ?? "", as: "fire2"),
                    "\(system)")
            #expect(Self.same(system, tokens[.start] ?? "", as: "pause") && Self.same(system, tokens[.select] ?? "", as: "select"),
                    "\(system)")
        }
    }

    @Test("Atari 8-bit: fire, Start and Select")
    func atari8bit() throws {
        let tokens = try Self.tokens(.Atari8bit)
        #expect(PVA8Button(tokens[.a] ?? "") == .fire && PVA8Button(tokens[.start] ?? "") == .startKey)
        #expect(PVA8Button(tokens[.select] ?? "") == .selectKey)
    }

    @Test("TIC-80 presses its own A B X Y, Start and Select")
    func tic80() throws {
        let tokens = try Self.tokens(.TIC80)
        let expected: [(OverlayFamilySlot, PVTIC80Button)] = [
            (.a, .a), (.b, .b), (.x, .x), (.y, .y), (.start, .start), (.select, .select)
        ]
        for (slot, button) in expected {
            #expect(PVTIC80Button(tokens[slot] ?? "") == button, "\(slot.rawValue)")
        }
    }

    @Test("Lynx: A, B, Option 1, Option 2 and Pause are their own buttons")
    func lynx() throws {
        let tokens = try Self.tokens(.Lynx)
        let expected: [(OverlayFamilySlot, PVLynxButton)] = [
            (.a, .a), (.b, .b), (.start, .option1), (.select, .option2), (.reset, .pause)
        ]
        for (slot, button) in expected {
            #expect(PVLynxButton(tokens[slot] ?? "") == button, "\(slot.rawValue)")
        }
    }

    @Test("Game Gear, Master System and SG-1000: button 1 is b, button 2 is c")
    func segaEightBit() throws {
        for system in [SystemIdentifier.GameGear, .MasterSystem, .SG1000] {
            let tokens = try Self.tokens(system)
            #expect(Self.same(system, tokens[.b] ?? "", as: "b") && Self.same(system, tokens[.a] ?? "", as: "c"), "\(system)")
            #expect(Self.same(system, tokens[.start] ?? "", as: "start"), "\(system)")
        }
    }

    @Test("Pokemon Mini: A B C and Menu, with no token that opens the pause menu")
    func pokemonMini() throws {
        let tokens = try Self.tokens(.PokemonMini)
        #expect(PVPMButton(tokens[.a] ?? "") == .a && PVPMButton(tokens[.b] ?? "") == .b)
        #expect(PVPMButton(tokens[.c] ?? "") == .c && PVPMButton(tokens[.start] ?? "") == .menu)
    }

    @Test("Supervision, FDS and Mega Duck press A, B, Start and Select")
    func plainPads() throws {
        for system in [SystemIdentifier.Supervision, .FDS, .MegaDuck] {
            let tokens = try Self.tokens(system)
            for name in ["a", "b", "start", "select"] {
                let slot = try #require(OverlayFamilySlot(rawValue: name))
                #expect(Self.same(system, tokens[slot] ?? "", as: name), "\(system) \(name)")
            }
        }
    }

    @Test("3DO presses A B C, L R, P and X")
    func threeDO() throws {
        let tokens = try Self.tokens(._3DO)
        let expected: [(OverlayFamilySlot, PV3DOButton)] = [
            (.a, .a), (.b, .b), (.c, .c), (.l, .L), (.r, .R), (.start, .P), (.select, .X)
        ]
        for (slot, button) in expected {
            #expect(PV3DOButton(tokens[slot] ?? "") == button, "\(slot.rawValue)")
        }
    }
}
