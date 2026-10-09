import Foundation
import Testing
import PVCoreBridge
import PVSystems
@testable import PVTouchOverlay

/// Each token in a batch 1 binding must reach the button the label promises: `controllerType.init(token)` is the
/// enum the handler's `PV<System>Button(id)` call builds, and an unknown token falls back to a d-pad direction.
@Suite("Binding token resolution")
struct BindingTokenResolutionTests {
    /// The button case a token builds, as the enum's raw value; compare two spellings of the same case.
    private static func button(_ system: SystemIdentifier, _ token: String) -> Int {
        system.controllerType.init(token).rawValue
    }

    private static func same(_ system: SystemIdentifier, _ token: String, as canonical: String) -> Bool {
        button(system, token) == button(system, canonical)
    }

    @Test("No batch 1 slot token falls back to a d-pad direction", arguments: SystemOverlayBindings.batch1Systems)
    func noFallback(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        let directions = ["up", "down", "left", "right"]
        let directionValues = Set(directions.map { Self.button(system, $0) })
        #expect(directionValues.count == directions.count, "\(system) d-pad directions collide")
        for (slot, token) in binding.tokens {
            #expect(!directionValues.contains(Self.button(system, token)),
                    "\(system) \(slot.rawValue)=\(token) resolves to a d-pad direction")
        }
    }

    @Test("Atari console buttons: 2600 RESET is start, 5200 and 7800 RESET is r (never the restart token)")
    func atariConsoleButtons() throws {
        #expect(Self.same(.Atari2600, "start", as: "reset"))
        #expect(Self.same(.Atari5200, "r", as: "reset"))
        #expect(Self.same(.Atari7800, "r", as: "reset"))
        #expect(!Self.same(.Atari5200, "pause", as: "reset") && !Self.same(.Atari7800, "pause", as: "reset"))
        for system in [SystemIdentifier.Atari2600, .Atari5200, .Atari7800] {
            let binding = try #require(SystemOverlayBindings.binding(for: system))
            #expect(binding.tokens.values.allSatisfy { $0.lowercased() != "reset" }, "\(system) must not bind the restart token")
        }
    }

    @Test("Keypad keys land on the keys they are labelled with")
    func keypadKeys() {
        let digits = (0...9).map(String.init)
        #expect(digits.allSatisfy { Self.same(.Atari5200, $0, as: "number\($0)") })
        #expect(Self.same(.Atari5200, "*", as: "asterisk") && Self.same(.Atari5200, "#", as: "pound"))
        for system in [SystemIdentifier.AtariJaguar, .AtariJaguarCD, .ColecoVision, .Intellivision] {
            #expect(digits.allSatisfy { Self.same(system, $0, as: "button\($0)") }, "\(system)")
        }
        for system in [SystemIdentifier.AtariJaguar, .AtariJaguarCD, .ColecoVision] {
            #expect(Self.same(system, "*", as: "asterisk") && Self.same(system, "#", as: "pound"), "\(system)")
        }
        #expect(Self.button(.Intellivision, "clear") != Self.button(.Intellivision, "enter"))
        #expect(Self.same(.Intellivision, "clear", as: "select") && Self.same(.Intellivision, "enter", as: "start"))
    }

    @Test("Every keypad key is bound to its own button")
    func keypadKeysAreDistinct() throws {
        for system in [SystemIdentifier.Atari5200, .AtariJaguar, .AtariJaguarCD, .ColecoVision, .Intellivision] {
            let binding = try #require(SystemOverlayBindings.binding(for: system))
            let values = OverlayFamilySlot.keypadKeys.map { Self.button(system, binding.tokens[$0] ?? "") }
            #expect(Set(values).count == OverlayFamilySlot.keypadKeys.count, "\(system)")
        }
    }

    @Test("Fire buttons and side buttons")
    func fireButtons() {
        #expect(Self.button(.Atari7800, "fire1") != Self.button(.Atari7800, "fire2"))
        #expect(Self.button(.Atari5200, "fire1") != Self.button(.Atari5200, "fire2"))
        #expect(Set(["a", "b", "c"].map { Self.button(.AtariJaguar, $0) }).count == 3)
        #expect(Self.button(.AtariJaguar, "pause") != Self.button(.AtariJaguar, "option"))
        #expect(Self.button(.ColecoVision, "leftAction") != Self.button(.ColecoVision, "rightAction"))
        let intellivision = ["topAction", "bottomLeftAction", "bottomRightAction"].map { Self.button(.Intellivision, $0) }
        #expect(Set(intellivision).count == 3)
    }

    @Test("Arcade boards press the face buttons the thin wrapper maps to Y X L over B A R")
    func arcadeButtons() throws {
        for system in [SystemIdentifier.MAME, .CPS1, .CPS2, .CPS3] {
            let binding = try #require(SystemOverlayBindings.binding(for: system))
            let slots: [OverlayFamilySlot] = [.x, .y, .z, .a, .b, .c]
            let expected = ["square", "triangle", "l1", "cross", "circle", "r1"]
            for (slot, name) in zip(slots, expected) {
                #expect(Self.same(system, binding.tokens[slot] ?? "", as: name), "\(system) \(slot.rawValue)")
            }
            #expect(Self.same(system, binding.tokens[.coin] ?? "", as: "coin"))
            #expect(Self.same(system, binding.tokens[.start] ?? "", as: "start"))
        }
    }

    @Test("Neo Geo: A B C D are triangle, circle, cross and square; coin is the pad's Select")
    func neoGeoButtons() throws {
        for system in [SystemIdentifier.NeoGeo, .NeoGeoCD] {
            let binding = try #require(SystemOverlayBindings.binding(for: system))
            let slots: [OverlayFamilySlot] = [.a, .b, .c, .x, .coin]
            let expected = ["triangle", "circle", "cross", "square", "select"]
            for (slot, name) in zip(slots, expected) {
                #expect(Self.same(system, binding.tokens[slot] ?? "", as: name), "\(system) \(slot.rawValue)")
            }
        }
    }

    @Test("NAOMI, NAOMI 2 and Atomiswave press the Dreamcast pad's buttons and its coin")
    func segaArcadeButtons() throws {
        for system in [SystemIdentifier.NAOMI, .NAOMI2, .Atomiswave] {
            let binding = try #require(SystemOverlayBindings.binding(for: system))
            let slots: [OverlayFamilySlot] = [.a, .b, .c, .x, .y, .z, .coin]
            let expected = ["a", "b", "r", "x", "y", "l", "coin"]
            for (slot, name) in zip(slots, expected) {
                #expect(Self.same(system, binding.tokens[slot] ?? "", as: name), "\(system) \(slot.rawValue)")
            }
            #expect(Set(slots.map { Self.button(system, binding.tokens[$0] ?? "") }).count == slots.count)
        }
    }

    @Test("2600 console switches send the position-less latch tokens")
    func switchTokens() {
        #expect(OverlayHardwareSwitch.all.map(\.token) == ["leftdiff", "rightdiff", "tvtype"])
        #expect(OverlayHardwareSwitch.all.map(\.id) == ["left_diff", "right_diff", "color_bw"])
        let described = Set((SystemIdentifier.Atari2600.hardwareSwitches ?? []).map(\.id))
        #expect(described == Set(OverlayHardwareSwitch.all.map(\.id)))
    }
}
