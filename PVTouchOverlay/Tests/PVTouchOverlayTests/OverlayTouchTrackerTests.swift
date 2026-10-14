import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Overlay touch tracker")
struct OverlayTouchTrackerTests {
    private static let buttonSize: CGFloat = 56
    private static let hitOutset: CGFloat = 20

    static func control(_ id: String, kind: OverlayControlKind, at origin: CGPoint,
                        size: CGSize = CGSize(width: buttonSize, height: buttonSize)) -> ResolvedControl {
        let frame = CGRect(origin: origin, size: size)
        return ResolvedControl(control: OverlayControl(id: id, kind: kind, frame: .zero, shape: .circle,
                                                       paletteSlot: .primary),
                               frame: frame, hitFrame: frame.insetBy(dx: -hitOutset, dy: -hitOutset))
    }

    static func button(_ id: String, at origin: CGPoint) -> ResolvedControl {
        control(id, kind: .button(OverlayInputID(system: .SNES, token: id)), at: origin)
    }

    static func action(_ action: OverlayAction, at origin: CGPoint) -> ResolvedControl {
        control("action-\(action.rawValue)", kind: .action(action), at: origin,
                size: CGSize(width: 70, height: 30))
    }

    static func center(_ control: ResolvedControl) -> CGPoint { CGPoint(x: control.frame.midX, y: control.frame.midY) }

    // Two face buttons 60pt apart (4pt gap, overlapping hit frames).
    let buttonA = button("a", at: CGPoint(x: 0, y: 0))
    let buttonB = button("b", at: CGPoint(x: 60, y: 0))
    // A row of action pills, 16pt apart, like `OverlayFamilyKit.actionsGroup`.
    let menu = action(.menu, at: CGPoint(x: 0, y: 200))
    let save = action(.quickSave, at: CGPoint(x: 86, y: 200))
    let load = action(.quickLoad, at: CGPoint(x: 172, y: 200))

    private func tracker(_ controls: [ResolvedControl], multiButton: Bool = false) -> OverlayTouchTracker<Int> {
        OverlayTouchTracker(controls: controls, multiButton: multiButton)
    }

    // MARK: - Drag across

    @Test("A finger sliding from one button to the next releases the first and presses the second")
    func dragAcrossButtons() {
        var touches = tracker([buttonA, buttonB])
        touches.began(1, at: Self.center(buttonA))
        #expect(touches.hits() == [.control(id: "a")])
        touches.moved(1, to: Self.center(buttonB))
        #expect(touches.hits() == [.control(id: "b")])
        touches.ended(1)
        #expect(touches.hits().isEmpty)
    }

    @Test("A finger that begins on empty space can slide onto a gameplay button")
    func slideInFromEmptySpace() {
        var touches = tracker([buttonA])
        touches.began(1, at: CGPoint(x: -100, y: -100))
        #expect(touches.hits().isEmpty)
        touches.moved(1, to: Self.center(buttonA))
        #expect(touches.hits() == [.control(id: "a")])
    }

    // MARK: - Lockout

    @Test("Sliding across a row of action pills fires only the one the touch began on")
    func actionRowSlide() {
        var touches = tracker([menu, save, load])
        touches.began(1, at: Self.center(menu))
        #expect(touches.hits() == [.control(id: menu.id)])
        touches.moved(1, to: Self.center(save))
        #expect(touches.hits().isEmpty)
        touches.moved(1, to: Self.center(load))
        #expect(touches.hits().isEmpty)
        // Back onto the pill it began on: still nothing, so an action cannot fire twice.
        touches.moved(1, to: Self.center(menu))
        #expect(touches.hits().isEmpty)
        #expect(touches.owner(of: 1) == .inert)
    }

    @Test("A touch latched to a system control holds it while it stays inside its hit frame")
    func latchedHoldsInside() {
        var touches = tracker([menu, buttonA])
        touches.began(1, at: Self.center(menu))
        touches.moved(1, to: CGPoint(x: menu.hitFrame.maxX - 1, y: menu.frame.midY))
        #expect(touches.hits() == [.control(id: menu.id)])
        #expect(touches.owner(of: 1) == .system(id: menu.id))
    }

    @Test("A gameplay touch sliding onto any system control never presses it")
    func gameplaySlideOntoEverySystemKind() {
        let snes = { (token: String) in OverlayInputID(system: .SNES, token: token) }
        var system: [OverlayControlKind] = [.hardwareSwitch(descriptorID: "left_diff")]
        system += [OverlayAction.menu, .quickSave, .quickLoad, .fastForward, .toggleKeyboard, .toggleMouse,
                   .screenshot, .keypad, .flip, .diskSide, .service].map { .action($0) }
        system += ["leftdiff", "rightdiff", "tvtype", "reset", "home", "service"].map { .button(snes($0)) }
        var targets = system.map { Self.control("target", kind: $0, at: CGPoint(x: 60, y: 0)) }
        // The console Reset pill, whatever its token.
        targets.append(Self.control("reset", kind: .button(snes("r")), at: CGPoint(x: 60, y: 0)))
        for target in targets {
            let kind = target.control.kind
            for multiButton in [false, true] {
                var touches = tracker([buttonA, target], multiButton: multiButton)
                touches.began(1, at: Self.center(buttonA))
                touches.moved(1, to: Self.center(target))
                #expect(!touches.hits().contains(.control(id: target.id)), "\(kind) (multi: \(multiButton))")
            }
        }
    }

