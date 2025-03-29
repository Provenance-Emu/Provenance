
import Foundation
import Combine
import PVEmulatorCore
import PVCoreBridge
import PVLogging

/// Handles input from Delta Skins and forwards it to the emulator core or controller
public class DeltaSkinInputHandler: ObservableObject {
    /// The emulator core to send inputs to
    private weak var emulatorCore: PVEmulatorCore?
    
    /// The controller view controller to send controller-based inputs to
    private weak var controllerVC: (any ControllerVC)?
    
    /// A dummy D-pad for sending directional input to the controller
    private let dummyDPad = JSDPad(frame: .zero)

    /// Callback for menu button presses
    var menuButtonHandler: (() -> Void)?

    /// Initialize with an emulator core and optional controller view controller
    public init(emulatorCore: PVEmulatorCore? = nil, controllerVC: (any ControllerVC)? = nil) {
        self.emulatorCore = emulatorCore
        self.controllerVC = controllerVC
        
        // Set the tag to match the D-pad tag expected by the controller
        dummyDPad.tag = ControlTag.dpad1.rawValue
    }

    /// Set the emulator core
    func setEmulatorCore(_ core: PVEmulatorCore) {
        self.emulatorCore = core
    }
    
    /// Set the controller view controller
    func setControllerVC(_ controller: (any ControllerVC)?) {
        self.controllerVC = controller
    }

    /// Handle button press
    func buttonPressed(_ buttonId: String) {
        DLOG("Delta Skin button pressed: \(buttonId)")

        // Check if this is a menu button
        if buttonId.lowercased().contains("menu") {
            menuButtonPressed()
            return
        }
        
        // Normalize the button ID
        let normalizedId = buttonId.lowercased()
        DLOG("Normalized button ID: \(normalizedId)")
        
        // Log controller availability
        if let _ = controllerVC {
            DLOG("Controller VC is available")
        } else {
            DLOG("Controller VC is NOT available")
        }
        
        // Check if we should use the controller VC for this button
        if let controller = controllerVC, isControllerButton(normalizedId) {
            DLOG("Using controller for button press: \(normalizedId)")
            // Use the controller view controller for D-pad, Start, and Select buttons
            forwardButtonPressToController(normalizedId, isPressed: true)
        } else if let core = emulatorCore {
            DLOG("Using core for button press: \(normalizedId)")
            // Forward to the core for other buttons
            forwardButtonPress(buttonId, isPressed: true)
        } else {
            ELOG("No emulator core or controller available for button press: \(buttonId)")
        }
    }

    /// Handle button release
    func buttonReleased(_ buttonId: String) {
        DLOG("Delta Skin button released: \(buttonId)")

        // Skip menu button releases
        if buttonId.lowercased().contains("menu") {
            return
        }
        
        // Normalize the button ID
        let normalizedId = buttonId.lowercased()
        DLOG("Normalized button ID for release: \(normalizedId)")
        
        // Log controller availability
        if let _ = controllerVC {
            DLOG("Controller VC is available for release")
        } else {
            DLOG("Controller VC is NOT available for release")
        }
        
        // Check if we should use the controller VC for this button
        if let controller = controllerVC, isControllerButton(normalizedId) {
            DLOG("Using controller for button release: \(normalizedId)")
            // Use the controller view controller for D-pad, Start, and Select buttons
            forwardButtonPressToController(normalizedId, isPressed: false)
        } else if let core = emulatorCore {
            DLOG("Using core for button release: \(normalizedId)")
            // Forward to the core for other buttons
            forwardButtonPress(buttonId, isPressed: false)
        } else {
            ELOG("No emulator core or controller available for button release: \(buttonId)")
        }
    }

    /// Handle menu button press
    func menuButtonPressed() {
        DLOG("Delta Skin menu button pressed")

        // Call the menu button handler if set
        menuButtonHandler?()
    }

