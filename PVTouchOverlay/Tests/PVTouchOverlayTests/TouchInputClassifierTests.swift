import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay
import SkinKitUI

@Suite("Touch input classifier")
struct TouchInputClassifierTests {
    @Test("Console inputs are gameplay, including Start, Select, Coin and analog tokens")
    func gameplayTokens() {
        let gameplay = [
            "a", "b", "c", "x", "y", "z", "A", "start", "select", "coin", "insertcoin", "option", "pause",
            "up", "down", "left", "right", "upleft", "downright", "l", "l1", "l2", "r", "r2", "l3", "r3",
            "leftThumbstickUp", "rightThumbstickRight", "cUp", "1", "9", "star", "pound", "plus", "minus",
            "somethingnew", ""
        ]
        for token in gameplay {
            #expect(TouchInputClassifier.role(forToken: token) == .gameplay, "\(token) should be gameplay")
        }
    }

    @Test("Every frontend command DeltaSkinInputHandler intercepts is a system control")
    func frontendCommands() {
        let commands = [
            "menu", "Menu", "quickSave", "quicksave", "quickLoad", "quickload", "fastForward",
            "toggleFastForward", "slowMotion", "toggleSlowMotion", "screenshot", "screenshotButton",
            "pauseMenu", "MENU "
        ]
        for token in commands {
            #expect(TouchInputClassifier.role(forToken: token) == .system, "\(token) must be a system control")
        }
        for token in TouchInputClassifier.frontendFunctionTokens {
            #expect(TouchInputClassifier.role(forToken: token) == .system, "\(token) must be a system control")
        }
    }

    @Test("Console switches and system / operator buttons are system controls")
    func switchesAndSystemButtons() {
        let system = [
            "leftdiff", "leftDifficulty", "rightdiff", "rightdifficulty", "tvtype", "tvType",
            "leftdiffa", "leftdiff_b", "rightdiffb", "colorbw", "colorbw_color", "color", "bw", "b&w",
            "turboi", "turboii", "home", "service", "test", "TEST", "reset", "restart"
        ]
        for token in system {
            #expect(TouchInputClassifier.role(forToken: token) == .system, "\(token) must be a system control")
        }
    }

    @Test("Overlay kinds: actions and hardware switches are system, buttons go by token")
    func overlayKinds() {
        let snes = { (token: String) in OverlayInputID(system: .SNES, token: token) }
        let actions: [OverlayAction] = [.menu, .quickSave, .quickLoad, .fastForward, .toggleKeyboard,
                                        .toggleMouse, .screenshot, .keypad, .flip, .diskSide, .service]
        for action in actions {
            #expect(OverlayControlKind.action(action).touchRole == .system, "\(action)")
            #expect(!OverlayControlKind.action(action).isMultiPressEligible)
        }
        #expect(OverlayControlKind.hardwareSwitch(descriptorID: "left_diff").touchRole == .system)
        #expect(OverlayControlKind.button(snes("a")).touchRole == .gameplay)
        #expect(OverlayControlKind.button(snes("a")).isMultiPressEligible)
        #expect(OverlayControlKind.analogTrigger(snes("l2")).isMultiPressEligible)
        #expect(OverlayControlKind.button(snes("tvtype")).touchRole == .system)
        #expect(!OverlayControlKind.button(snes("reset")).isMultiPressEligible)
        let resetPill = OverlayControl(id: OverlayFamilySlot.reset.rawValue, kind: .button(snes("r")), frame: .zero,
                                       shape: .pill, paletteSlot: .utility)
        #expect(resetPill.touchRole == .system && !resetPill.isMultiPressEligible)
        let dpad = OverlayControlKind.dpad(up: snes("up"), down: snes("down"), left: snes("left"), right: snes("right"))
        #expect(dpad.touchRole == .gameplay && !dpad.isMultiPressEligible)
        #expect(OverlayControlKind.stick(.left, click: nil).touchRole == .gameplay)
    }

    /// Every bound system's pad: the only system controls are the action pills, console switch pills, the
    /// Reset pill and the Wii Remote's Home; every d-pad, face, shoulder, stick, Start and Select is gameplay.
    @Test("Every bound template classifies its controls as expected")
    func everyTemplate() {
        let systemGroups: Set<String> = ["actions", "switches"]
        let systemSlots: Set<String> = [OverlayFamilySlot.reset.rawValue, OverlayFamilySlot.home.rawValue]
        for system in SystemOverlayBindings.boundSystems {
            guard let binding = SystemOverlayBindings.binding(for: system) else { continue }
            for subtype in binding.families.keys {
                for orientation in OverlayOrientation.allCases {
                    let template = binding.template(padKind: OverlayPadKind(system: system, subtype: subtype),
                                                    orientation: orientation)
                    for group in template.groups {
                        for control in group.controls {
                            let role = control.touchRole
                            let label = "\(system) \(subtype) \(group.id)/\(control.id)"
                            if systemGroups.contains(group.id) {
                                #expect(role == .system, "\(label) should be a system control")
                            } else if case .action = control.kind {
                                #expect(role == .system, "\(label) should be a system control")
                            } else if systemSlots.contains(control.id) {
                                #expect(role == .system, "\(label) should be a system control")
                            } else {
                                #expect(role == .gameplay, "\(label) should be gameplay")
                            }
                        }
                    }
                }
            }
        }
    }
}
