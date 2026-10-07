import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

@Suite("OverlayHitTester")
struct OverlayHitTesterTests {
    static func button(_ name: String, _ frame: CGRect, _ hit: CGRect) -> ResolvedControl {
        ResolvedControl(
            control: OverlayControl(id: name, kind: .button(OverlayInputID(system: .SNES, token: name)),
                                    frame: .zero, shape: .circle, paletteSlot: .primary),
            frame: frame, hitFrame: hit)
    }

    let buttonA = button("a", CGRect(x: 100, y: 100, width: 56, height: 56),
                         CGRect(x: 80, y: 80, width: 96, height: 96))
    let buttonB = button("b", CGRect(x: 150, y: 100, width: 56, height: 56),
                         CGRect(x: 130, y: 80, width: 96, height: 96))
    let dpad = ResolvedControl(
        control: OverlayControl(
            id: "dpad",
            kind: .dpad(up: OverlayInputID(system: .SNES, token: "up"),
                        down: OverlayInputID(system: .SNES, token: "down"),
                        left: OverlayInputID(system: .SNES, token: "left"),
                        right: OverlayInputID(system: .SNES, token: "right")),
            frame: .zero, shape: .cross, paletteSlot: .dpad),
        frame: CGRect(x: 0, y: 0, width: 150, height: 150),
        hitFrame: CGRect(x: -20, y: -20, width: 190, height: 190))

    @Test("Finger inside a draw frame wins over an overlapping hit frame")
    func drawFrameWins() {
        // (160, 128) is inside b's draw frame and inside a's hit frame but not a's draw frame.
        let hits = OverlayHitTester.hits(at: [CGPoint(x: 160, y: 128)], controls: [buttonA, buttonB], previousDPad: [:])
        #expect(hits == [.control(id: "b")])
    }

    @Test("In the overlap of two hit frames the nearest centre wins")
    func nearestCentre() {
        let hits = OverlayHitTester.hits(at: [CGPoint(x: 140, y: 85)], controls: [buttonA, buttonB], previousDPad: [:])
        #expect(hits == [.control(id: "a")])
    }

    @Test("Multiple touches produce the union")
    func union() {
        let touches = [CGPoint(x: 110, y: 110), CGPoint(x: 190, y: 110)]
        let hits = OverlayHitTester.hits(at: touches, controls: [buttonA, buttonB], previousDPad: [:])
        #expect(hits == [.control(id: "a"), .control(id: "b")])
    }

    @Test("D-pad: centre is dead, cardinals and diagonals resolve")
    func dpadOctants() {
        let frame = dpad.frame
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 75, y: 75), in: frame, previous: []) == [])
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 75, y: 10), in: frame, previous: []) == [.up])
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 140, y: 75), in: frame, previous: []) == [.right])
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 135, y: 15), in: frame, previous: []) == [.up, .right])
    }

    @Test("D-pad hysteresis keeps the previous direction near a boundary")
    func dpadHysteresis() {
        let frame = dpad.frame
        // 22.5 degrees is the up/up-right boundary; 26 degrees sits just past it on the up-right side.
        let angle = 26.0 * .pi / 180
        let point = CGPoint(x: 75 + 60 * sin(angle), y: 75 - 60 * cos(angle))
        #expect(OverlayHitTester.dpadDirections(point: point, in: frame, previous: [.up]) == [.up])
        #expect(OverlayHitTester.dpadDirections(point: point, in: frame, previous: []) == [.up, .right])
    }
}
