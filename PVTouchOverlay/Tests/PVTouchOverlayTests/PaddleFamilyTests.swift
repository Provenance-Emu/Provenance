import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Paddle family")
struct PaddleFamilyTests {
    private static let binding = SystemOverlayBinding(
        system: .Atari2600, families: [OverlayPadKind.standardSubtype: PaddleFamily.self],
        defaultSubtype: OverlayPadKind.standardSubtype,
        tokens: [.a: "fire1", .start: "start", .select: "select"], labels: [:], palette: .atari,
        hardwareSwitches: ["left_diff", "right_diff", "color_bw"])

    @Test("The paddle is one left stick limited to the x axis, with no click")
    func slider() throws {
        let template = Self.binding.template(padKind: .standard(.Atari2600), orientation: .portrait)
        let stick = try #require(template.groups.first { $0.id == "paddle" }?.controls.first)
        #expect(stick.kind == .stick(.left, click: nil))
        #expect(stick.axis == .horizontal)
        #expect(stick.frame.width > stick.frame.height)
    }

    @Test("A horizontal stick drops the vertical component; a free stick keeps both")
    func constrainedAxis() {
        let horizontal = OverlayStickAxis.horizontal.constrained(x: 0.5, y: -0.75)
        #expect(horizontal.x == 0.5 && horizontal.y == 0)
        let free = OverlayStickAxis.both.constrained(x: 0.5, y: -0.75)
        #expect(free.x == 0.5 && free.y == -0.75)
    }

    @Test("Fire is the only face button when B has no token")
    func oneFireButton() throws {
        let template = Self.binding.template(padKind: .standard(.Atari2600), orientation: .portrait)
        let face = try #require(template.groups.first { $0.id == "face" })
        #expect(face.controls.map(\.id) == ["a"])
    }

    @Test("The console switches draw as pills that send the latch tokens")
    func switches() throws {
        let template = Self.binding.template(padKind: .standard(.Atari2600), orientation: .portrait)
        let group = try #require(template.groups.first { $0.id == "switches" })
        #expect(group.controls.compactMap { control -> String? in
            if case .button(let token) = control.kind { return token.token }
            return nil
        } == ["leftdiff", "rightdiff", "tvtype"])
    }

    @Test("Fits every canvas with no overlap")
    func noOverlap() {
        for canvas in OverlayTestSupport.canvases {
            let template = Self.binding.template(padKind: .standard(.Atari2600), orientation: canvas.orientation)
            let layout = OverlayTestSupport.resolve(template, on: canvas)
            #expect(OverlayTestSupport.offCanvas(layout, canvas: canvas).isEmpty, "\(canvas.size)")
            #expect(OverlayTestSupport.overlaps(in: layout).isEmpty,
                    "\(canvas.size): \(OverlayTestSupport.overlaps(in: layout))")
        }
    }

    @Test("The 2600 joystick pad shows RESET, SELECT, the three switches and one fire button")
    func joystick2600() throws {
        let binding = try #require(SystemOverlayBindings.binding(for: .Atari2600))
        let ids = OverlayTestSupport.controlIDs(binding.template(padKind: .standard(.Atari2600), orientation: .portrait))
        #expect(ids.isSuperset(of: ["a", "start", "select", "dpad", "switch-left_diff", "switch-right_diff", "switch-color_bw"]))
        #expect(!ids.contains("b"))
        for canvas in OverlayTestSupport.canvases {
            let layout = OverlayTestSupport.resolve(binding.template(padKind: .standard(.Atari2600),
                                                                     orientation: canvas.orientation), on: canvas)
            #expect(OverlayTestSupport.overlaps(in: layout).isEmpty, "\(canvas.size): \(OverlayTestSupport.overlaps(in: layout))")
        }
    }
}
