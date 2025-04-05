import Foundation
import Combine
import PVEmulatorCore
import PVCoreBridge
import PVLogging
import PVUIBase
#if canImport(UIKit)
import UIKit
#endif

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

        // Set up notification observers
        setupNotificationObservers()
    }

    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
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

        // Check if the emulator is not running or is paused
        if let core = emulatorCore, (!core.isRunning || core.isEmulationPaused) {
            DLOG("Emulator core is not running or is paused, attempting to unpause")
            // Attempt to unpause the emulator
            core.setPauseEmulation(false)
        }

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

        // Handle fast forward toggle button
        if lowercasedId.contains("togglefastforward") {
            toggleFastForwardPressed()
            return
        }

        // Handle hold-style fast forward button
        if lowercasedId.contains("fastforward") && !lowercasedId.contains("toggle") {
            fastForwardPressed()
            return
        }

        // Handle slow motion toggle button
        if lowercasedId.contains("toggleslowmotion") {
            toggleSlowMotionPressed()
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

        // Check if the emulator is not running or is paused
        if let core = emulatorCore, (!core.isRunning || core.isEmulationPaused) {
            DLOG("Emulator core is not running or is paused during button release, attempting to unpause")
            // Attempt to unpause the emulator
            core.setPauseEmulation(false)
        }

        // Check for hold-style fast forward button release
        let lowercasedId = buttonId.lowercased()
        if lowercasedId.contains("fastforward") && !lowercasedId.contains("toggle") {
            fastForwardReleased()
            return
        }

        // Skip special button releases for toggle-style buttons
        if lowercasedId.contains("menu") ||
           lowercasedId.contains("quicksave") ||
           lowercasedId.contains("quickload") ||
           lowercasedId.contains("togglefastforward") ||
           lowercasedId.contains("toggleslowmotion") {
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

    // MARK: - Game Speed Control

    /// Timer for long press detection
    private var longPressTimer: Timer?

    /// Store the previous game speed when using hold-style buttons
    private var previousGameSpeed: GameSpeed?

    /// Handle toggle fast forward button press
    private func toggleFastForwardPressed() {
        DLOG("Toggle fast forward button pressed")
        guard let core = emulatorCore else {
            ELOG("Cannot toggle fast forward - emulatorCore is nil")
            return
        }

        // If already in fast mode, go back to normal
        if core.gameSpeed == .fast || core.gameSpeed == .veryFast {
            DLOG("Returning to normal speed from fast mode")
            core.gameSpeed = .normal
            return
        }

        // Otherwise, set to fast mode
        DLOG("Setting game speed to fast")
        core.gameSpeed = .fast

        // Start a timer for long press detection (for very fast mode)
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { [weak self] _ in
            guard let self = self, let core = self.emulatorCore else { return }

            // If still in fast mode after the timer, switch to very fast
            if core.gameSpeed == .fast {
                DLOG("Long press detected, setting game speed to very fast")
                core.gameSpeed = .veryFast
            }
        }
    }

    /// Handle hold-style fast forward button press
    private func fastForwardPressed() {
        DLOG("Fast forward button pressed (hold style)")
        guard let core = emulatorCore else {
            ELOG("Cannot set fast forward - emulatorCore is nil")
            return
        }

        // Save the current game speed to restore it on release
        previousGameSpeed = core.gameSpeed

        // Set to fast mode
        DLOG("Setting game speed to fast")
        core.gameSpeed = .fast
    }

    /// Handle hold-style fast forward button release
    private func fastForwardReleased() {
        DLOG("Fast forward button released (hold style)")
        guard let core = emulatorCore else {
            ELOG("Cannot reset game speed - emulatorCore is nil")
            return
        }

        // Reset to normal speed or previous speed
        if let previousSpeed = previousGameSpeed {
            DLOG("Restoring previous game speed: \(previousSpeed)")
            core.gameSpeed = previousSpeed
        } else {
            DLOG("Resetting game speed to normal")
            core.gameSpeed = .normal
        }

        // Clear the previous game speed
        previousGameSpeed = nil
    }

    /// Handle toggle slow motion button press
    private func toggleSlowMotionPressed() {
        DLOG("Toggle slow motion button pressed")
        guard let core = emulatorCore else {
            ELOG("Cannot toggle slow motion - emulatorCore is nil")
            return
        }

        // If already in slow mode, go back to normal
        if core.gameSpeed == .slow || core.gameSpeed == .verySlow {
            DLOG("Returning to normal speed from slow mode")
            core.gameSpeed = .normal
            return
        }

        // Otherwise, set to slow mode
        DLOG("Setting game speed to slow")
        core.gameSpeed = .slow

        // Start a timer for long press detection (for very slow mode)
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { [weak self] _ in
            guard let self = self, let core = self.emulatorCore else { return }

            // If still in slow mode after the timer, switch to very slow
            if core.gameSpeed == .slow {
                DLOG("Long press detected, setting game speed to very slow")
                core.gameSpeed = .verySlow
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
        switch buttonId.lowercased() {
        // Menu buttons
        case "start", "run", "play":
            if isPressed {
                DLOG("Calling controller.pressStart")
                controller.pressStart(forPlayer: 0)
                // Add haptic feedback
#if os(iOS) && !targetEnvironment(macCatalyst)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
#endif
            } else {
                DLOG("Calling controller.releaseStart")
                controller.releaseStart(forPlayer: 0)
            }
            return true

        case "select", "mode", "option":
            if isPressed {
                DLOG("Calling controller.pressSelect")
                controller.pressSelect(forPlayer: 0)
                // Add haptic feedback
#if os(iOS) && !targetEnvironment(macCatalyst)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
#endif
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

        switch buttonId.lowercased() {
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
        
        // Use system-specific button handling if we have a controller VC
        if let controllerVC = controllerVC {
            // Forward to the controller VC which knows how to map buttons for specific systems
            forwardButtonPressToSystemSpecificCore(normalizedId, isPressed: isPressed, core: core, controllerVC: controllerVC)
        } else {
            // Fallback to generic mapping if we don't have a controller VC
            let buttonIndex = mapButtonToIndex(normalizedId)
            
            if isPressed {
                DLOG("Pressing button (generic mapping): \(normalizedId) (index: \(buttonIndex))")
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
                DLOG("Releasing button (generic mapping): \(normalizedId) (index: \(buttonIndex))")
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
    }
    
    /// Forward button press to the system-specific core using the controller VC
    private func forwardButtonPressToSystemSpecificCore(_ buttonId: String, isPressed: Bool, core: PVEmulatorCore, controllerVC: any ControllerVC) {
        // Get the type of the controller VC to determine which system we're dealing with
        let controllerType = type(of: controllerVC)
        
        DLOG("Using system-specific controller: \(controllerType)")
        
        // Use the controller VC's JSButton tag mapping
        // This works because the controller VC sets up the button tags in its layoutViews method
        // and handles mapping button titles to the correct system-specific enum values
        let buttonIndex = mapButtonToIndex(buttonId)
        
        if isPressed {
            DLOG("Pressing button (system-specific): \(buttonId) (index: \(buttonIndex))")
            if let responder = core as? PVControllerResponder {
                responder.controllerPressedButton(buttonIndex, forPlayer: 0)
            }
        } else {
            DLOG("Releasing button (system-specific): \(buttonId) (index: \(buttonIndex))")
            if let responder = core as? PVControllerResponder {
                responder.controllerReleasedButton(buttonIndex, forPlayer: 0)
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
        case "start", "run", "play":
            return 11 // Start (and common variations)
        case "select", "mode", "option":
            return 12 // Select (and common variations)
        case "circle":
            return 5  // PlayStation Circle (typically maps to A/B)
        case "cross":
            return 6  // PlayStation Cross (typically maps to B/A)
        case "triangle":
            return 7  // PlayStation Triangle (typically maps to X/Y)
        case "square":
            return 8  // PlayStation Square (typically maps to Y/X)
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
        } else if normalizedId.contains("start") || normalizedId.contains("run") || normalizedId.contains("play") {
            return 11 // Start and variations
        } else if normalizedId.contains("select") || normalizedId.contains("mode") || normalizedId.contains("option") {
            return 12 // Select and variations
        }

        // Default to A button if unknown
        return 5
    }

    // MARK: - Notification Observers

    /// Set up notification observers for reconnection events
    private func setupNotificationObservers() {
        DLOG("Setting up notification observers for DeltaSkinInputHandler")

        // Observer for reconnection events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReconnectEvent),
            name: NSNotification.Name("DeltaSkinInputHandlerReconnect"),
            object: nil
        )

        // Observer for skin change events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSkinChangeEvent),
            name: NSNotification.Name("DeltaSkinChanged"),
            object: nil
        )
    }

    /// Handle reconnection event when the menu is dismissed
    @objc private func handleReconnectEvent() {
        DLOG("DeltaSkinInputHandler handling reconnect event")
        performReconnection()
    }

    /// Handle skin change event
    @objc private func handleSkinChangeEvent() {
        DLOG("DeltaSkinInputHandler handling skin change event")
        performReconnection()
    }

    /// Common logic to reconnect and reset state
    private func performReconnection() {
        // Refresh emulator core reference on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            ILOG("⚠️ Starting DeltaSkinInputHandler reconnection")

            // Debug information about our menu button handler
            if let _ = self.menuButtonHandler {
                DLOG("Menu button handler is set")
            } else {
                ELOG("⛔️ Menu button handler is NOT set - this may cause menu functionality issues")
            }

            // Log current state
            if let core = self.emulatorCore {
                DLOG("Current core: \(core), isRunning: \(core.isRunning), isPaused: \(core.isEmulationPaused)")

                // Verify core responds to basic inputs by sending and releasing a dummy input
                if let responder = core as? PVControllerResponder {
                    DLOG("Testing core responsiveness with dummy button press")
                    // Send a dummy press and release for a non-disruptive button (select)
                    responder.controllerPressedButton(12, forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        responder.controllerReleasedButton(12, forPlayer: 0)
                    }
                } else {
                    ELOG("Core does not conform to PVControllerResponder, cannot test responsiveness directly")
                }
            } else {
                ELOG("⛔️ No emulator core available for reconnection!")
            }

            if let controller = self.controllerVC {
                DLOG("Controller VC is available: \(controller)")
            } else {
                DLOG("No controller VC available")
            }

            // Clear any stuck button states
            if let controller = self.controllerVC {
                DLOG("Releasing any stuck buttons on controller")
                // Release controller buttons
                if let leftShoulderButton = controller.leftShoulderButton {
                    controller.buttonReleased(leftShoulderButton)
                }
                if let rightShoulderButton = controller.rightShoulderButton {
                    controller.buttonReleased(rightShoulderButton)
                }
                if let leftShoulderButton2 = controller.leftShoulderButton2 {
                    controller.buttonReleased(leftShoulderButton2)
                }
                if let rightShoulderButton2 = controller.rightShoulderButton2 {
                    controller.buttonReleased(rightShoulderButton2)
                }
                if let buttonGroup = controller.buttonGroup {
                    for case let button as JSButton in buttonGroup.subviews {
                        controller.buttonReleased(button)
                    }
                }

                // Release D-pad directions
                for direction in [JSDPadDirection.up, .down, .left, .right, .upLeft, .upRight, .downLeft, .downRight] {
                    controller.dPad(self.dummyDPad, didRelease: direction)
                }

                DLOG("✅ Released all controller buttons")
            }

            // Validate and ensure the emulator core is running
            guard let core = self.emulatorCore else {
                ELOG("Cannot reconnect - emulatorCore is nil")
                return
            }

            DLOG("Reconnecting to emulator core: \(core)")

            // If core was paused, unpause it
            if core.isEmulationPaused {
                DLOG("Unpausing core during reconnect")
                core.setPauseEmulation(false)
            }

            // Restore normal game speed
            if core.gameSpeed != .normal {
                DLOG("Resetting game speed to normal from \(core.gameSpeed)")
                core.gameSpeed = .normal
            }

            // Reset the core's input state by sending dummy button releases if the core supports it
            if let responder = core as? PVControllerResponder {
                DLOG("Core conforms to PVControllerResponder, using direct method calls")
                // Release all standard buttons
                for i in 1...12 {
                    responder.controllerReleasedButton(i, forPlayer: 0)
                }
            } else {
                DLOG("Core does not conform to PVControllerResponder, using notification fallback")
                // Fallback to notifications
                for i in 1...12 {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ButtonReleased"),
                        object: nil,
                        userInfo: ["button": i, "player": 0]
                    )
                }
            }

            // Reset analog sticks if supported
            if let analogResponder = core as? PVAnalogResponder {
                DLOG("Resetting analog stick positions")
                analogResponder.controllerMovedLeftAnalogStick(x: 0, y: 0, forPlayer: 0)
                analogResponder.controllerMovedRightAnalogStick(x: 0, y: 0, forPlayer: 0)
            }

            // Force a GPU view refresh when possible
            if let metalVC = core.renderDelegate as? PVMetalViewController {
                DLOG("Refreshing Metal GPU view during reconnect")
                metalVC.safelyRefreshGPUView()
            }

            // Test button forwarding after reconnection
            self.testButtonForwarding()

            ILOG("✅ Reconnection complete")
        }
    }

    /// Test button forwarding to verify input handling after reconnection
    private func testButtonForwarding() {
        guard let core = emulatorCore else {
            ELOG("Cannot test button forwarding - no emulator core")
            return
        }

        DLOG("Testing button forwarding after reconnection")

        // Test menu button handling
        if let _ = menuButtonHandler {
            DLOG("✅ Menu button handler still registered")
        } else {
            ELOG("⛔️ Menu button handler MISSING after reconnection")

            // Attempt to fix this by posting a notification to request menu handler reattachment
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinReconnectMenuHandler"),
                object: nil
            )
        }

        // Test direct button forwarding to core
        if let responder = core as? PVControllerResponder {
            DLOG("Testing A button forwarding to core")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }

                // Notify the input system we're going to perform a test
                DLOG("Performing input test sequence...")

                // Send a test button press and release for the A button (non-disruptive)
                self.forwardButtonPress("a", isPressed: true)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.forwardButtonPress("a", isPressed: false)
                    DLOG("✅ Input test sequence completed")
                }
            }
        }
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
