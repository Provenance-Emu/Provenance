import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Bindings resolve")
struct BindingResolvesTests {
    private static func screenCount(_ policy: OverlayScreenPolicy) -> Int {
        switch policy {
        case .dualStacked, .dualStacked3DS: return 2
        case .topBand, .centerColumn, .fill: return 1
        }
    }

    @Test("Every binding, subtype and orientation lays out inside the canvas with the screens its policy promises",
          arguments: SystemOverlayBindings.boundSystems)
    func resolves(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for subtype in binding.families.keys {
            for canvas in OverlayTestSupport.canvases {
                for toggles in [Set<OverlayAction>(), [.keypad]] {
                    let template = binding.template(padKind: OverlayPadKind(system: system, subtype: subtype),
                                                    orientation: canvas.orientation)
                    let layout = OverlayTestSupport.resolve(template, on: canvas, shownToggles: toggles)
                    let name = "\(system) \(subtype) \(canvas.size) toggles=\(toggles)"
                    #expect(layout.screenFrames.count == Self.screenCount(template.screenPolicy), "\(name) screens")
                    #expect(layout.screenFrames.allSatisfy { $0.width > 0 && $0.height > 0 }, "\(name) empty screen \(layout.screenFrames)")
                    #expect(OverlayTestSupport.offCanvas(layout, canvas: canvas).isEmpty, "\(name) off canvas")
                    #expect(OverlayTestSupport.overlaps(in: layout).isEmpty,
                            "\(name) overlaps: \(OverlayTestSupport.overlaps(in: layout))")
                }
            }
        }
    }

    @Test("Every control's token belongs to the binding's system and no hidden slot is drawn",
          arguments: SystemOverlayBindings.boundSystems)
    func controlsAreTokenised(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for subtype in binding.families.keys {
            let template = binding.template(padKind: OverlayPadKind(system: system, subtype: subtype),
                                            orientation: .landscape)
            for control in template.groups.flatMap(\.controls) {
                switch control.kind {
                case .button(let token), .analogTrigger(let token):
                    #expect(token.system == system, "\(system) \(subtype) \(control.id) is tagged \(token.system)")
                    #expect(!binding.isHidden(OverlayFamilySlot(rawValue: control.id)),
                            "\(system) \(subtype) draws hidden slot \(control.id)")
                case .dpad(let up, let down, let left, let right):
                    #expect([up, down, left, right].allSatisfy { $0.system == system })
                default:
                    break
                }
            }
        }
    }

    @Test("Batch 1 binds the Keypad, Arcade stick and Atari pads to the families the spec names")
    func batch1Families() throws {
        func family(_ system: SystemIdentifier) throws -> String {
            let binding = try #require(SystemOverlayBindings.binding(for: system))
            return binding.family(for: binding.defaultSubtype).id
        }
        for system in [SystemIdentifier.Atari5200, .AtariJaguar, .AtariJaguarCD, .ColecoVision, .Intellivision] {
            #expect(try family(system) == KeypadFamily.id, "\(system)")
        }
        for system in [SystemIdentifier.MAME, .CPS1, .CPS2, .CPS3, .NeoGeo, .NeoGeoCD, .NAOMI, .NAOMI2, .Atomiswave] {
            #expect(try family(system) == ArcadeStickFamily.id, "\(system)")
        }
        #expect(try family(.Atari2600) == TwoButtonFamily.id)
        #expect(try family(.Atari7800) == TwoButtonFamily.id)
    }

    @Test("Atari 5200 offers the joystick-only variant as a TwoButton pad")
    func atari5200Variants() throws {
        let binding = try #require(SystemOverlayBindings.binding(for: .Atari5200))
        #expect(binding.defaultSubtype == "5200-joystick")
        #expect(binding.families["5200-joystick-only"]?.id == TwoButtonFamily.id)
    }
}
