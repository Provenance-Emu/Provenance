import Foundation
import Testing
import PVCoreBridge
import PVSystems
@testable import PVTouchOverlay

/// Each token in a batch 2 binding must reach the button its label promises. `controllerType.init(token)` is the
/// enum the handler's `PV<System>Button(id)` call builds; an unknown token falls back to the enum's default case.
@Suite("Batch 2 token resolution")
struct Batch2TokenResolutionTests {
    private static func button(_ system: SystemIdentifier, _ token: String) -> Int {
        system.controllerType.init(token).rawValue
    }

    private static func same(_ system: SystemIdentifier, _ token: String, as canonical: String) -> Bool {
        button(system, token) == button(system, canonical)
    }

    private static func tokens(_ system: SystemIdentifier) throws -> [OverlayFamilySlot: String] {
        try #require(SystemOverlayBindings.binding(for: system)).tokens
    }

    @Test("Distinct slots press distinct buttons on every batch 2 pad", arguments: SystemOverlayBindings.batch2Systems)
    func distinctButtons(system: SystemIdentifier) throws {
        let values = try Self.tokens(system).map { Self.button(system, $0.value) }
        #expect(Set(values).count == values.count, "\(system) has two slots on one button")
    }

    @Test("No batch 2 slot token falls back to a d-pad direction",
          arguments: SystemOverlayBindings.batch2Systems.filter { $0 != .WonderSwan && $0 != .WonderSwanColor })
    func noDirectionFallback(system: SystemIdentifier) throws {
        let directions = Set(["up", "down", "left", "right"].map { Self.button(system, $0) })
        for (slot, token) in try Self.tokens(system) {
            #expect(!directions.contains(Self.button(system, token)),
                    "\(system) \(slot.rawValue)=\(token) resolves to a d-pad direction")
        }
    }

    @Test("WonderSwan slot tokens are their own buttons, not the X1 fallback")
    func wonderSwanTokens() throws {
        for system in [SystemIdentifier.WonderSwan, .WonderSwanColor] {
            let tokens = try Self.tokens(system)
            let fallback = Self.button(system, "")
            #expect(tokens.values.allSatisfy { Self.button(system, $0) != fallback }, "\(system)")
            let cluster = [OverlayFamilySlot.dpad2Up, .dpad2Right, .dpad2Down, .dpad2Left].map { tokens[$0] ?? "" }
            #expect(zip(cluster, ["y1", "y2", "y3", "y4"]).allSatisfy { Self.same(system, $0, as: $1) }, "\(system)")
            #expect(Self.same(system, tokens[.select] ?? "", as: "sound"), "\(system)")
        }
    }

    @Test("Saturn presses its own six face buttons, L, R and Start")
    func saturn() throws {
        let tokens = try Self.tokens(.Saturn)
        for (slot, name) in [(OverlayFamilySlot.a, "a"), (.b, "b"), (.c, "c"), (.x, "x"), (.y, "y"), (.z, "z"),
                             (.l, "l"), (.r, "r"), (.start, "start")] {
            #expect(Self.same(.Saturn, tokens[slot] ?? "", as: name), "\(name)")
        }
    }

    @Test("Dreamcast: face buttons, analog triggers on l / r (no l2 / r2 case), Start")
    func dreamcast() throws {
        let tokens = try Self.tokens(.Dreamcast)
        for (slot, name) in [(OverlayFamilySlot.a, "a"), (.b, "b"), (.x, "x"), (.y, "y"), (.l, "l"), (.r, "r"),
                             (.start, "start")] {
            #expect(Self.same(.Dreamcast, tokens[slot] ?? "", as: name), "\(name)")
        }
        #expect(tokens[.l2] == nil && tokens[.r2] == nil)
    }

    @Test("PC Engine family and PC-FX: I-VI are button1-6 and Run is run")
    func numberedButtons() throws {
        for system in [SystemIdentifier.PCE, .SGFX, .PCECD, .PCFX] {
            let tokens = try Self.tokens(system)
            let slots: [OverlayFamilySlot] = [.a, .b, .c, .x, .y, .z]
            for (index, slot) in slots.enumerated() {
                #expect(Self.same(system, tokens[slot] ?? "", as: "button\(index + 1)"), "\(system) \(slot.rawValue)")
            }
            #expect(Self.same(system, tokens[.start] ?? "", as: "run"), "\(system) run")
            #expect(Self.same(system, tokens[.select] ?? "", as: "select"), "\(system) select")
        }
    }

    @Test("Neo Geo Pocket: Option is the only system button")
    func neoGeoPocket() throws {
        for system in [SystemIdentifier.NGP, .NGPC] {
            let tokens = try Self.tokens(system)
            #expect(Self.same(system, tokens[.start] ?? "", as: "option"))
            #expect(Self.same(system, tokens[.a] ?? "", as: "a") && Self.same(system, tokens[.b] ?? "", as: "b"))
            #expect(tokens[.select] == nil)
        }
    }

    @Test("PS2, PS3 and PSP press shapes, bumpers and triggers")
    func sony() throws {
        for system in [SystemIdentifier.PS2, .PS3, .PSP] {
            let tokens = try Self.tokens(system)
            for (slot, name) in [(OverlayFamilySlot.a, "cross"), (.b, "circle"), (.x, "triangle"), (.y, "square"),
                                 (.l, "l1"), (.r, "r1"), (.start, "start"), (.select, "select")] {
                #expect(Self.same(system, tokens[slot] ?? "", as: name), "\(system) \(name)")
            }
        }
        let ps2 = try Self.tokens(.PS2)
        #expect(Self.same(.PS2, ps2[.l2] ?? "", as: "l2") && Self.same(.PS2, ps2[.r2] ?? "", as: "r2"))
        #expect(Self.same(.PS3, try Self.tokens(.PS3)[.l3] ?? "", as: "l3"))
        let psp = try Self.tokens(.PSP)
        #expect(psp[.l2] == nil && psp[.r2] == nil && psp[.l3] == nil && psp[.r3] == nil)
    }

    @Test("CD-i buttons are button1 and button2, and nothing maps to the RESET that start would press")
    func cdi() throws {
        let tokens = try Self.tokens(.CDi)
        #expect(Self.same(.CDi, tokens[.b] ?? "", as: "button1") && Self.same(.CDi, tokens[.a] ?? "", as: "button2"))
        #expect(!tokens.values.contains { Self.same(.CDi, $0, as: "reset") })
    }

    @Test("Vectrex buttons 1-4 and Odyssey 2 Action are their own buttons")
    func vectrexAndOdyssey() throws {
        let vectrex = try Self.tokens(.Vectrex)
        let slots: [OverlayFamilySlot] = [.a, .b, .x, .y]
        for (index, slot) in slots.enumerated() {
            #expect(Self.same(.Vectrex, vectrex[slot] ?? "", as: "button\(index + 1)"))
        }
        #expect(Self.same(.Odyssey2, try Self.tokens(.Odyssey2)[.a] ?? "", as: "action"))
    }

    @Test("Virtual Boy: A B L R Start Select and the right-hand d-pad")
    func virtualBoy() throws {
        let tokens = try Self.tokens(.VirtualBoy)
        for (slot, name) in [(OverlayFamilySlot.a, "a"), (.b, "b"), (.l, "l"), (.r, "r"), (.start, "start"),
                             (.select, "select"), (.dpad2Up, "rightUp"), (.dpad2Down, "rightDown"),
                             (.dpad2Left, "rightLeft"), (.dpad2Right, "rightRight")] {
            #expect(Self.same(.VirtualBoy, tokens[slot] ?? "", as: name), "\(name)")
        }
        let left = ["up", "down", "left", "right"].map { Self.button(.VirtualBoy, $0) }
        let right = [OverlayFamilySlot.dpad2Up, .dpad2Down, .dpad2Left, .dpad2Right].map { Self.button(.VirtualBoy, tokens[$0] ?? "") }
        #expect(Set(left + right).count == 8)
    }
}
