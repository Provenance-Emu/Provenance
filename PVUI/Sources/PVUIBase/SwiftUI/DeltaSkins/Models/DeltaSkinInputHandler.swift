import Foundation
import Combine
import PVEmulatorCore
import PVCoreBridge
import PVLogging

/// Handles input from Delta Skins and forwards it to the emulator core
public class DeltaSkinInputHandler: ObservableObject {
    /// The emulator core to send inputs to
    private weak var emulatorCore: PVEmulatorCore?

    /// Callback for menu button presses
    var menuButtonHandler: (() -> Void)?

    /// Initialize with an emulator core
    public init(emulatorCore: PVEmulatorCore? = nil) {
        self.emulatorCore = emulatorCore
    }

    /// Set the emulator core
    func setEmulatorCore(_ core: PVEmulatorCore) {
        self.emulatorCore = core
    }

    /// Handle button press
    func buttonPressed(_ buttonId: String) {
        guard let core = emulatorCore else {
            ELOG("No emulator core available for button press: \(buttonId)")
            return
        }

        DLOG("Delta Skin button pressed: \(buttonId)")

        // Check if this is a menu button
        if buttonId.lowercased().contains("menu") {
            menuButtonPressed()
            return
        }

        // Forward to the core
        forwardButtonPress(buttonId, isPressed: true)
    }

    /// Handle button release
    func buttonReleased(_ buttonId: String) {
        guard let core = emulatorCore else {
            ELOG("No emulator core available for button release: \(buttonId)")
            return
        }

        DLOG("Delta Skin button released: \(buttonId)")

        // Skip menu button releases
        if buttonId.lowercased().contains("menu") {
            return
        }

        // Forward to the core
        forwardButtonPress(buttonId, isPressed: false)
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
