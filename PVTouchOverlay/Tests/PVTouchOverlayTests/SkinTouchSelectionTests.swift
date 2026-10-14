import Foundation
import Testing
@testable import PVTouchOverlay

/// Ported from iFly's `SkinMultiButtonTouchTests`, plus the slide-in lockout for every system control.
@Suite("Skin touch selection")
struct SkinTouchSelectionTests {
    private func candidate(_ id: String, distance: CGFloat, dpad: Bool = false, stick: Bool = false,
                           role: TouchInputRole? = nil) -> SkinTouchCandidate {
        SkinTouchCandidate(id: id, command: id, distance: distance, isDPad: dpad, isThumbstick: stick,
                           role: role ?? TouchInputClassifier.role(forToken: id))
    }

    /// Every kind of non-gameplay control a skin can carry.
    static let systemTokens = [
        "menu", "quickSave", "quickLoad", "fastForward", "toggleFastForward", "slowMotion", "screenshot",
        "restart", "quit", "savestates", "cheats", "skins", "filters", "speedmenu", "toggleAnalog",
        "swapDiscs", "coreOptions", "info", "reverseScreens", "haptics", "controllers", "orientation",
        "resolution", "leftDifficulty", "tvType", "color", "home", "service", "test"
    ]

    // MARK: - Closest wins / multi-button

    @Test("Single mode picks only the closest")
    func singleModePicksClosest() {
        let resolution = SkinTouchSelection.resolve(
            [candidate("a", distance: 12), candidate("b", distance: 5), candidate("x", distance: 30)],
            multiButton: false, isTouchBegin: true)
        #expect(resolution.primary?.id == "b")
        #expect(resolution.commands == ["b"])
    }

    @Test("Multi mode presses every gameplay button under the touch")
    func multiModePressesEveryGameplayButton() {
        let resolution = SkinTouchSelection.resolve(
            [candidate("a", distance: 12), candidate("b", distance: 5)], multiButton: true, isTouchBegin: true)
        #expect(resolution.primary?.id == "b")
        #expect(resolution.commands == ["a", "b"])
        #expect(!resolution.latchesToSystem)
    }

    @Test("Multi mode keeps a d-pad or stick winner alone")
    func dpadAndStickStayAlone() {
        let dpad = SkinTouchSelection.resolve(
            [candidate("dpad", distance: 4, dpad: true), candidate("a", distance: 30)],
            multiButton: true, isTouchBegin: true)
        #expect(dpad.primary?.id == "dpad")
        #expect(dpad.pressed.isEmpty)

        let stick = SkinTouchSelection.resolve(
            [candidate("stick", distance: 4, stick: true), candidate("a", distance: 12)],
            multiButton: true, isTouchBegin: true)
        #expect(stick.primary?.id == "stick")
        #expect(stick.pressed.isEmpty)
    }

    @Test("A d-pad never joins a button multi-press")
    func dpadDoesNotJoin() {
        // The button is much closer than the d-pad, so it wins; the d-pad is not added.
        let resolution = SkinTouchSelection.resolve(
            [candidate("dpad", distance: 40, dpad: true), candidate("a", distance: 5), candidate("b", distance: 8)],
            multiButton: true, isTouchBegin: true)
        #expect(resolution.primary?.id == "a")
        #expect(resolution.commands == ["a", "b"])
    }

    @Test("No candidates yields nothing")
    func noCandidates() {
        let resolution = SkinTouchSelection.resolve([], multiButton: true, isTouchBegin: false)
        #expect(resolution.primary == nil)
        #expect(resolution.pressed.isEmpty && resolution.commands.isEmpty)
    }

    // MARK: - Lockout

    @Test("A slide never reaches a system control, in either mode")
    func slideNeverReachesSystem() {
        for token in Self.systemTokens {
            for multiButton in [false, true] {
                // Alone under the finger: nothing is pressed.
                let alone = SkinTouchSelection.resolve([candidate(token, distance: 1)], multiButton: multiButton,
                                                       isTouchBegin: false)
                #expect(alone.primary == nil, "\(token) pressed by a slide (multi: \(multiButton))")
                // Closer than a gameplay button: the gameplay button wins.
                let mixed = SkinTouchSelection.resolve([candidate(token, distance: 1), candidate("a", distance: 9)],
                                                       multiButton: multiButton, isTouchBegin: false)
                #expect(mixed.commands == ["a"], "\(token) pressed by a slide (multi: \(multiButton))")
            }
        }
    }

    @Test("A touch that begins on a system control presses it alone and latches")
    func touchDownOnSystemLatches() {
        for token in Self.systemTokens {
            for multiButton in [false, true] {
                let resolution = SkinTouchSelection.resolve(
                    [candidate(token, distance: 2), candidate("a", distance: 6), candidate("b", distance: 8)],
                    multiButton: multiButton, isTouchBegin: true)
                #expect(resolution.commands == [token], "\(token) (multi: \(multiButton))")
                #expect(resolution.latchesToSystem, "\(token) (multi: \(multiButton))")
            }
        }
    }

