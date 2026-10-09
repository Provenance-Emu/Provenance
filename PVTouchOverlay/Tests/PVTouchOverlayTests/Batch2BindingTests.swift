import Foundation
import Testing
import PVCoreBridge
import PVSystems
@testable import PVTouchOverlay

/// Batch 2: Sega, NEC, SNK, Sony and the smaller consoles.
@Suite("Batch 2 bindings")
struct Batch2BindingTests {
    private static func binding(_ system: SystemIdentifier) throws -> SystemOverlayBinding {
        try #require(SystemOverlayBindings.binding(for: system))
    }

    private static func template(_ system: SystemIdentifier, subtype: String = OverlayPadKind.standardSubtype,
                                 _ orientation: OverlayOrientation = .portrait) throws -> OverlayTemplate {
        try binding(system).template(padKind: OverlayPadKind(system: system, subtype: subtype),
                                     orientation: orientation)
    }

    private static func controls(_ template: OverlayTemplate) -> [OverlayControl] {
        template.groups.flatMap(\.controls)
    }

    private static func family(_ system: SystemIdentifier, _ subtype: String? = nil) throws -> String {
        let binding = try binding(system)
        return binding.family(for: subtype ?? binding.defaultSubtype).id
    }

    // MARK: Families and subtypes

    @Test("Each batch 2 system binds the family the spec names")
    func families() throws {
        #expect(try Self.family(.Saturn) == SixFaceFamily.id)
        #expect(try Self.family(.Dreamcast) == FourFaceFamily.id)
        #expect(try Self.family(.Dreamcast, "dreamcast-arcade") == ArcadeStickFamily.id)
        for system in [SystemIdentifier.PCE, .SGFX, .PCECD] {
            #expect(try Self.family(system) == TwoButtonFamily.id, "\(system)")
            #expect(try Self.family(system, "pce-6btn") == SixFaceFamily.id, "\(system)")
        }
        #expect(try Self.family(.PCFX) == SixFaceFamily.id)
        for system in [SystemIdentifier.NGP, .NGPC, .Odyssey2, .CDi] {
            #expect(try Self.family(system) == TwoButtonFamily.id, "\(system)")
        }
        for system in [SystemIdentifier.WonderSwan, .WonderSwanColor] {
            #expect(try Self.family(system) == DualDPadFamily.id && Self.family(system, "ws-vertical") == DualDPadFamily.id)
        }
        #expect(try Self.family(.VirtualBoy) == DualDPadFamily.id)
        for system in [SystemIdentifier.PS2, .PS3] {
            #expect(try Self.family(system) == DualStickFamily.id, "\(system)")
        }
        #expect(try Self.family(.PSP) == DigitalPadFamily.id)
        #expect(try Self.family(.Vectrex) == FourFaceFamily.id)
    }

    @Test("Selectable subtypes exist as controller layout variants, default first")
    func subtypesAreVariants() throws {
        let cases: [(SystemIdentifier, [String])] = [
            (.Dreamcast, ["dreamcast-standard", "dreamcast-arcade"]),
            (.PCE, ["pce-2btn", "pce-6btn"]), (.SGFX, ["pce-2btn", "pce-6btn"]), (.PCECD, ["pce-2btn", "pce-6btn"]),
            (.WonderSwan, ["ws-horizontal", "ws-vertical"]), (.WonderSwanColor, ["ws-horizontal", "ws-vertical"])
        ]
        for (system, ids) in cases {
            #expect(system.availableControllerLayoutVariants?.map(\.id) == ids, "\(system)")
            let binding = try Self.binding(system)
            #expect(Set(binding.families.keys) == Set(ids), "\(system)")
            #expect(binding.defaultSubtype == ids[0], "\(system)")
        }
    }

    // MARK: Hidden slots and extras

    @Test("Saturn draws six face buttons, L and R, and Start only")
    func saturn() throws {
        let ids = OverlayTestSupport.controlIDs(try Self.template(.Saturn))
        #expect(ids.isSuperset(of: ["a", "b", "c", "x", "y", "z", "l", "r", "start", "dpad"]))
        #expect(!ids.contains("select"))
    }

