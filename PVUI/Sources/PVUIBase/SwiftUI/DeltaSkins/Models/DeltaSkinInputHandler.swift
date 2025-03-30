
import Foundation
import Combine
import PVEmulatorCore
import PVCoreBridge
import PVLogging
import PVUIBase

/// Handles input from Delta Skins and forwards it to the emulator core or controller
public class DeltaSkinInputHandler: ObservableObject {
    /// The emulator core to send inputs to
    private weak var emulatorCore: PVEmulatorCore?
    
    /// The controller view controller to send controller-based inputs to
    private weak var controllerVC: (any ControllerVC)?
    
    /// The emulator controller for handling special commands like quicksave and quickload
    private weak var emulatorController: (any PVEmualatorControllerProtocol)?
    
    /// A dummy D-pad for sending directional input to the controller
    private let dummyDPad = JSDPad(frame: .zero)

    /// Callback for menu button presses
    var menuButtonHandler: (() -> Void)?

    /// Initialize with an emulator core and optional controller view controller
    public init(emulatorCore: PVEmulatorCore? = nil, controllerVC: (any ControllerVC)? = nil, emulatorController: (any PVEmualatorControllerProtocol)? = nil) {
        self.emulatorCore = emulatorCore
        self.controllerVC = controllerVC
        self.emulatorController = emulatorController
        
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
    
    /// Set the emulator controller
    func setEmulatorController(_ controller: (any PVEmualatorControllerProtocol)?) {
        self.emulatorController = controller
    }

    /// Handle button press
    func buttonPressed(_ buttonId: String) {
        DLOG("Delta Skin button pressed: \(buttonId)")

        // Check for special commands
        let lowercasedId = buttonId.lowercased()
        
        // Handle menu button
        if lowercasedId.contains("menu") {
            menuButtonPressed()
            return
        }
        
        // Handle quicksave button
        if lowercasedId.contains("quicksave") {
            quicksaveButtonPressed()
            return
        }
        
        // Handle quickload button
        if lowercasedId.contains("quickload") {
            quickloadButtonPressed()
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

        // Skip special button releases
        let lowercasedId = buttonId.lowercased()
        if lowercasedId.contains("menu") || 
           lowercasedId.contains("quicksave") || 
           lowercasedId.contains("quickload") {
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
    
    /// Handle quicksave button press
    private func quicksaveButtonPressed() {
        DLOG("Quicksave button pressed")
        guard let controller = emulatorController else {
            ELOG("Cannot perform quicksave - emulatorController is nil")
            return
        }
        
        // Perform quicksave asynchronously
        Task {
            do {
                let success = try await controller.quicksave()
                if success {
                    DLOG("Quicksave completed successfully")
                } else {
                    ELOG("Quicksave failed")
                }
            } catch {
                ELOG("Error during quicksave: \(error)")
            }
        }
    }
    
    /// Handle quickload button press
    private func quickloadButtonPressed() {
        DLOG("Quickload button pressed")
        guard let controller = emulatorController else {
            ELOG("Cannot perform quickload - emulatorController is nil")
            return
        }
        
        // Perform quickload asynchronously
        Task {
            do {
                let success = try await controller.quickload()
                if success {
                    DLOG("Quickload completed successfully")
                } else {
                    ELOG("Quickload failed")
                }
            } catch {
                ELOG("Error during quickload: \(error)")
            }
        }
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
        // All standard controller buttons should be handled by the controller
        let controllerButtons = [
            // D-pad directions
            "up", "down", "left", "right", "upleft", "upright", "downleft", "downright",
            // Menu buttons
            "start", "select", 
            // Action buttons
            "a", "b", "x", "y",
            // Shoulder buttons
            "l", "r", "l1", "r1", "l2", "r2", "l3", "r3",
            // Analog buttons
            "leftanalog", "rightanalog"
        ]
        let isController = controllerButtons.contains(buttonId.lowercased())
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
        
        // Normalize the button ID to lowercase
        let normalizedId = buttonId.lowercased()
        
        // Handle special buttons first (D-pad, Start, Select)
        if handleSpecialButtons(normalizedId, isPressed: isPressed, controller: controller) {
            return
        }
        
        // For other buttons (A, B, X, Y, etc.), find the button in the button group
        if let buttonGroup = controller.buttonGroup {
            // Find the button with the matching label
            if let button = findButtonInGroup(buttonGroup, withLabel: normalizedId) {
                DLOG("Found button with label \(normalizedId) in button group")
                if isPressed {
                    controller.buttonPressed(button)
                } else {
                    controller.buttonReleased(button)
                }
                return
            }
        }
        
        // Handle shoulder buttons
        if handleShoulderButtons(normalizedId, isPressed: isPressed, controller: controller) {
            return
        }
        
        DLOG("Unhandled controller button \(isPressed ? "press" : "release"): \(buttonId)")
    }
    
    /// Handle special buttons (D-pad, Start, Select)
    private func handleSpecialButtons(_ buttonId: String, isPressed: Bool, controller: any ControllerVC) -> Bool {
        switch buttonId {
        // Menu buttons
        case "start":
            if isPressed {
                DLOG("Calling controller.pressStart")
                controller.pressStart(forPlayer: 0)
            } else {
                DLOG("Calling controller.releaseStart")
                controller.releaseStart(forPlayer: 0)
            }
            return true
            
        case "select":
            if isPressed {
                DLOG("Calling controller.pressSelect")
                controller.pressSelect(forPlayer: 0)
            } else {
                DLOG("Calling controller.releaseSelect")
                controller.releaseSelect(forPlayer: 0)
            }
            return true
            
        // D-pad directions
        case "up", "down", "left", "right", "upleft", "upright", "downleft", "downright":
            if isPressed {
                let direction = stringToDirection(buttonId)
                DLOG("Calling controller.dPad with press direction: \(direction)")
                controller.dPad(dummyDPad, didPress: direction)
            } else {
                let direction = stringToDirection(buttonId)
                DLOG("Calling controller.dPad with release direction: \(direction)")
                controller.dPad(dummyDPad, didRelease: direction)
            }
            return true
            
        default:
            return false
        }
    }
    
    /// Handle shoulder buttons (L, R, L2, R2, etc.)
    private func handleShoulderButtons(_ buttonId: String, isPressed: Bool, controller: any ControllerVC) -> Bool {
        // Try to find the appropriate shoulder button
        var button: JSButton? = nil
        
        switch buttonId {
        case "l", "l1":
            button = controller.leftShoulderButton
        case "r", "r1":
            button = controller.rightShoulderButton
        case "l2":
            button = controller.leftShoulderButton2
        case "r2":
            button = controller.rightShoulderButton2
        case "l3":
            button = controller.leftAnalogButton
        case "r3":
            button = controller.rightAnalogButton
        case "z":
            button = controller.zTriggerButton
        default:
            return false
        }
        
        if let button = button {
            if isPressed {
                DLOG("Pressing shoulder button: \(buttonId)")
                controller.buttonPressed(button)
            } else {
                DLOG("Releasing shoulder button: \(buttonId)")
                controller.buttonReleased(button)
            }
            return true
        }
        
        return false
    }
    
    /// Find a button in the button group with the given label
    private func findButtonInGroup(_ buttonGroup: MovableButtonView, withLabel label: String) -> JSButton? {
        // Search for buttons in the button group
        for case let button as JSButton in buttonGroup.subviews {
            // Check if the button label matches (case insensitive)
            if let buttonLabel = button.titleLabel?.text?.lowercased(), 
               buttonLabel == label || buttonLabel.first?.lowercased() == label {
                return button
            }
        }
        return nil
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
