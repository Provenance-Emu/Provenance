import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Dual d-pad family")
struct DualDPadFamilyTests {
    private static func binding(landscapeOnly: Bool = false) -> SystemOverlayBinding {
        SystemOverlayBinding(
            system: .VirtualBoy, families: [OverlayPadKind.standardSubtype: DualDPadFamily.self],
            defaultSubtype: OverlayPadKind.standardSubtype,
            tokens: [.a: "a", .b: "b", .l: "l", .r: "r", .start: "start", .select: "select",
                     .dpad2Up: "rightUp", .dpad2Down: "rightDown", .dpad2Left: "rightLeft", .dpad2Right: "rightRight"],
            labels: [:], palette: .snes, hardwareSwitches: [], landscapeOnly: landscapeOnly)
    }

    @Test("Two d-pads with their own tokens, the second above the face buttons")
    func twoDPads() throws {
        let canvas = OverlayLayoutEngineTests.phonePortrait
        let template = Self.binding().template(padKind: .standard(.VirtualBoy), orientation: .portrait)
        let layout = OverlayTestSupport.resolve(template, on: canvas)
        let first = try #require(layout.groups.first { $0.id == "dpad" }?.controls.first)
        let second = try #require(layout.groups.first { $0.id == "dpad2" }?.controls.first)
        guard case .dpad(let up1, _, _, _) = first.control.kind, case .dpad(let up2, _, _, _) = second.control.kind else {
            Issue.record("not d-pads")
            return
        }
        #expect(up1.token == "up" && up2.token == "rightUp")
        let face = try #require(layout.groups.first { $0.id == "face" })
        #expect(second.frame.maxY <= face.frame.minY)
    }

    @Test("Fits every canvas with no overlap")
    func noOverlap() {
        for canvas in OverlayTestSupport.canvases {
            let template = Self.binding().template(padKind: .standard(.VirtualBoy), orientation: canvas.orientation)
            let layout = OverlayTestSupport.resolve(template, on: canvas)
            #expect(OverlayTestSupport.offCanvas(layout, canvas: canvas).isEmpty, "\(canvas.size)")
            #expect(OverlayTestSupport.overlaps(in: layout).isEmpty,
                    "\(canvas.size): \(OverlayTestSupport.overlaps(in: layout))")
        }
    }

    @Test("landscapeOnly draws the landscape template, with the centre-column picture, in portrait")
    func landscapeOnly() {
        let template = Self.binding(landscapeOnly: true).template(padKind: .standard(.VirtualBoy), orientation: .portrait)
        #expect(template.orientation == .landscape)
        #expect(template.screenPolicy == .centerColumn)
        let layout = OverlayTestSupport.resolve(template, on: OverlayLayoutEngineTests.phonePortrait)
        #expect(layout.orientation == .landscape)
        #expect(layout.screenFrames.count == 1)
    }

    @Test("Without the flag a portrait canvas gets the portrait template")
    func portraitByDefault() {
        let template = Self.binding().template(padKind: .standard(.VirtualBoy), orientation: .portrait)
        #expect(template.orientation == .portrait && template.screenPolicy == .topBand)
    }

    @Test("effectiveOrientation follows the flag")
    func effectiveOrientation() {
        #expect(Self.binding(landscapeOnly: true).effectiveOrientation(for: .portrait) == .landscape)
        #expect(Self.binding().effectiveOrientation(for: .portrait) == .portrait)
    }
}