    @Test("Genesis still draws no shoulders now that SixFace can")
    func genesisHasNoShoulders() throws {
        let ids = OverlayTestSupport.controlIDs(try Self.template(.Genesis, subtype: "genesis-6btn"))
        #expect(!ids.contains("l") && !ids.contains("r"))
    }

    @Test("Dreamcast: diamond A bottom, B right, X left, Y top; analog L R; one stick; no select")
    func dreamcast() throws {
        for orientation in OverlayOrientation.allCases {
            let template = try Self.template(.Dreamcast, subtype: "dreamcast-standard", orientation)
            let all = Self.controls(template)
            func frame(_ id: String) throws -> CGRect { try #require(all.first { $0.id == id }).frame }
            let a = try frame("a"), b = try frame("b"), x = try frame("x"), y = try frame("y")
            #expect(a.midY > b.midY && a.midY > x.midY && y.midY < b.midY && y.midY < x.midY, "\(orientation)")
            #expect(b.midX > a.midX && x.midX < a.midX && y.midX == a.midX, "\(orientation)")
            for id in ["l", "r"] {
                let trigger = try #require(all.first { $0.id == id })
                guard case .analogTrigger = trigger.kind else {
                    Issue.record("Dreamcast \(id) is \(trigger.kind), not an analog trigger")
                    continue
                }
            }
            let sticks = all.filter { if case .stick = $0.kind { return true } else { return false } }
            #expect(sticks.count == 1 && sticks.first?.id == "leftStick", "\(orientation)")
            #expect(!all.contains { $0.id == "select" })
        }
    }

    @Test("Dreamcast arcade draws A B X Y and a stick, no triggers")
    func dreamcastArcade() throws {
        let ids = OverlayTestSupport.controlIDs(try Self.template(.Dreamcast, subtype: "dreamcast-arcade"))
        #expect(ids.isSuperset(of: ["a", "b", "x", "y", "start", "dpad"]))
        #expect(ids.isDisjoint(with: ["c", "z", "l", "r", "coin"]))
    }

    @Test("The face diamond of the other FourFace pads is unchanged")
    func superNintendoDiamond() throws {
        let all = Self.controls(try Self.template(.Vectrex, .portrait))
        func frame(_ id: String) throws -> CGRect { try #require(all.first { $0.id == id }).frame }
        #expect(try frame("x").midY < frame("a").midY && frame("b").midY > frame("a").midY)
    }

    @Test("PC Engine: two buttons draw II left of I; the 6-button pad draws I-VI; Run and Select only")
    func pcEngine() throws {
        for system in [SystemIdentifier.PCE, .SGFX, .PCECD] {
            let two = Self.controls(try Self.template(system, subtype: "pce-2btn"))
            let ids = Set(two.map(\.id))
            #expect(ids.isSuperset(of: ["a", "b", "start", "select"]) && ids.isDisjoint(with: ["c", "x", "y", "z"]), "\(system)")
            let one = try #require(two.first { $0.id == "a" }), twoButton = try #require(two.first { $0.id == "b" })
            #expect(one.label == "I" && twoButton.label == "II" && twoButton.frame.minX < one.frame.minX, "\(system)")
            let six = OverlayTestSupport.controlIDs(try Self.template(system, subtype: "pce-6btn"))
            #expect(six.isSuperset(of: ["a", "b", "c", "x", "y", "z", "start", "select"]), "\(system)")
        }
        let fx = OverlayTestSupport.controlIDs(try Self.template(.PCFX))
        #expect(fx.isSuperset(of: ["a", "b", "c", "x", "y", "z", "start", "select"]))
    }

    @Test("Neo Geo Pocket and WonderSwan Color share the pocket pads: A B and one system button")
    func pocketPads() throws {
        for system in [SystemIdentifier.NGP, .NGPC] {
            let template = try Self.template(system)
            let ids = OverlayTestSupport.controlIDs(template)
            #expect(ids.isSuperset(of: ["a", "b", "start"]) && !ids.contains("select"), "\(system)")
            #expect(Self.controls(template).first { $0.id == "start" }?.label == "OPTION", "\(system)")
        }
    }

    @Test("Odyssey 2 draws one Action button and CD-i two buttons, with no system pills")
    func singleButtonPads() throws {
        let odyssey = Self.controls(try Self.template(.Odyssey2))
        #expect(Set(odyssey.map(\.id)) == ["dpad", "a"])
        let cdi = Self.controls(try Self.template(.CDi))
        #expect(Set(cdi.map(\.id)) == ["dpad", "a", "b"])
    }

    @Test("PSP has a d-pad, ✕ ○ △ □, L R, Start, Select and one stick, nothing else")
    func psp() throws {
        for orientation in OverlayOrientation.allCases {
            let all = Self.controls(try Self.template(.PSP, orientation))
            let ids = Set(all.map(\.id))
            #expect(ids == ["dpad", "a", "b", "x", "y", "l", "r", "start", "select", "leftStick"], "\(orientation) \(ids)")
        }
    }

    @Test("PS2 and PS3 draw the DualShock layout with both sticks")
    func playStation2() throws {
        for system in [SystemIdentifier.PS2, .PS3] {
            let ids = OverlayTestSupport.controlIDs(try Self.template(system))
            #expect(ids.isSuperset(of: ["leftStick", "rightStick", "l", "r", "l2", "r2", "start", "select"]), "\(system)")
        }
    }

    @Test("Vectrex draws four numbered buttons and no shoulders or system pills")
    func vectrex() throws {
        let all = Self.controls(try Self.template(.Vectrex))
        #expect(Set(all.map(\.id)) == ["dpad", "a", "b", "x", "y"])
        #expect(all.compactMap(\.label).sorted() == ["1", "2", "3", "4"])
    }

    @Test("Dual d-pad pads press the Y cluster on the second d-pad, the right-hand Virtual Boy pad on its own")
    func secondDPads() throws {
        for system in [SystemIdentifier.WonderSwan, .WonderSwanColor, .VirtualBoy] {
            let template = try Self.template(system, .landscape)
            let pad = try #require(Self.controls(template).first { $0.id == "dpad2" })
            guard case .dpad(let up, let down, let left, let right) = pad.kind else {
                Issue.record("\(system) dpad2 is not a d-pad")
                continue
            }
            let tokens = [up, down, left, right].map(\.token)
            #expect(tokens == (system == .VirtualBoy ? ["rightUp", "rightDown", "rightLeft", "rightRight"]
                                                     : ["y1", "y3", "y4", "y2"]), "\(system)")
        }
    }