    @Test("Multi-button touch never adds a system control")
    func multiButtonNeverAddsSystem() {
        for token in Self.systemTokens {
            let resolution = SkinTouchSelection.resolve(
                [candidate("a", distance: 3), candidate("b", distance: 5), candidate(token, distance: 9)],
                multiButton: true, isTouchBegin: true)
            #expect(resolution.commands == ["a", "b"], "\(token) joined a multi-press")
        }
    }

    @Test("D-pads and sticks are gameplay whatever their token says")
    func dpadAndStickSlideIn() {
        let dpad = candidate("menu", distance: 2, dpad: true, role: .system)
        #expect(dpad.allowsSlideIn)
        #expect(SkinTouchSelection.resolve([dpad], multiButton: false, isTouchBegin: false).primary?.id == "menu")
    }

    // MARK: - Drag across (continuation)

    @Test("Single mode keeps a touch on its button while it stays inside")
    func singleModeKeeps() {
        #expect(SkinTouchSelection.continuation(holdsButtons: true, stillOnHeld: true, isLatched: false,
                                                multiButton: false) == .keep)
        #expect(SkinTouchSelection.continuation(holdsButtons: true, stillOnHeld: false, isLatched: false,
                                                multiButton: false) == .resolve)
    }

    @Test("Multi mode re-derives the held set on every move")
    func multiModeResolves() {
        #expect(SkinTouchSelection.continuation(holdsButtons: true, stillOnHeld: true, isLatched: false,
                                                multiButton: true) == .resolve)
    }

    @Test("A latched touch stays on its system control, then goes dead once it leaves")
    func latchedTouch() {
        for multiButton in [false, true] {
            #expect(SkinTouchSelection.continuation(holdsButtons: true, stillOnHeld: true, isLatched: true,
                                                    multiButton: multiButton) == .keep)
            #expect(SkinTouchSelection.continuation(holdsButtons: true, stillOnHeld: false, isLatched: true,
                                                    multiButton: multiButton) == .releaseAndIgnore)
            // Back over the control after leaving: it holds nothing, so it stays dead.
            #expect(SkinTouchSelection.continuation(holdsButtons: false, stillOnHeld: false, isLatched: true,
                                                    multiButton: multiButton) == .releaseAndIgnore)
        }
    }

    /// Plays a finger through the view's steps: continuation, then resolve when asked.
    private struct Finger {
        var held: Set<String> = []
        var latched = false
        let multiButton: Bool

        mutating func touch(_ candidates: [SkinTouchCandidate], begin: Bool = false) {
            let still = candidates.contains { held.contains($0.command) }
            switch SkinTouchSelection.continuation(holdsButtons: !held.isEmpty, stillOnHeld: still,
                                                   isLatched: latched, multiButton: multiButton) {
            case .keep: return
            case .releaseAndIgnore: held = []; return
            case .resolve: break
            }
            let resolution = SkinTouchSelection.resolve(candidates, multiButton: multiButton, isTouchBegin: begin)
            held = resolution.commands
            if resolution.latchesToSystem { latched = true }
        }
    }

    @Test("Sliding from A to B releases A and presses B; straddling presses both only in multi mode")
    func dragAcross() {
        var single = Finger(multiButton: false)
        single.touch([candidate("a", distance: 2)], begin: true)
        #expect(single.held == ["a"])
        single.touch([candidate("a", distance: 20), candidate("b", distance: 22)])
        #expect(single.held == ["a"], "still inside A: stays on A")
        single.touch([candidate("b", distance: 3)])
        #expect(single.held == ["b"])

        var multi = Finger(multiButton: true)
        multi.touch([candidate("a", distance: 2)], begin: true)
        multi.touch([candidate("a", distance: 20), candidate("b", distance: 22)])
        #expect(multi.held == ["a", "b"])
        multi.touch([candidate("b", distance: 3)])
        #expect(multi.held == ["b"])
    }

    @Test("Sliding from a gameplay button onto Menu never presses Menu")
    func slideOntoMenu() {
        for multiButton in [false, true] {
            var finger = Finger(multiButton: multiButton)
            finger.touch([candidate("a", distance: 2)], begin: true)
            finger.touch([candidate("menu", distance: 2)])
            #expect(finger.held.isEmpty)
            finger.touch([candidate("menu", distance: 0), candidate("b", distance: 15)])
            #expect(finger.held == ["b"])
        }
    }

    @Test("A touch that began on Quick Save never slides onto anything, even back onto Quick Save")
    func latchedNeverSlides() {
        for multiButton in [false, true] {
            var finger = Finger(multiButton: multiButton)
            finger.touch([candidate("quickSave", distance: 2), candidate("a", distance: 10)], begin: true)
            #expect(finger.held == ["quickSave"])
            finger.touch([candidate("a", distance: 1)])
            #expect(finger.held.isEmpty)
            finger.touch([candidate("quickSave", distance: 1)])
            #expect(finger.held.isEmpty)
        }
    }
}
