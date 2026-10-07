import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

final class RecordingSink: OverlayInputSink {
    var log: [String] = []
    func overlayPress(_ id: OverlayInputID) { log.append("press \(id.token)") }
    func overlayRelease(_ id: OverlayInputID) { log.append("release \(id.token)") }
    func overlayStick(_ side: OverlayStickSide, x: Float, y: Float) { log.append("stick \(side.rawValue) \(x) \(y)") }
    func overlayAnalogTrigger(_ id: OverlayInputID, value: Float) { log.append("trigger \(id.token) \(value)") }
    func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase) {
        log.append("surface \(role.rawValue) \(phase)")
    }
    func overlayAction(_ action: OverlayAction) { log.append("action \(action.rawValue)") }
    func overlayHardwareSwitch(descriptorID: String, isOn: Bool) { log.append("switch \(descriptorID) \(isOn)") }
}

@Suite("OverlayHitDispatcher")
struct OverlayHostDispatchTests {
    let snes = SystemIdentifier.SNES

    private func input(_ token: String) -> OverlayInputID { OverlayInputID(system: snes, token: token) }

    var controls: [OverlayControl] {
        [OverlayControl(id: "a", kind: .button(input("a")), frame: .zero, shape: .circle, paletteSlot: .primary),
         OverlayControl(id: "b", kind: .button(input("b")), frame: .zero, shape: .circle, paletteSlot: .secondary),
         OverlayControl(id: "dpad",
                        kind: .dpad(up: input("up"), down: input("down"), left: input("left"), right: input("right")),
                        frame: .zero, shape: .cross, paletteSlot: .dpad),
         OverlayControl(id: "l", kind: .analogTrigger(input("l")), frame: .zero, shape: .bar, paletteSlot: .utility),
         OverlayControl(id: "menu", kind: .action(.menu), frame: .zero, shape: .pill, paletteSlot: .utility)]
    }

    @Test("Releases are emitted before presses and only deltas are sent")
    func deltas() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.control(id: "a")], from: "g")
        dispatcher.apply([.control(id: "a"), .control(id: "b")], from: "g")
        dispatcher.apply([.control(id: "b")], from: "g")
        #expect(sink.log == ["press a", "press b", "release a"])
    }

    @Test("Releases come before presses within one transition")
    func releaseBeforePress() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.control(id: "a")], from: "g")
        dispatcher.apply([.control(id: "b")], from: "g")
        #expect(sink.log == ["press a", "release a", "press b"])
    }

    @Test("D-pad directions map to their tokens and a diagonal presses two")
    func dpad() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.dpad(id: "dpad", .up), .dpad(id: "dpad", .right)], from: "g")
        #expect(sink.log == ["press up", "press right"])
        dispatcher.apply([], from: "g")
        #expect(Array(sink.log.suffix(2)) == ["release up", "release right"])
    }

    @Test("Analog triggers send 1 then 0; actions fire on touch-down only")
    func triggerAndAction() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.control(id: "l"), .control(id: "menu")], from: "g")
        dispatcher.apply([], from: "g")
        #expect(sink.log == ["trigger l 1.0", "action menu", "trigger l 0.0"])
    }

    @Test("releaseAll clears held inputs")
    func releaseAll() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.control(id: "a")], from: "g")
        dispatcher.releaseAll()
        #expect(sink.log == ["press a", "release a"])
    }

    @Test("Hits from separate sources are unioned: a second surface does not release the first")
    func perSourceUnion() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.dpad(id: "dpad", .right)], from: "dpad")
        dispatcher.apply([.control(id: "a")], from: "face")
        #expect(sink.log == ["press right", "press a"])
        dispatcher.apply([], from: "face")
        #expect(sink.log == ["press right", "press a", "release a"])
    }

    @Test("A token shared by two held controls is released only when both let go")
    func sharedTokenRefCount() {
        let sink = RecordingSink()
        let shared = [
            OverlayControl(id: "a1", kind: .button(input("a")), frame: .zero, shape: .circle, paletteSlot: .primary),
            OverlayControl(id: "a2", kind: .button(input("a")), frame: .zero, shape: .circle, paletteSlot: .primary)
        ]
        let dispatcher = OverlayHitDispatcher(controls: shared, sink: sink)
        dispatcher.apply([.control(id: "a1"), .control(id: "a2")], from: "g")
        dispatcher.apply([.control(id: "a2")], from: "g")
        #expect(sink.log == ["press a"])
        dispatcher.apply([], from: "g")
        #expect(sink.log == ["press a", "release a"])
    }

    @Test("update(controls:) releases held hits whose controls vanished")
    func updateReleasesVanished() {
        let sink = RecordingSink()
        let dispatcher = OverlayHitDispatcher(controls: controls, sink: sink)
        dispatcher.apply([.control(id: "a"), .control(id: "b")], from: "g")
        dispatcher.update(controls: controls.filter { $0.id != "a" })
        #expect(sink.log == ["press a", "press b", "release a"])
        dispatcher.apply([], from: "g")
        #expect(sink.log.last == "release b")
    }
}