    // MARK: Orientation and screen policy

    @Test("Tall-screen pads keep the portrait template: a tall picture fits the top band")
    func tallScreens() throws {
        // Vectrex, Virtual Boy and the vertical WonderSwan have tall pictures. Forcing the landscape
        // template on a portrait phone left a ~40pt centre column, so they use the normal portrait
        // top band, where the planner aspect-fits the tall picture from the core's aspect.
        let tall: [(SystemIdentifier, String)] = [
            (.WonderSwan, "ws-vertical"), (.WonderSwanColor, "ws-vertical"),
            (.VirtualBoy, OverlayPadKind.standardSubtype), (.Vectrex, OverlayPadKind.standardSubtype)
        ]
        for (system, subtype) in tall {
            let template = try Self.template(system, subtype: subtype, .portrait)
            #expect(template.orientation == .portrait && template.screenPolicy == .topBand, "\(system)")
        }
    }

    @Test("WonderSwan horizontal follows the device orientation")
    func wonderSwanHorizontal() throws {
        for system in [SystemIdentifier.WonderSwan, .WonderSwanColor] {
            let portrait = try Self.template(system, subtype: "ws-horizontal", .portrait)
            #expect(portrait.orientation == .portrait && portrait.screenPolicy == .topBand, "\(system)")
            let landscape = try Self.template(system, subtype: "ws-horizontal", .landscape)
            #expect(landscape.screenPolicy == .centerColumn, "\(system)")
        }
    }

    @Test("Every other batch 2 system keeps the top band in portrait")
    func topBand() throws {
        for system in SystemOverlayBindings.batch2Systems {
            let binding = try Self.binding(system)
            let template = try Self.template(system, subtype: binding.defaultSubtype, .portrait)
            #expect(template.screenPolicy == .topBand, "\(system)")
        }
    }
}
