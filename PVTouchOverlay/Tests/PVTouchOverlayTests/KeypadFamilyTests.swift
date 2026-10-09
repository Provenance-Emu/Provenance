import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Keypad family")
struct KeypadFamilyTests {
    private static func jaguar(orientation: OverlayOrientation) throws -> OverlayTemplate {
        let binding = try #require(SystemOverlayBindings.binding(for: .AtariJaguar))
        return binding.template(padKind: .standard(.AtariJaguar), orientation: orientation)
    }

    @Test("The keypad is a toggled group of twelve keys in 3x4 reading order")
    func keypadGroup() throws {
        let template = try Self.jaguar(orientation: .portrait)
        let keypad = try #require(template.groups.first { $0.id == "keypad" })
        #expect(keypad.toggledBy == .keypad)
        #expect(keypad.controls.map(\.id) == ["k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "kStar", "k0", "kPound"])
        let first = try #require(keypad.controls.first), last = try #require(keypad.controls.last)
        #expect(first.frame.origin == .zero)
        #expect(last.frame.minX > first.frame.minX && last.frame.minY > first.frame.minY)
        #expect(Set(keypad.controls.map(\.frame.minX)).count == 3 && Set(keypad.controls.map(\.frame.minY)).count == 4)
    }

    @Test("A pill in the system row carries the keypad action")
    func togglePill() throws {
        let template = try Self.jaguar(orientation: .portrait)
        let system = try #require(template.groups.first { $0.id == "system" })
        #expect(system.controls.contains { $0.kind == .action(.keypad) })
    }

    @Test("A pad with no console buttons still gets a system row for the keypad pill")
    func keypadOnlySystemRow() throws {
        let binding = try #require(SystemOverlayBindings.binding(for: .ColecoVision))
        let template = binding.template(padKind: .standard(.ColecoVision), orientation: .portrait)
        let system = try #require(template.groups.first { $0.id == "system" })
        #expect(system.controls.map(\.id) == ["action-keypad"])
    }

    @Test("While the keypad is off nothing is laid out for it; while on, it is a group")
    func toggleVisibility() throws {
        let template = try Self.jaguar(orientation: .portrait)
        let canvas = OverlayLayoutEngineTests.phonePortrait
        let off = OverlayTestSupport.resolve(template, on: canvas)
        let on = OverlayTestSupport.resolve(template, on: canvas, shownToggles: [.keypad])
        #expect(!off.groups.contains { $0.id == "keypad" })
        #expect(on.groups.contains { $0.id == "keypad" })
        #expect(on.groups.count == off.groups.count + 1)
    }

    @Test("The picture does not move for a keypad that is shown: it floats over the picture",
          arguments: [SystemIdentifier.Atari5200, .AtariJaguar, .ColecoVision, .Intellivision])
    func keypadReservesNothing(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for canvas in OverlayTestSupport.canvases {
            let template = binding.template(padKind: .standard(system), orientation: canvas.orientation)
            let off = OverlayTestSupport.resolve(template, on: canvas)
            let on = OverlayTestSupport.resolve(template, on: canvas, shownToggles: [.keypad])
            #expect(off.screenFrames == on.screenFrames, "\(system) \(canvas.size)")
            #expect(off.screenFrames.allSatisfy { $0.width > 100 && $0.height > 60 }, "\(system) \(canvas.size)")
        }
    }

    @Test("Both toggle states keep every group on the canvas with no overlapping controls",
          arguments: [SystemIdentifier.Atari5200, .AtariJaguar, .ColecoVision, .Intellivision])
    func noOverlap(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for canvas in OverlayTestSupport.canvases {
            let template = binding.template(padKind: .standard(system), orientation: canvas.orientation)
            for toggles in [Set<OverlayAction>(), [.keypad]] {
                let layout = OverlayTestSupport.resolve(template, on: canvas, shownToggles: toggles)
                #expect(OverlayTestSupport.offCanvas(layout, canvas: canvas).isEmpty, "\(system) \(canvas.size)")
                #expect(OverlayTestSupport.overlaps(in: layout).isEmpty,
                        "\(system) \(canvas.size) \(toggles): \(OverlayTestSupport.overlaps(in: layout))")
            }
        }
    }

    @Test("Hidden fire and console slots leave no control: ColecoVision has two fire buttons and no Start")
    func colecoSlots() throws {
        let binding = try #require(SystemOverlayBindings.binding(for: .ColecoVision))
        let ids = OverlayTestSupport.controlIDs(binding.template(padKind: .standard(.ColecoVision), orientation: .portrait))
        #expect(ids.isSuperset(of: ["a", "b", "dpad"]))
        #expect(ids.isDisjoint(with: ["c", "start", "select", "reset"]))
    }

    @Test("The editor sees the keypad: with it shown the group is movable and the dispatcher knows its keys")
    func keyControlsAreButtons() throws {
        let template = try Self.jaguar(orientation: .landscape)
        let keypad = try #require(template.groups.first { $0.id == "keypad" })
        for control in keypad.controls {
            guard case .button(let token) = control.kind else {
                Issue.record("\(control.id) is not a button")
                continue
            }
            #expect(token.system == .AtariJaguar)
        }
    }
}