    /// Handle analog stick movement
    func analogStickMoved(_ stickId: String, x: Float, y: Float) {
        guard let core = emulatorCore else {
            ELOG("No emulator core available for analog stick: \(stickId)")
            return
        }

        DLOG("Analog stick moved: \(stickId), x: \(x), y: \(y)")

        // Determine which stick this is
        let isLeftStick = stickId.lowercased().contains("left")

        // Try different methods that might be available
        if let responder = core as? PVAnalogResponder {
            if isLeftStick {
                responder.controllerMovedLeftAnalogStick(x: x, y: y, forPlayer: 0)
            } else {
                responder.controllerMovedRightAnalogStick(x: x, y: y, forPlayer: 0)
            }
        } else {
            // Fallback to a more generic approach
            NotificationCenter.default.post(
                name: NSNotification.Name("AnalogStickMoved"),
                object: nil,
                userInfo: ["stick": isLeftStick ? "left" : "right", "x": x, "y": y, "player": 0]
            )
        }
    }

    // MARK: - Private Methods
    
    /// Check if a button should be handled by the controller
    private func isControllerButton(_ buttonId: String) -> Bool {
        // D-pad directions, Start, and Select buttons should be handled by the controller
        let controllerButtons = ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright", "start", "select"]
        let isController = controllerButtons.contains(buttonId)
        DLOG("isControllerButton check: \(buttonId) -> \(isController)")
        return isController
    }
    
    /// Forward button press to the controller view controller
    private func forwardButtonPressToController(_ buttonId: String, isPressed: Bool) {
        guard let controller = controllerVC else {
            ELOG("Cannot forward to controller - controllerVC is nil")
            return
        }
        
        DLOG("Forwarding \(isPressed ? "press" : "release") to controller: \(buttonId)")
        
        if isPressed {
            // Handle button press
            switch buttonId {
            case "start":
                DLOG("Calling controller.pressStart")
                controller.pressStart(forPlayer: 0)
            case "select":
                DLOG("Calling controller.pressSelect")
                controller.pressSelect(forPlayer: 0)
            case "up":
                DLOG("Calling controller.dPad with .up")
                controller.dPad(dummyDPad, didPress: .up)
            case "down":
                DLOG("Calling controller.dPad with .down")
                controller.dPad(dummyDPad, didPress: .down)
            case "left":
                DLOG("Calling controller.dPad with .left")
                controller.dPad(dummyDPad, didPress: .left)
            case "right":
                DLOG("Calling controller.dPad with .right")
                controller.dPad(dummyDPad, didPress: .right)
            case "upleft":
                DLOG("Calling controller.dPad with .upLeft")
                controller.dPad(dummyDPad, didPress: .upLeft)
            case "upright":
                DLOG("Calling controller.dPad with .upRight")
                controller.dPad(dummyDPad, didPress: .upRight)
            case "downleft":
                DLOG("Calling controller.dPad with .downLeft")
                controller.dPad(dummyDPad, didPress: .downLeft)
            case "downright":
                DLOG("Calling controller.dPad with .downRight")
                controller.dPad(dummyDPad, didPress: .downRight)
            default:
                DLOG("Unhandled controller button press: \(buttonId)")
            }
        } else {
            // Handle button release
            switch buttonId {
            case "start":
                DLOG("Calling controller.releaseStart")
                controller.releaseStart(forPlayer: 0)
            case "select":
                DLOG("Calling controller.releaseSelect")
                controller.releaseSelect(forPlayer: 0)
            case "up", "down", "left", "right", "upleft", "upright", "downleft", "downright":
                let direction = stringToDirection(buttonId)
                DLOG("Calling controller.dPad with release direction: \(direction)")
                controller.dPad(dummyDPad, didRelease: direction)
            default:
                DLOG("Unhandled controller button release: \(buttonId)")
            }
        }
    }
    
    /// Convert string direction to JSDPadDirection
    private func stringToDirection(_ direction: String) -> JSDPadDirection {
        switch direction.lowercased() {
        case "up":
            return .up
        case "down":
            return .down
        case "left":
            return .left
        case "right":
            return .right
        case "upleft":
            return .upLeft
        case "upright":
            return .upRight
        case "downleft":
            return .downLeft
        case "downright":
            return .downRight
        default:
            return .none
        }
    }