    @Test("Where a gameplay and a system hit frame overlap, only the control picked at touch-down fires")
    func overlapAtTouchDown() {
        // Menu's hit frame reaches into A's; the point is nearer A's centre, so A owns the touch.
        let nearMenu = Self.action(.menu, at: CGPoint(x: 60, y: 13))
        var touches = tracker([buttonA, nearMenu])
        let overlap = CGPoint(x: 58, y: 28)
        #expect(buttonA.hitFrame.contains(overlap) && nearMenu.hitFrame.contains(overlap))
        touches.began(1, at: overlap)
        #expect(touches.hits() == [.control(id: "a")])

        // Same point, menu picked: a touch-down inside menu's draw frame wins over A's hit frame.
        let insideMenu = CGPoint(x: 62, y: 28)
        touches.began(2, at: insideMenu)
        #expect(touches.owner(of: 2) == .system(id: nearMenu.id))
        touches.ended(1)
        #expect(touches.hits() == [.control(id: nearMenu.id)])
    }

    @Test("A latch whose control vanishes in a relayout never fires again")
    func vanishedLatch() {
        var touches = tracker([menu, buttonA])
        touches.began(1, at: Self.center(menu))
        touches.controls = [buttonA]
        #expect(touches.hits().isEmpty)
        touches.controls = [menu, buttonA]
        #expect(touches.hits().isEmpty)
    }

    @Test("removeAll drops every touch and latch")
    func removeAll() {
        var touches = tracker([menu, buttonA])
        touches.began(1, at: Self.center(menu))
        touches.began(2, at: Self.center(buttonA))
        touches.removeAll()
        #expect(touches.isEmpty && touches.hits().isEmpty)
    }

    @Test("A system touch and a gameplay touch work side by side")
    func twoFingers() {
        var touches = tracker([menu, buttonA, buttonB], multiButton: true)
        touches.began(1, at: Self.center(buttonA))
        touches.began(2, at: Self.center(menu))
        #expect(touches.hits() == [.control(id: "a"), .control(id: menu.id)])
    }

    // MARK: - Multi-button touch

    @Test("Between two buttons: one press in single mode, both in multi mode")
    func straddle() {
        let between = CGPoint(x: (buttonA.frame.midX + buttonB.frame.midX) / 2, y: buttonA.frame.midY)
        var single = tracker([buttonA, buttonB])
        single.began(1, at: between, radius: 20)
        #expect(single.hits().count == 1)

        var multi = tracker([buttonA, buttonB], multiButton: true)
        multi.began(1, at: between, radius: 20)
        #expect(multi.hits() == [.control(id: "a"), .control(id: "b")])
    }

    @Test("Multi-button touch never adds a system control or a d-pad")
    func multiNeverAddsSystemOrDPad() {
        let snes = { (token: String) in OverlayInputID(system: .SNES, token: token) }
        let home = Self.control("home", kind: .button(snes("home")), at: CGPoint(x: 60, y: 0))
        let dpad = Self.control("dpad", kind: .dpad(up: snes("up"), down: snes("down"), left: snes("left"),
                                                     right: snes("right")),
                                at: CGPoint(x: 0, y: 60))
        var touches = tracker([buttonA, home, dpad], multiButton: true)
        // Inside A, with a contact circle wide enough to cover Home and the d-pad.
        touches.began(1, at: CGPoint(x: 50, y: 50), radius: 40)
        #expect(touches.hits() == [.control(id: "a")])
    }

    @Test("A d-pad winner is never expanded onto a button")
    func dpadWinnerAlone() {
        let snes = { (token: String) in OverlayInputID(system: .SNES, token: token) }
        let dpad = Self.control("dpad", kind: .dpad(up: snes("up"), down: snes("down"), left: snes("left"),
                                                     right: snes("right")),
                                at: CGPoint(x: 0, y: 0), size: CGSize(width: 150, height: 150))
        let nearby = Self.button("a", at: CGPoint(x: 160, y: 47))
        var touches = tracker([dpad, nearby], multiButton: true)
        touches.began(1, at: CGPoint(x: 145, y: 75), radius: 50)
        #expect(touches.hits() == [.dpad(id: "dpad", .right)])
    }
}