    /// Forward button press to the emulator core
    private func forwardButtonPress(_ buttonId: String, isPressed: Bool) {
        guard let core = emulatorCore else { return }

        // Normalize the button ID
        let normalizedId = buttonId.lowercased()

        // Map to button index and send to core
        let buttonIndex = mapButtonToIndex(normalizedId)

        if isPressed {
            DLOG("Pressing button: \(normalizedId) (index: \(buttonIndex))")
            // Try different methods that might be available
            if let responder = core as? PVControllerResponder {
                responder.controllerPressedButton(buttonIndex, forPlayer: 0)
            } else {
                // Fallback to a more generic approach
                NotificationCenter.default.post(
                    name: NSNotification.Name("ButtonPressed"),
                    object: nil,
                    userInfo: ["button": buttonIndex, "player": 0]
                )
            }
        } else {
            DLOG("Releasing button: \(normalizedId) (index: \(buttonIndex))")
            // Try different methods that might be available
            if let responder = core as? PVControllerResponder {
                responder.controllerReleasedButton(buttonIndex, forPlayer: 0)
            } else {
                // Fallback to a more generic approach
                NotificationCenter.default.post(
                    name: NSNotification.Name("ButtonReleased"),
                    object: nil,
                    userInfo: ["button": buttonIndex, "player": 0]
                )
            }
        }
    }

    /// Map button ID to button index
    private func mapButtonToIndex(_ buttonId: String) -> Int {
        // Normalize the input ID for consistent matching
        let normalizedId = buttonId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact matches first (for commands extracted from skin JSON)
        switch normalizedId {
        case "up":
            return 1  // Up
        case "down":
            return 2  // Down
        case "left":
            return 3  // Left
        case "right":
            return 4  // Right
        case "a":
            return 5  // A
        case "b":
            return 6  // B
        case "x":
            return 7  // X
        case "y":
            return 8  // Y
        case "l", "l1":
            return 9  // L
        case "r", "r1":
            return 10 // R
        case "start":
            return 11 // Start
        case "select":
            return 12 // Select
        default:
            break
        }

        // Fallback to partial matching if exact match failed
        if normalizedId.contains("up") {
            return 1  // Up
        } else if normalizedId.contains("down") {
            return 2  // Down
        } else if normalizedId.contains("left") {
            return 3  // Left
        } else if normalizedId.contains("right") {
            return 4  // Right
        } else if normalizedId.contains("a") && !normalizedId.contains("analog") {
            return 5  // A
        } else if normalizedId.contains("b") {
            return 6  // B
        } else if normalizedId.contains("x") {
            return 7  // X
        } else if normalizedId.contains("y") {
            return 8  // Y
        } else if (normalizedId.contains("l") || normalizedId.contains("l1")) && !normalizedId.contains("select") {
            return 9  // L
        } else if (normalizedId.contains("r") || normalizedId.contains("r1")) && !normalizedId.contains("start") {
            return 10 // R
        } else if normalizedId.contains("start") {
            return 11 // Start
        } else if normalizedId.contains("select") {
            return 12 // Select
        }

        // Default to A button if unknown
        return 5
    }
}

/// Protocol for cores that support CoreActions
protocol CoreActionsProtocol: AnyObject {
    func performAction(_ action: CoreAction, value: Float)
}

// Add this protocol definition
protocol PVControllerResponder {
    func controllerPressedButton(_ button: Int, forPlayer player: Int)
    func controllerReleasedButton(_ button: Int, forPlayer player: Int)
}

// Add this protocol definition
protocol PVAnalogResponder {
    func controllerMovedLeftAnalogStick(x: Float, y: Float, forPlayer player: Int)
    func controllerMovedRightAnalogStick(x: Float, y: Float, forPlayer player: Int)
}
