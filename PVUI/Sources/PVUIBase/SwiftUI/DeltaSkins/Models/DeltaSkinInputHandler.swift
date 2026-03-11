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

    /// Track previous joystick state for D-pad conversion
    private var previousJoystickState: (x: Float, y: Float)? = nil

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
    @MainActor
    func buttonPressed(_ buttonId: String) {
        DLOG("Delta Skin button pressed: \(buttonId)")

        // Check for special commands first (do not auto-unpause here)
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

        // For gameplay inputs: unpause if paused before forwarding
        if let core = emulatorCore, (!core.isRunning || core.isEmulationPaused) {
            DLOG("Auto-unpausing core for gameplay input: \(lowercasedId)")
            core.setPauseEmulation(false)
        }

        // Normalize the button ID
        let normalizedId = buttonId.lowercased()
        DLOG("Normalized button ID: \(normalizedId)")

        // Prefer core/system-specific mapping; it will fall back to controllerVC or generic if needed
        if emulatorCore != nil {
            forwardButtonPress(normalizedId, isPressed: true)
        } else if let controller = controllerVC, isControllerButton(normalizedId) {
            DLOG("No core available, forwarding to controller: \(normalizedId)")
            forwardButtonPressToController(normalizedId, isPressed: true)
        } else {
            ELOG("No emulator core or controller available for button press: \(buttonId)")
        }
    }

    /// Handle button release
    @MainActor
    func buttonReleased(_ buttonId: String) {
        DLOG("Delta Skin button released: \(buttonId)")

        // Check if the emulator is not running or is paused
//        if let core = emulatorCore, (!core.isRunning || core.isEmulationPaused) {
//            DLOG("Emulator core is not running or is paused during button release, attempting to unpause")
//            // Attempt to unpause the emulator
//            core.setPauseEmulation(false)
//        }

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

        // Prefer core/system-specific mapping; it will fall back to controllerVC or generic if needed
        if emulatorCore != nil {
            forwardButtonPress(normalizedId, isPressed: false)
        } else if let controller = controllerVC, isControllerButton(normalizedId) {
            DLOG("No core available, forwarding release to controller: \(normalizedId)")
            forwardButtonPressToController(normalizedId, isPressed: false)
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

    // MARK: - DS Touchscreen

    /// Forward a touch on the NDS bottom screen to the emulator core.
    ///
    /// - Parameter normalizedPoint: Touch position normalised to the bottom screen's
    ///   output frame (0,0 = top-left of the bottom screen, 1,1 = bottom-right).
    ///
    /// The method translates the normalised position into DS touchscreen coordinates
    /// (x: 0–255, y: 0–191) and calls `PVDSSystemResponderClient.touchScreenAtPoint(_:)`
    /// on the emulator core when it conforms to the protocol.
    @MainActor
    func ndsBottomScreenTouched(at normalizedPoint: CGPoint) {
        guard let core = emulatorCore else {
            ELOG("DS touch: no emulator core available")
            return
        }

        // DS touchscreen native resolution: 256 × 192
        let dsX = max(0, min(255, normalizedPoint.x * 255))
        let dsY = max(0, min(191, normalizedPoint.y * 191))
        let dsPoint = CGPoint(x: dsX, y: dsY)

        DLOG("DS bottom screen touch: normalized=\(normalizedPoint) → ds=\(dsPoint)")

        guard let responder = core as? PVDSSystemResponderClient else {
            ELOG("DS touch: core does not conform to PVDSSystemResponderClient")
            return
        }
        responder.touchScreenAtPoint?(dsPoint)
    }

    /// Notify the emulator core that the DS touchscreen stylus was lifted.
    @MainActor
    func ndsBottomScreenTouchReleased() {
        guard let core = emulatorCore,
              let responder = core as? PVDSSystemResponderClient else { return }
        responder.releaseScreenTouch?()
    }

    // MARK: - Analog stick

    /// Handle analog stick movement
    func analogStickMoved(_ stickId: String, x: Float, y: Float) {
        ILOG("🔵 analogStickMoved called: stickId=\(stickId), x=\(x), y=\(y)")

        guard let core = emulatorCore else {
            ELOG("No emulator core available for analog stick: \(stickId)")
            return
        }

        DLOG("Analog stick moved: \(stickId), x: \(x), y: \(y)")

        // Determine which stick this is
        // Check for "left" or "right" in stickId (e.g., "leftAnalog", "rightAnalog", "analog_left", "analog_right")
        // Default to left if neither is specified
        let lowercasedId = stickId.lowercased()
        let isLeftStick = lowercasedId.contains("left") || (!lowercasedId.contains("right"))

        // Check if this system only had D-pad (not joystick)
        // Even if the core conforms to JoystickResponder (like RetroArch cores),
        // we should convert joystick to D-pad for these systems
        let systemIdentifier = core.systemIdentifier
        let systemId = systemIdentifier.flatMap { SystemIdentifier(rawValue: $0) }
        let systemsWithDPadOnly: Set<SystemIdentifier> = [
            .Sega32X, .Genesis, .SegaCD, .SNES, .NES, .FDS, .GBA, .GB, .GBC, .VirtualBoy, .Atari8bit, .AtariST, ._3DO, .Music, .ColecoVision
        ]

        // Convert joystick to D-pad for systems that only had D-pad
        // Only convert left stick (right stick is typically not used for D-pad conversion)
        if isLeftStick, let systemId = systemId, systemsWithDPadOnly.contains(systemId) {
            DLOG("System \(systemId) only had D-pad, converting joystick to D-pad")
            convertJoystickToDPad(x: x, y: y, core: core)
            return
        }

        // Handle systems that require system-specific button enums instead of Int
        // These systems have their own joystick responder protocols that take enum values
        if let systemId = systemId {
            ILOG("🔵 System detected: \(systemId), isLeftStick: \(isLeftStick)")
            switch systemId {
            case .N64:
                // N64 only has a left analog stick
                ILOG("🔵 N64 case matched, isLeftStick: \(isLeftStick)")
                if isLeftStick {
                    ILOG("🔵 Checking if core conforms to PVN64SystemResponderClient...")
                    if let responder = core as? PVN64SystemResponderClient {
                        ILOG("✅ Core conforms! Calling didMoveJoystick with .leftAnalog, x=\(x), y=\(y)")
                        responder.didMoveJoystick(.leftAnalog, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                        DLOG("Forwarded joystick event via PVN64SystemResponderClient: button=leftAnalog, x=\(x), y=\(y)")
                        return
                    } else {
                        ELOG("❌ Core does NOT conform to PVN64SystemResponderClient")
                    }
                } else {
                    ILOG("⚠️ N64 only supports left stick, but isLeftStick is false")
                }
            case .PSP:
                // PSP only has a left analog stick
                if isLeftStick, let responder = core as? PVPSPSystemResponderClient {
                    responder.didMoveJoystick(.leftAnalog, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVPSPSystemResponderClient: button=leftAnalog, x=\(x), y=\(y)")
                    return
                }
            case .PSX:
                // PSX has both left and right analog sticks
                if let responder = core as? PVPSXSystemResponderClient {
                    let button: PVPSXButton = isLeftStick ? .leftAnalog : .rightAnalog
                    responder.didMoveJoystick(button, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVPSXSystemResponderClient: button=\(button.stringValue), x=\(x), y=\(y)")
                    return
                }
            case .PS2, .PS3:
                // PS2/PS3 have both left and right analog sticks
                if let responder = core as? PVPS2SystemResponderClient {
                    let button: PVPS2Button = isLeftStick ? .leftAnalog : .rightAnalog
                    responder.didMoveJoystick(button, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVPS2SystemResponderClient: button=\(button.stringValue), x=\(x), y=\(y)")
                    return
                }
            case .Dreamcast:
                // Dreamcast has a left analog stick
                if isLeftStick, let responder = core as? PVDreamcastSystemResponderClient {
                    responder.didMoveJoystick(.leftAnalog, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVDreamcastSystemResponderClient: button=leftAnalog, x=\(x), y=\(y)")
                    return
                }
            case .Saturn:
                // Saturn doesn't have analog sticks, skip
                if isLeftStick, let responder = core as? PVSaturnSystemResponderClient {
                    responder.didMoveJoystick(.leftAnalog, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVDreamcastSystemResponderClient: button=leftAnalog, x=\(x), y=\(y)")
                    return
                }
            case .MAME:
                // MAME has both left and right analog sticks
                if let responder = core as? PVMAMESystemResponderClient {
                    let button: PVMAMEButton = isLeftStick ? .leftAnalog : .rightAnalog
                    responder.didMoveJoystick(button, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVMAMESystemResponderClient: button=\(button.stringValue), x=\(x), y=\(y)")
                    return
                }
            case ._3DS:
                // 3DS has a left analog stick (Circle Pad) and C-Stick (right)
                if let responder = core as? PV3DSSystemResponderClient {
                    let button: PV3DSButton = isLeftStick ? .leftAnalog : .rightAnalog
                    responder.didMoveJoystick(button, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PV3DSSystemResponderClient: button=\(button.stringValue), x=\(x), y=\(y)")
                    return
                }
            case .GameCube:
                if let responder = core as? PVGameCubeSystemResponderClient {
                    let button: PVGCButton = isLeftStick ? .leftAnalog : .rightAnalog
                    responder.didMoveJoystick(button, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVGameCubeControllerViewController: button=\(button.stringValue), x=\(x), y=\(y)")
                    return
                }
            case .Wii:
                if let responder = core as? PVWiiSystemResponderClient {
                    let button: PVWiiMoteButton = isLeftStick ? .leftAnalog : .rightAnalog
                    responder.didMoveJoystick(button, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
                    DLOG("Forwarded joystick event via PVWiiControllerViewController: button=\(button.stringValue), x=\(x), y=\(y)")
                    return
                }
            default:
                break
            }
        }

        // Use generic JoystickResponder protocol (all cores that support joysticks implement this)
        // The protocol-agnostic approach: use 0 for left stick, 1 for right stick
        // Each core's implementation will map these values to their specific button enums internally
        if let joystickResponder = core as? JoystickResponder {
            let buttonValue = isLeftStick ? 0 : 1
            joystickResponder.didMoveJoystick(buttonValue, withXValue: CGFloat(x), withYValue: CGFloat(y), forPlayer: 0)
            DLOG("Forwarded joystick event via JoystickResponder: button=\(buttonValue), x=\(x), y=\(y)")
            return
        }

        // Fallback for cores that might use different protocols
        if let responder = core as? PVAnalogResponder {
            if isLeftStick {
                responder.controllerMovedLeftAnalogStick(x: x, y: y, forPlayer: 0)
            } else {
                responder.controllerMovedRightAnalogStick(x: x, y: y, forPlayer: 0)
            }
            return
        }

        // Last resort: post notification
        DLOG("No joystick responder found, posting notification")
        NotificationCenter.default.post(
            name: NSNotification.Name("AnalogStickMoved"),
            object: nil,
            userInfo: ["stick": isLeftStick ? "left" : "right", "x": x, "y": y, "player": 0]
        )
    }

    /// Convert joystick movement to D-pad button presses for systems that don't support joysticks
    private func convertJoystickToDPad(x: Float, y: Float, core: PVEmulatorCore) {
        guard let systemIdentifier = core.systemIdentifier, let systemId = SystemIdentifier(rawValue: systemIdentifier) else {
            return
        }

        // Threshold for detecting D-pad direction (0.3 = 30% of stick movement)
        let threshold: Float = 0.3

        // Determine which directions are active
        // Note: Y is already inverted in DeltaSkinThumbstick (positive Y = up, negative Y = down)
        let up = y > threshold
        let down = y < -threshold
        let left = x < -threshold
        let right = x > threshold

        // Check if joystick is centered (released)
        let isCentered = abs(x) < threshold && abs(y) < threshold

        // Get previous state
        let prevX = previousJoystickState?.x ?? 0
        let prevY = previousJoystickState?.y ?? 0
        let prevUp = prevY > threshold
        let prevDown = prevY < -threshold
        let prevLeft = prevX < -threshold
        let prevRight = prevX > threshold

        // Update previous state
        previousJoystickState = (x: x, y: y)

        // If joystick is centered, release all buttons
        if isCentered {
            if prevUp { sendDPadButton("up", isPressed: false, systemId: systemId, core: core) }
            if prevDown { sendDPadButton("down", isPressed: false, systemId: systemId, core: core) }
            if prevLeft { sendDPadButton("left", isPressed: false, systemId: systemId, core: core) }
            if prevRight { sendDPadButton("right", isPressed: false, systemId: systemId, core: core) }
            return
        }

        // Release buttons that are no longer active
        if prevUp && !up { sendDPadButton("up", isPressed: false, systemId: systemId, core: core) }
        if prevDown && !down { sendDPadButton("down", isPressed: false, systemId: systemId, core: core) }
        if prevLeft && !left { sendDPadButton("left", isPressed: false, systemId: systemId, core: core) }
        if prevRight && !right { sendDPadButton("right", isPressed: false, systemId: systemId, core: core) }

        // Press buttons that are newly active
        if up && !prevUp { sendDPadButton("up", isPressed: true, systemId: systemId, core: core) }
        if down && !prevDown { sendDPadButton("down", isPressed: true, systemId: systemId, core: core) }
        if left && !prevLeft { sendDPadButton("left", isPressed: true, systemId: systemId, core: core) }
        if right && !prevRight { sendDPadButton("right", isPressed: true, systemId: systemId, core: core) }
    }

    /// Send D-pad button press/release using system-specific responder
    private func sendDPadButton(_ buttonId: String, isPressed: Bool, systemId: SystemIdentifier, core: PVEmulatorCore) {
        let id = normalizeSkinButtonId(buttonId, for: systemId)

        switch systemId {
        case .CDi:
            if let r = core as? PVCDiSystemResponderClient {
                let b = PVCDiButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .ColecoVision:
            if let r = core as? PVColecoVisionSystemResponderClient {
                let b = PVColecoVisionButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PSX:
            if let r = core as? PVPSXSystemResponderClient {
                let b = PVPSXButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Genesis, .SegaCD:
            if let r = core as? PVGenesisSystemResponderClient {
                let b = PVGenesisButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Sega32X:
            if let r = core as? PVSega32XSystemResponderClient {
                let b = PVSega32XButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .SNES:
            if let r = core as? PVSNESSystemResponderClient {
                let b = PVSNESButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .NES, .FDS:
            if let r = core as? PVNESSystemResponderClient {
                let b = PVNESButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .GBA:
            if let r = core as? PVGBASystemResponderClient {
                let b = PVGBAButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .GB, .GBC:
            if let r = core as? PVGBSystemResponderClient {
                let b = PVGBButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .N64:
            if let r = core as? PVN64SystemResponderClient {
                let b = PVN64Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PSP:
            if let r = core as? PVPSPSystemResponderClient {
                let b = PVPSPButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PS2, .PS3:
            if let r = core as? PVPS2SystemResponderClient {
                let b = PVPS2Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Saturn:
            if let r = core as? PVSaturnSystemResponderClient {
                let b = PVSaturnButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Dreamcast:
            if let r = core as? PVDreamcastSystemResponderClient {
                let b = PVDreamcastButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PCE:
            if let r = core as? PVPCESystemResponderClient {
                let b = PVPCEButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PCECD:
            if let r = core as? PVPCECDSystemResponderClient {
                let b = PVPCECDButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .MasterSystem:
            if let r = core as? PVMasterSystemSystemResponderClient {
                let b = PVMasterSystemButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .GameGear:
            if let r = core as? PVGenesisSystemResponderClient {
                let b = PVGenesisButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .AtariJaguar, .AtariJaguarCD:
            if let r = core as? PVJaguarSystemResponderClient {
                let b = PVJaguarButton(id)
                isPressed ? r.didPush(jaguarButton: b, forPlayer: 0) : r.didRelease(jaguarButton: b, forPlayer: 0)
            }
        case .NeoGeo:
            if let r = core as? PVNeoGeoSystemResponderClient {
                let b = PVNeoGeoButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .MAME, .CPS1, .CPS2, .CPS3:
            if let r = core as? PVMAMESystemResponderClient {
                let b = PVMAMEButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .DS:
            if let r = core as? PVDSSystemResponderClient {
                let b = PVDSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case ._3DS:
            if let r = core as? PV3DSSystemResponderClient {
                let b = PV3DSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case ._3DO:
            if let r = core as? PV3DOSystemResponderClient {
                let b = PV3DOButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .WonderSwan, .WonderSwanColor:
            if let r = core as? PVWonderSwanSystemResponderClient {
                let b = PVWSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .VirtualBoy:
            if let r = core as? PVVirtualBoySystemResponderClient {
                /// VirtualBoy requires specific button names: leftUp, leftDown, leftLeft, leftRight for D-pad
                /// The normalizeSkinButtonId should have already converted "up" -> "leftUp", etc.
                /// But PVVBButton.init also accepts "up", "down", etc. as aliases, so both should work
                let b = PVVBButton(id)
                DLOG("VirtualBoy button: original=\(buttonId), normalized=\(id), PVVBButton=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Atari2600:
            if let r = core as? PV2600SystemResponderClient {
                let b = PV2600Button(id)
                DLOG("Atari2600 button: original=\(buttonId), normalized=\(id), PV2600Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Atari5200:
            if let r = core as? PV5200SystemResponderClient {
                let b = PV5200Button(id)
                DLOG("PV5200Button button: original=\(buttonId), normalized=\(id), PV2600Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Atari7800:
            if let r = core as? PV7800SystemResponderClient {
                let b = PV7800Button(id)
                DLOG("PV7800Button button: original=\(buttonId), normalized=\(id), PV2600Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Vectrex:
            if let r = core as? PVVectrexSystemResponderClient {
                let b = PVVectrexButton(id)
                DLOG("Vectrex button: original=\(buttonId), normalized=\(id), PVVectrexButton=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Atari8bit:
            if let r = core as? PVA8SystemResponderClient {
                let b = PVA8Button(id)
                DLOG("Atari8bit button: original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .AtariST:
            /// AtariST uses PVA8Button but goes through RetroArch responder
            /// Try PVA8SystemResponderClient first, then fall back to RetroArch
            if let r = core as? PVA8SystemResponderClient {
                let b = PVA8Button(id)
                DLOG("AtariST button (via PVA8): original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PCFX, .SGFX:
            if let r = core as? PVPCFXSystemResponderClient {
                let b = PVPCFXButton(id)
                DLOG("PVPFXButton button (via PVA8): original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .MSX, .MSX2:
            if let r = core as? PVMSXSystemResponderClient {
                let b = PVMSXButton(id)
                DLOG("PVMSXButton button (via PVA8): original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .NGP, .NGPC:
            if let r = core as? PVNeoGeoPocketSystemResponderClient {
                let b = PVNGPButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Lynx:
            if let r = core as? PVLynxSystemResponderClient {
                let b = PVLynxButton(id)
                isPressed ? r.didPush(LynxButton: b, forPlayer: 0) : r.didRelease(LynxButton: b, forPlayer: 0)
            }
        case .Intellivision:
            if let r = core as? PVIntellivisionSystemResponderClient {
                let b = PVIntellivisionButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Odyssey2:
            if let r = core as? PVOdyssey2SystemResponderClient {
                let b = PVOdyssey2Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .PokemonMini:
            if let r = core as? PVPokeMiniSystemResponderClient {
                let b = PVPMButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .SG1000:
            if let r = core as? PVSG1000SystemResponderClient {
                let b = PVSG1000Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Supervision:
            if let r = core as? PVSupervisionSystemResponderClient {
                let b = PVSupervisionButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .Wii:
            if let r = core as? PVWiiSystemResponderClient {
                let b = PVWiiMoteButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .GameCube:
            if let r = core as? PVGameCubeSystemResponderClient {
                let b = PVGCButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .EP128:
            if let r = core as? PVEP128SystemResponderClient {
                let b = PVEP128Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .DOS, .DOOM, .Wolf3D, .Macintosh, .AppleII, .Quake, .Quake2, .TIC80, .ZXSpectrum:
            if let r = core as? PVDOSSystemResponderClient {
                let b = PVDOSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)

            }
        default:
            // For other systems, try generic approach
            DLOG("No specific D-pad handler for system \(systemId), attempting generic")
            break
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
            "a", "b", "c", "x", "y", "z",
            // Numberic buttons
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            // Numpad buttons
            "#", "*", "(", ")", "+", "-", ".", "/",
            // PCFX buttons
            "i", "ii", "iii", "iv", "v", "vi", "vii", "viii",
            // Shoulder buttons
            "l", "r", "l1", "r1", "l2", "r2", "l3", "r3",
            // Other
            "mode", "cdbc", "option", "pause",
            // N64
            "c▲", "▲", "▼", "c▼", "c←", "←", "c→", "→", "c◄", "◄", "c►", "►", "c↗", "↗", "c↘", "↘", "c◀", "◀", "c▶", "▶", "c▼", "▼",
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

        // Try to forward directly to the core for standard buttons
        if forwardButtonPressToSystemSpecificCore(normalizedId, isPressed: isPressed) {
            return
        }

        // Try to find the button in the controller view
        if let button = findButtonInControllerView(controller.view, withLabel: normalizedId) {
            DLOG("Found button with label \(normalizedId) in controller view")
            if isPressed {
                controller.buttonPressed(button)
            } else {
                controller.buttonReleased(button)
            }
            return
        }

        // Handle shoulder buttons
        if handleShoulderButtons(normalizedId, isPressed: isPressed, controller: controller) {
            return
        }

        DLOG("Unhandled controller button \(isPressed ? "press" : "release"): \(buttonId)")
    }

    /// Handle special buttons (D-pad, Start, Select)
    private func handleSpecialButtons(_ buttonId: String, isPressed: Bool, controller: any ControllerVC) -> Bool {
        // Map common start button variations
        let startVariations = ["start", "run", "play", "option", "pause"]
        let selectVariations = ["select", "mode", "option", "pause"]

        // Check if this is a start button
        if startVariations.contains(buttonId.lowercased()) {
            if isPressed {
                DLOG("Calling controller.pressStart for button: \(buttonId)")
                controller.pressStart(forPlayer: 0)
                // Add haptic feedback
#if os(iOS) && !targetEnvironment(macCatalyst)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
#endif
            } else {
                DLOG("Calling controller.releaseStart for button: \(buttonId)")
                controller.releaseStart(forPlayer: 0)
            }
            return true
        }

        // Check if this is a select button
        if selectVariations.contains(buttonId.lowercased()) {
            if isPressed {
                DLOG("Calling controller.pressSelect for button: \(buttonId)")
                controller.pressSelect(forPlayer: 0)
                // Add haptic feedback
#if os(iOS) && !targetEnvironment(macCatalyst)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
#endif
            } else {
                DLOG("Calling controller.releaseSelect for button: \(buttonId)")
                controller.releaseSelect(forPlayer: 0)
            }
            return true
        }

        // D-pad directions
        let dpadDirections = ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"]
        if dpadDirections.contains(buttonId.lowercased()) {
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
        }

        // No special button matched
        return false
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

    /// Find a button in the controller view with the given label (searches all button groups)
    private func findButtonInControllerView(_ view: UIView, withLabel label: String) -> JSButton? {
        DLOG("Searching for button with label: \(label) in view: \(view)")

        // Normalize the input label for case-insensitive comparison
        let normalizedLabel = label.lowercased()

        // First try to find the button directly in the view's subviews
        for case let button as JSButton in view.subviews {
            if let buttonText = button.titleLabel?.text {
                let buttonLabel = buttonText.lowercased()
                DLOG("Found button with label: \(buttonText)")

                // Case-insensitive match
                if buttonLabel == normalizedLabel {
                    DLOG("MATCH FOUND for \(label) -> \(buttonLabel)")
                    return button
                }

                // First character match as fallback
                if buttonLabel.first?.lowercased() == normalizedLabel.first?.lowercased() {
                    DLOG("FIRST CHAR MATCH FOUND for \(label) -> \(buttonLabel)")
                    return button
                }
            }
        }

        // Then recursively search through all subviews (including button groups)
        for subview in view.subviews {
            // If this is a button group, search through its buttons directly
            if let buttonGroup = subview as? MovableButtonView {
                DLOG("Searching button group: \(buttonGroup)")
                for case let button as JSButton in buttonGroup.subviews {
                    if let buttonText = button.titleLabel?.text {
                        let buttonLabel = buttonText.lowercased()
                        DLOG("Found button in group with label: \(buttonText)")

                        // Case-insensitive match
                        if buttonLabel == normalizedLabel {
                            DLOG("MATCH FOUND in group for \(label) -> \(buttonLabel)")
                            return button
                        }

                        // First character match as fallback
                        if buttonLabel.first?.lowercased() == normalizedLabel.first?.lowercased() {
                            DLOG("FIRST CHAR MATCH FOUND in group for \(label) -> \(buttonLabel)")
                            return button
                        }
                    }
                }
            }

            // Recursively search through other subviews
            if let button = findButtonInControllerView(subview, withLabel: label) {
                return button
            }
        }

        return nil
    }



    /// Forward button press directly to the system-specific core
    private func forwardButtonPressToSystemSpecificCore(_ buttonId: String, isPressed: Bool) -> Bool {
        guard let core = emulatorCore else {
            return false
        }

        // Map common button IDs to their indices
        var buttonIndex: Int? = nil

        switch buttonId.lowercased() {
        case "a":
            buttonIndex = 0 // Most systems use 0 for A button
        case "b":
            buttonIndex = 1 // Most systems use 1 for B button
        case "x":
            buttonIndex = 2 // Most systems use 2 for X button
        case "y":
            buttonIndex = 3 // Most systems use 3 for Y button
        case "c":
            buttonIndex = 4 // Some systems use 4 for C button
        case "1":
            buttonIndex = 5 // Numeric buttons (for systems like Jaguar)
        case "2":
            buttonIndex = 6
        case "3":
            buttonIndex = 7
        case "4":
            buttonIndex = 8
        case "5":
            buttonIndex = 9
        case "6":
            buttonIndex = 10
        case "7":
            buttonIndex = 11
        case "8":
            buttonIndex = 12
        case "9":
            buttonIndex = 13
        case "0":
            buttonIndex = 14
        case "#":
            buttonIndex = 15
        case "*":
            buttonIndex = 16
        default:
            return false
        }

        if let index = buttonIndex {
            if isPressed {
                if let responder = core as? PVControllerResponder {
                    responder.controllerPressedButton(index, forPlayer: 0)
                    return true
                }
            } else {
                if let responder = core as? PVControllerResponder {
                    responder.controllerReleasedButton(index, forPlayer: 0)
                    return true
                }
            }
        }

        return false
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
        guard let core = emulatorCore else {
            ELOG("Cannot forward button press - emulatorCore is nil")
            return
        }

        // Normalize the button ID
        let normalizedId = buttonId.lowercased()

        // Log system info for debugging
        if let systemId = core.systemIdentifier {
            DLOG("Forwarding button \(isPressed ? "press" : "release"): \(buttonId) (normalized: \(normalizedId)) for system: \(systemId)")
        }

        // Prefer direct system-specific responder path (works best for RA and native cores)
        if trySystemResponderCall(normalizedId, isPressed: isPressed, core: core) {
            DLOG("✅ Button handled via system-specific responder: \(normalizedId)")
            return
        }

        DLOG("⚠️ System-specific responder did not handle button, trying fallback methods: \(normalizedId)")

        // Use system-specific button handling if we have a controller VC
        if let controllerVC = controllerVC {
            DLOG("Using controller VC for button mapping: \(normalizedId)")
            // Forward to the controller VC which knows how to map buttons for specific systems
            forwardButtonPressToSystemSpecificCore(normalizedId, isPressed: isPressed, core: core, controllerVC: controllerVC)
        } else {
            // Fallback to generic mapping if we don't have a controller VC
            DLOG("No controller VC available, using generic mapping: \(normalizedId)")
            let buttonIndex = mapButtonToIndex(normalizedId)
            DLOG("Mapped button \(normalizedId) to index \(buttonIndex)")

            if isPressed {
                DLOG("Pressing button (generic mapping): \(normalizedId) (index: \(buttonIndex))")
                // Try different methods that might be available
                if let responder = core as? PVControllerResponder {
                    DLOG("Core conforms to PVControllerResponder, calling controllerPressedButton")
                    responder.controllerPressedButton(buttonIndex, forPlayer: 0)
                } else {
                    DLOG("Core does not conform to PVControllerResponder, posting notification")
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
                    DLOG("Core conforms to PVControllerResponder, calling controllerReleasedButton")
                    responder.controllerReleasedButton(buttonIndex, forPlayer: 0)
                } else {
                    DLOG("Core does not conform to PVControllerResponder, posting notification")
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
        // Get the system identifier from the emulator core
        guard let systemIdentifier = core.systemIdentifier else {
            ELOG("No system identifier available, falling back to generic mapping")
            fallbackToGenericMapping(buttonId, isPressed: isPressed, core: core)
            return
        }

        // Convert the string system identifier to a SystemIdentifier enum
        guard let systemId = SystemIdentifier(rawValue: systemIdentifier) else {
            ELOG("Invalid system identifier: \(systemIdentifier), falling back to generic mapping")
            fallbackToGenericMapping(buttonId, isPressed: isPressed, core: core)
            return
        }

        DLOG("Using system-specific button mapping for system: \(systemId)")

        // Get the button type for this system
        let buttonType = systemId.controllerType

        // Create a button instance from the normalized string
        let button = buttonType.init(normalizeSkinButtonId(buttonId, for: systemId))

        // Get the raw value (button index)
        let buttonIndex = button.rawValue

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

    /// Try calling the typed system responder protocol if the core supports it
    /// Returns true if the call was handled.
    private func trySystemResponderCall(_ buttonId: String, isPressed: Bool, core: PVEmulatorCore) -> Bool {
        guard let systemIdentifier = core.systemIdentifier, let systemId = SystemIdentifier(rawValue: systemIdentifier) else {
            DLOG("Cannot determine system identifier for core")
            return false
        }

        DLOG("trySystemResponderCall: buttonId=\(buttonId), systemId=\(systemId)")
        let id = normalizeSkinButtonId(buttonId, for: systemId).trimmingCharacters(in: .whitespacesAndNewlines)
        DLOG("Normalized button ID: \(buttonId) -> \(id) for system \(systemId)")

        switch systemId {
        case .CDi:
            if let r = core as? PVCDiSystemResponderClient {
                let b = PVCDiButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
            }
        case .ColecoVision:
            if let r = core as? PVColecoVisionSystemResponderClient {
                let b = PVColecoVisionButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .PSX:
            if let r = core as? PVPSXSystemResponderClient {
                let b = PVPSXButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Genesis, .SegaCD:
            if let r = core as? PVGenesisSystemResponderClient {
                let b = PVGenesisButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Sega32X:
            if let r = core as? PVSega32XSystemResponderClient {
                let b = PVSega32XButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .SNES:
            if let r = core as? PVSNESSystemResponderClient {
                let b = PVSNESButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .NES, .FDS:
            if let r = core as? PVNESSystemResponderClient {
                let b = PVNESButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .GBA:
            if let r = core as? PVGBASystemResponderClient {
                let b = PVGBAButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .GB, .GBC:
            if let r = core as? PVGBSystemResponderClient {
                let b = PVGBButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .N64:
            if let r = core as? PVN64SystemResponderClient {
                let b = PVN64Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .PSP:
            if let r = core as? PVPSPSystemResponderClient {
                let b = PVPSPButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .PS2, .PS3:
            if let r = core as? PVPS2SystemResponderClient {
                let b = PVPS2Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Saturn:
            if let r = core as? PVSaturnSystemResponderClient {
                let b = PVSaturnButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Dreamcast:
            if let r = core as? PVDreamcastSystemResponderClient {
                let b = PVDreamcastButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .PCE:
            if let r = core as? PVPCESystemResponderClient {
                let b = PVPCEButton(id)
                DLOG("PCE button: original=\(buttonId), normalized=\(id), PVPCEButton=\(b.stringValue), rawValue=\(b.rawValue)")
                if b == .up && id != "up" && !["up", "down", "left", "right"].contains(id.lowercased()) {
                    ELOG("⚠️ PCE button '\(id)' defaulted to .up - check normalization!")
                }
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            } else {
                ELOG("Core expcted to be `PVPCESystemResponderClient` but isn't.")
                //return false
            }
        case .PCECD:
            if let r = core as? PVPCECDSystemResponderClient {
                let b = PVPCECDButton(id)
                DLOG("PCECD button: original=\(buttonId), normalized=\(id), PVPCECDButton=\(b.stringValue), rawValue=\(b.rawValue)")
                if b == .up && id != "up" && !["up", "down", "left", "right"].contains(id.lowercased()) {
                    ELOG("⚠️ PCECD button '\(id)' defaulted to .up - check normalization!")
                }
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            } else {
                ELOG("Core expcted to be `PVPCECDSystemResponderClient` but isn't.")
                //return false
            }
        case .MasterSystem:
            if let r = core as? PVMasterSystemSystemResponderClient {
                let b = PVMasterSystemButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .GameGear:
            if let r = core as? PVGenesisSystemResponderClient {
                let b = PVGenesisButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .AtariJaguar, .AtariJaguarCD:
            if let r = core as? PVJaguarSystemResponderClient {
                let b = PVJaguarButton(id)
                isPressed ? r.didPush(jaguarButton: b, forPlayer: 0) : r.didRelease(jaguarButton: b, forPlayer: 0)
                return true
            }
        case .NeoGeo:
            if let r = core as? PVNeoGeoSystemResponderClient {
                let b = PVNeoGeoButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .MAME, .CPS1, .CPS2, .CPS3:
            if let r = core as? PVMAMESystemResponderClient {
                let b = PVMAMEButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .DS:
            if let r = core as? PVDSSystemResponderClient {
                let b = PVDSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case ._3DS:
            if let r = core as? PV3DSSystemResponderClient {
                let b = PV3DSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case ._3DO:
            if let r = core as? PV3DOSystemResponderClient {
                let b = PV3DOButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .WonderSwan, .WonderSwanColor:
            if let r = core as? PVWonderSwanSystemResponderClient {
                let b = PVWSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .VirtualBoy:
            if let r = core as? PVVirtualBoySystemResponderClient {
                /// VirtualBoy requires specific button names: leftUp, leftDown, leftLeft, leftRight for D-pad
                /// The normalizeSkinButtonId should have already converted "up" -> "leftUp", etc.
                /// But PVVBButton.init also accepts "up", "down", etc. as aliases, so both should work
                let b = PVVBButton(id)
                DLOG("VirtualBoy button: original=\(buttonId), normalized=\(id), PVVBButton=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Atari2600:
            if let r = core as? PV2600SystemResponderClient {
                let b = PV2600Button(id)
                DLOG("Atari2600 button: original=\(buttonId), normalized=\(id), PV2600Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Atari5200:
            if let r = core as? PV5200SystemResponderClient {
                let b = PV5200Button(id)
                DLOG("PV5200Button button: original=\(buttonId), normalized=\(id), PV2600Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Atari7800:
            if let r = core as? PV7800SystemResponderClient {
                let b = PV7800Button(id)
                DLOG("PV7800Button button: original=\(buttonId), normalized=\(id), PV2600Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Vectrex:
            if let r = core as? PVVectrexSystemResponderClient {
                let b = PVVectrexButton(id)
                DLOG("Vectrex button: original=\(buttonId), normalized=\(id), PVVectrexButton=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Atari8bit:
            if let r = core as? PVA8SystemResponderClient {
                let b = PVA8Button(id)
                DLOG("Atari8bit button: original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .AtariST:
            /// AtariST uses PVA8Button but goes through RetroArch responder
            /// Try PVA8SystemResponderClient first, then fall back to RetroArch
            if let r = core as? PVA8SystemResponderClient {
                let b = PVA8Button(id)
                DLOG("AtariST button (via PVA8): original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .PCFX, .SGFX:
            if let r = core as? PVPCFXSystemResponderClient {
                let b = PVPCFXButton(id)
                DLOG("PVPFXButton button (via PVA8): original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .MSX, .MSX2:
            if let r = core as? PVMSXSystemResponderClient {
                let b = PVMSXButton(id)
                DLOG("PVMSXButton button (via PVA8): original=\(buttonId), normalized=\(id), PVA8Button=\(b.stringValue)")
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .NGP, .NGPC:
            if let r = core as? PVNeoGeoPocketSystemResponderClient {
                let b = PVNGPButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Lynx:
            if let r = core as? PVLynxSystemResponderClient {
                let b = PVLynxButton(id)
                isPressed ? r.didPush(LynxButton: b, forPlayer: 0) : r.didRelease(LynxButton: b, forPlayer: 0)
                return true
            }
        case .Intellivision:
            if let r = core as? PVIntellivisionSystemResponderClient {
                let b = PVIntellivisionButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Odyssey2:
            if let r = core as? PVOdyssey2SystemResponderClient {
                let b = PVOdyssey2Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .PokemonMini:
            if let r = core as? PVPokeMiniSystemResponderClient {
                let b = PVPMButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .SG1000:
            if let r = core as? PVSG1000SystemResponderClient {
                let b = PVSG1000Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Supervision:
            if let r = core as? PVSupervisionSystemResponderClient {
                let b = PVSupervisionButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .Wii:
            if let r = core as? PVWiiSystemResponderClient {
                let b = PVWiiMoteButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .GameCube:
            if let r = core as? PVGameCubeSystemResponderClient {
                let b = PVGCButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .EP128:
            if let r = core as? PVEP128SystemResponderClient {
                let b = PVEP128Button(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        case .DOS, .DOOM, .Wolf3D, .Macintosh, .AppleII, .Quake, .Quake2, .TIC80, .ZXSpectrum:
            if let r = core as? PVDOSSystemResponderClient {
                let b = PVDOSButton(id)
                isPressed ? r.didPush(b, forPlayer: 0) : r.didRelease(b, forPlayer: 0)
                return true
            }
        default:
            break
        }

        /// Fallback for systems that use PVRetroArchCoreResponderClient
        /// These systems don't have specific responder protocols but use ButtonResponder/JoystickResponder
        /// Check if this system's responderClientType is PVRetroArchCoreResponderClient or if core conforms to it
        let usesRetroArchResponder = String(describing: systemId.responderClientType).contains("PVRetroArchCoreResponderClient") || core is PVRetroArchCoreResponderClient
        if usesRetroArchResponder {
            DLOG("System uses PVRetroArchCoreResponderClient, using controllerType fallback: \(systemId)")

            /// Use the system's controllerType to get the appropriate button enum
            let buttonType = systemId.controllerType
            let button = buttonType.init(id)
            let buttonIndex = button.rawValue

            DLOG("RetroArch button: original=\(buttonId), normalized=\(id), buttonIndex=\(buttonIndex)")

            /// Use PVControllerResponder to send button press/release
            if let responder = core as? PVControllerResponder {
                if isPressed {
                    responder.controllerPressedButton(buttonIndex, forPlayer: 0)
                } else {
                    responder.controllerReleasedButton(buttonIndex, forPlayer: 0)
                }
                return true
            } else {
                /// If PVControllerResponder is not available, try JoystickResponder for D-pad
                /// or fall back to notifications
                DLOG("Core does not conform to PVControllerResponder, trying JoystickResponder or notifications")
                if isPressed {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ButtonPressed"),
                        object: nil,
                        userInfo: ["button": buttonIndex, "player": 0]
                    )
                } else {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ButtonReleased"),
                        object: nil,
                        userInfo: ["button": buttonIndex, "player": 0]
                    )
                }
                return true
            }
        }

        return false
    }

    /// Convert Unicode Roman numerals to ASCII equivalents
    /// Handles both uppercase (Ⅰ, Ⅱ, Ⅲ, Ⅳ, Ⅴ, Ⅵ) and lowercase (ⅰ, ⅱ, ⅲ, ⅳ, ⅴ, ⅵ)
    private func normalizeRomanNumerals(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "ⅰ", with: "i")  // U+2170 SMALL ROMAN NUMERAL ONE
            .replacingOccurrences(of: "ⅱ", with: "ii") // U+2171 SMALL ROMAN NUMERAL TWO
            .replacingOccurrences(of: "ⅲ", with: "iii") // U+2172 SMALL ROMAN NUMERAL THREE
            .replacingOccurrences(of: "ⅳ", with: "iv") // U+2173 SMALL ROMAN NUMERAL FOUR
            .replacingOccurrences(of: "ⅴ", with: "v")  // U+2174 SMALL ROMAN NUMERAL FIVE
            .replacingOccurrences(of: "ⅵ", with: "vi") // U+2175 SMALL ROMAN NUMERAL SIX
            .replacingOccurrences(of: "Ⅰ", with: "i")  // U+2160 ROMAN NUMERAL ONE
            .replacingOccurrences(of: "Ⅱ", with: "ii") // U+2161 ROMAN NUMERAL TWO
            .replacingOccurrences(of: "Ⅲ", with: "iii") // U+2162 ROMAN NUMERAL THREE
            .replacingOccurrences(of: "Ⅳ", with: "iv") // U+2163 ROMAN NUMERAL FOUR
            .replacingOccurrences(of: "Ⅴ", with: "v")  // U+2164 ROMAN NUMERAL FIVE
            .replacingOccurrences(of: "Ⅵ", with: "vi") // U+2165 ROMAN NUMERAL SIX
    }

    /// Normalize skin button IDs to canonical names per system
    private func normalizeSkinButtonId(_ id: String, for system: SystemIdentifier) -> String {
        let s = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch system {
        case .PSX, .PS2, .PSP:
            // Prefer PS shape names/symbols
            /*
             case "triangle", "x", "▵": self = .triangle
             case "circle", "a", "○": self = .circle
             case "cross", "b", "✕": self = .cross
             case "square", "y", "□": self = .square
             */
            if ["△", "tri", "triangle", "▵", "x"].contains(s) { return "triangle" }
            if ["□", "sq", "square", "y"].contains(s) { return "square" }
            if ["○", "cir", "circle", "a"].contains(s) { return "circle" }
            if ["✕", "cro", "cross", "b"].contains(s) { return "cross" }
        case .VirtualBoy:
            /// VirtualBoy has unique D-pad buttons (leftUp, leftDown, etc.)
            /// Convert standard D-pad directions to VirtualBoy-specific names
            if ["up", "leftup"].contains(s) { return "leftUp" }
            if ["down", "leftdown"].contains(s) { return "leftDown" }
            if ["left", "leftleft"].contains(s) { return "leftLeft" }
            if ["right", "leftright"].contains(s) { return "leftRight" }
            /// VirtualBoy uses "l" and "r" directly (not "l1"/"r1")
            /// Handle shoulder button variations
            if ["l", "l1", "lb", "lshoulder", "shoulderleft"].contains(s) { return "l" }
            if ["r", "r1", "rb", "rshoulder", "shoulderright"].contains(s) { return "r" }
            /// Regular buttons use standard names
            if ["a", "b", "start", "select"].contains(s) { return s }
        case .NES, .FDS, .Music:
            /// NES button normalization - only supports: up, down, left, right, a, b, start, select
            /// Filter out invalid buttons (NES doesn't have L/R, X/Y, etc.)
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b"].contains(s) { return s }
            if ["start", "select"].contains(s) { return s }
            /// NES doesn't support these buttons, so return original to let PVNESButton handle it
            /// (it will default to .up for unknown values, but at least we tried)
            return s
        case .SNES:
            /// SNES button normalization - supports: up, down, left, right, a, b, x, y, l, r, start, select
            /// PVSNESButton.init handles L/R variations (l, l1, lb, etc.) internally
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b", "x", "y"].contains(s) { return s }
            /// L/R buttons - PVSNESButton handles variations like "l", "l1", "lb", "triggerleft", etc.
            if ["l", "l1", "lb", "leftshoulder", "shoulderleft", "triggerleft"].contains(s) { return "l" }
            if ["r", "r1", "rb", "rightshoulder", "shoulderright", "triggerright"].contains(s) { return "r" }
            if ["start", "select"].contains(s) { return s }
            return s
        case .Genesis, .SegaCD:
            if ["a", "b", "c", "x", "y", "z"].contains(s) { return s }
        case .Sega32X:
            // 32X uses "mode" instead of "select"
            if s == "select" { return "mode" }
            if ["a", "b", "c", "x", "y", "z", "start", "mode"].contains(s) { return s }
        case .Atari2600:
            // Atari 2600 button normalization
            // D-pad directions
            if ["up", "down", "left", "right"].contains(s) { return s }
            // Fire button (maps to fire1)
            if ["fire", "fire1", "a", "b", "x", "y"].contains(s) { return "fire1" }
            // Reset (start button on Atari 2600)
            if ["reset", "start", "run", "play"].contains(s) { return "reset" }
            // Select
            if s == "select" { return "select" }
            // Difficulty switches
            if ["leftdiffa", "leftdiffb", "rightdiffa", "rightdiffb"].contains(s) { return s }
        case .Vectrex:
            /// Vectrex uses analog directions and numbered buttons
            /// D-pad directions map to analog directions
            if ["up", "analogup"].contains(s) { return "up" }
            if ["down", "analogdown"].contains(s) { return "down" }
            if ["left", "analogleft"].contains(s) { return "left" }
            if ["right", "analogright"].contains(s) { return "right" }
            /// Buttons map to button1-4
            if ["button1", "1", "i", "a"].contains(s) { return "button1" }
            if ["button2", "2", "ii", "b"].contains(s) { return "button2" }
            if ["button3", "3", "iii", "x"].contains(s) { return "button3" }
            if ["button4", "4", "iv", "y"].contains(s) { return "button4" }
        case .Atari8bit:
            /// Atari 8-bit uses D-pad directions and fire button
            if ["up", "down", "left", "right"].contains(s) { return s }
            /// Fire button maps to fire
            if ["fire", "fire1", "a", "b", "x", "y"].contains(s) { return "fire" }
        case .AtariST:
            /// AtariST uses same button mapping as Atari 8-bit (PVA8Button)
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["fire", "fire1", "a", "b", "x", "y"].contains(s) { return "fire" }
        case ._3DS:
            // 3DS uses standard button names
            if ["a", "b", "x", "y", "l", "r", "zl", "zr", "start", "select", "up", "down", "left", "right"].contains(s) { return s }
            // Map l1/l2/r1/r2 to l/r/zl/zr for 3DS
            if s == "l1" { return "l" }
            if s == "r1" { return "r" }
            if s == "l2" { return "zl" }
            if s == "r2" { return "zr" }
        case ._3DO:
            // 3DO button normalization
            // D-pad directions
            if ["up", "down", "left", "right"].contains(s) { return s }
            // Action buttons
            if ["a", "b", "c"].contains(s) { return s }
            // Shoulder buttons (PV3DOButton handles "l"/"l1" -> L and "r"/"r1" -> R)
            if ["l", "l1"].contains(s) { return "l" }
            if ["r", "r1"].contains(s) { return "r" }
            // Special buttons
            if ["p", "x"].contains(s) { return s }
        case .N64:
            // N64 button normalization
            // D-pad directions
            if ["up", "down", "left", "right"].contains(s) { return s }
            // C-buttons (handle various formats)
            if ["c▲", "cup", "c-up", "c up"].contains(s) { return "c▲" }
            if ["c▼", "cdown", "c-down", "c down"].contains(s) { return "c▼" }
            if ["c◀", "cleft", "c-left", "c left"].contains(s) { return "c◀" }
            if ["c▶", "cright", "c-right", "c right"].contains(s) { return "c▶" }
            // Action buttons
            if ["a", "b"].contains(s) { return s }
            // Z button: both "x" and "z" map to "z" for N64
            if ["z", "x"].contains(s) { return "z" }
            // Shoulder buttons: N64 uses "l" and "r" directly (not "l1"/"r1")
            if ["l", "l1", "lb", "lshoulder", "shoulderleft"].contains(s) { return "l" }
            if ["r", "r1", "rb", "rshoulder", "shoulderright"].contains(s) { return "r" }
            // Start button
            if ["start"].contains(s) { return s }
            // Analog stick directions
            if ["analog-up", "analogup"].contains(s) { return "analog-up" }
            if ["analog-down", "analogdown"].contains(s) { return "analog-down" }
            if ["analog-left", "analogleft"].contains(s) { return "analog-left" }
            if ["analog-right", "analogright"].contains(s) { return "analog-right" }
            if ["left-analog", "leftanalog"].contains(s) { return "left-analog" }
        case .GBA:
            /// GBA button normalization - supports: up, down, left, right, a, b, l, r, start, select
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b"].contains(s) { return s }
            if ["l", "l1"].contains(s) { return "l" }
            if ["r", "r1"].contains(s) { return "r" }
            if ["start", "select"].contains(s) { return s }
            return s
        case .GB, .GBC:
            /// GB/GBC button normalization - supports: up, down, left, right, a, b, start, select
            /// PVGBButton maps x->a and y->b
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "x"].contains(s) { return "a" }
            if ["b", "y"].contains(s) { return "b" }
            if ["start", "select"].contains(s) { return s }
            return s
        case .Saturn:
            /// Saturn button normalization - supports: up, down, left, right, a, b, c, x, y, z, l, r, start
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b", "c", "x", "y", "z"].contains(s) { return s }
            if ["l", "l1"].contains(s) { return "l" }
            if ["r", "r1"].contains(s) { return "r" }
            if ["start"].contains(s) { return s }
            return s
        case .Dreamcast:
            /// Dreamcast button normalization - supports: up, down, left, right, a, b, x, y, l, r, start
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b", "x", "y"].contains(s) { return s }
            if ["l", "l1"].contains(s) { return "l" }
            if ["r", "r1"].contains(s) { return "r" }
            if ["start"].contains(s) { return s }
            return s
        case .PCE, .PCECD:
            /// PCE/PCECD button normalization - supports: up, down, left, right, button1-6, run, select, mode
            /// Also handles Unicode Roman numerals (ⅰ, ⅱ, ⅲ, ⅳ, ⅴ, ⅵ and Ⅰ, Ⅱ, Ⅲ, Ⅳ, Ⅴ, Ⅵ)
            let normalized = normalizeRomanNumerals(s)
            if ["up", "down", "left", "right"].contains(normalized) { return normalized }
            if ["button1", "1", "i", "a"].contains(normalized) { return "button1" }
            if ["button2", "2", "ii", "b"].contains(normalized) { return "button2" }
            if ["button3", "3", "iii", "x"].contains(normalized) { return "button3" }
            if ["button4", "4", "iv", "y"].contains(normalized) { return "button4" }
            if ["button5", "5", "v"].contains(normalized) { return "button5" }
            if ["button6", "6", "vi"].contains(normalized) { return "button6" }
            if ["run", "start"].contains(normalized) { return "run" }
            if ["select"].contains(normalized) { return "select" }
            if ["mode"].contains(normalized) { return "mode" }
            return normalized
        case .MasterSystem:
            /// MasterSystem button normalization - supports: up, down, left, right, b, c, start
            /// PVMasterSystemButton maps a->b and x/y->c
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["b", "a"].contains(s) { return "b" }
            if ["c", "x", "y"].contains(s) { return "c" }
            if ["start"].contains(s) { return s }
            return s
        case .AtariJaguar, .AtariJaguarCD:
            /// Jaguar button normalization - supports: up, down, left, right, a, b, c, pause, option, button1-9, 0, *, #
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a"].contains(s) { return "a" }
            if ["b"].contains(s) { return "b" }
            if ["c", "x"].contains(s) { return "c" }
            if ["pause", "start"].contains(s) { return "pause" }
            if ["option", "select"].contains(s) { return "option" }
            if ["button1", "1"].contains(s) { return "button1" }
            if ["button2", "2"].contains(s) { return "button2" }
            if ["button3", "3"].contains(s) { return "button3" }
            if ["button4", "4"].contains(s) { return "button4" }
            if ["button5", "5"].contains(s) { return "button5" }
            if ["button6", "6"].contains(s) { return "button6" }
            if ["button7", "7"].contains(s) { return "button7" }
            if ["button8", "8"].contains(s) { return "button8" }
            if ["button9", "9"].contains(s) { return "button9" }
            if ["button0", "0"].contains(s) { return "button0" }
            if ["asterisk", "*"].contains(s) { return "asterisk" }
            if ["pound", "#"].contains(s) { return "pound" }
            return s
        case .NeoGeo:
            /// NeoGeo button normalization - uses PS-style buttons (triangle, circle, cross, square) and L/R
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["triangle", "a", "▵"].contains(s) { return "triangle" }
            if ["circle", "b", "○"].contains(s) { return "circle" }
            if ["cross", "x", "✕"].contains(s) { return "cross" }
            if ["square", "y", "□"].contains(s) { return "square" }
            if ["l1", "l"].contains(s) { return "l1" }
            if ["l2", "lt"].contains(s) { return "l2" }
            if ["l3"].contains(s) { return "l3" }
            if ["r1", "r"].contains(s) { return "r1" }
            if ["r2", "rt"].contains(s) { return "r2" }
            if ["r3"].contains(s) { return "r3" }
            if ["start", "mode"].contains(s) { return "start" }
            if ["select", "back"].contains(s) { return "select" }
            return s
        case .MAME:
            /// MAME button normalization - uses PS-style buttons and L/R
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["triangle", "a", "▵"].contains(s) { return "triangle" }
            if ["circle", "b", "○"].contains(s) { return "circle" }
            if ["cross", "x", "✕"].contains(s) { return "cross" }
            if ["square", "y", "□"].contains(s) { return "square" }
            if ["l1", "l"].contains(s) { return "l1" }
            if ["l2", "lt"].contains(s) { return "l2" }
            if ["l3"].contains(s) { return "l3" }
            if ["r1", "r"].contains(s) { return "r1" }
            if ["r2", "rt"].contains(s) { return "r2" }
            if ["r3"].contains(s) { return "r3" }
            if ["start", "mode"].contains(s) { return "start" }
            if ["select", "back", "cbdc"].contains(s) { return "select" }
            return s
        case .DS:
            /// DS button normalization - supports: up, down, left, right, a, b, x, y, l, r, start, select
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b", "x", "y"].contains(s) { return s }
            if ["l", "l1"].contains(s) { return "l" }
            if ["r", "r1"].contains(s) { return "r" }
            if ["start", "select"].contains(s) { return s }
            if ["screenswap", "ss", "swap"].contains(s) { return "screenswap" }
            if ["rotate"].contains(s) { return "rotate" }
            return s
        case .WonderSwan, .WonderSwanColor:
            /// WonderSwan button normalization - supports: x1-x4, y1-y4, a, b, start, sound
            if ["x1", "x"].contains(s) { return "x1" }
            if ["x3"].contains(s) { return "x3" }
            if ["x4"].contains(s) { return "x4" }
            if ["x2"].contains(s) { return "x2" }
            if ["y1", "y"].contains(s) { return "y1" }
            if ["y3"].contains(s) { return "y3" }
            if ["y4"].contains(s) { return "y4" }
            if ["y2"].contains(s) { return "y2" }
            if ["a", "b"].contains(s) { return s }
            if ["start"].contains(s) { return s }
            if ["sound", "select"].contains(s) { return "sound" }
            return s
        case .PCFX:
            /// PCFX button normalization - same as PCE/PCECD
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["button1", "1", "i", "a"].contains(s) { return "button1" }
            if ["button2", "2", "ii", "b"].contains(s) { return "button2" }
            if ["button3", "3", "iii", "x"].contains(s) { return "button3" }
            if ["button4", "4", "iv", "y"].contains(s) { return "button4" }
            if ["button5", "5", "v"].contains(s) { return "button5" }
            if ["button6", "6", "vi"].contains(s) { return "button6" }
            if ["run"].contains(s) { return "run" }
            if ["select"].contains(s) { return "select" }
            if ["mode"].contains(s) { return "mode" }
            return s
        case .SG1000:
            /// SG1000 button normalization - supports: up, down, left, right, b, c, start
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["b"].contains(s) { return "b" }
            if ["c"].contains(s) { return "c" }
            if ["start"].contains(s) { return s }
            return s
        case .Lynx:
            /// Lynx button normalization - supports: up, down, left, right, a, b, option1, option2, pause
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "b"].contains(s) { return s }
            if ["option1", "o1", "x"].contains(s) { return "option1" }
            if ["option2", "o2", "y"].contains(s) { return "option2" }
            if ["pause", "start"].contains(s) { return "pause" }
            return s
        case .ColecoVision:
            /// ColecoVision button normalization - supports: up, down, left, right, leftAction, rightAction, button1-9, 0, *, #
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["leftaction"].contains(s) { return "leftAction" }
            if ["rightaction"].contains(s) { return "rightAction" }
            if ["button1", "1", "a"].contains(s) { return "button1" }
            if ["button2", "2", "b"].contains(s) { return "button2" }
            if ["button3", "3", "x"].contains(s) { return "button3" }
            if ["button4", "4", "y"].contains(s) { return "button4" }
            if ["button5", "5"].contains(s) { return "button5" }
            if ["button6", "6"].contains(s) { return "button6" }
            if ["button7", "7"].contains(s) { return "button7" }
            if ["button8", "8"].contains(s) { return "button8" }
            if ["button9", "9"].contains(s) { return "button9" }
            if ["button0", "0"].contains(s) { return "button0" }
            if ["asterisk", "*"].contains(s) { return "asterisk" }
            if ["pound", "#"].contains(s) { return "pound" }
            return s
        case .Intellivision:
            /// Intellivision button normalization - supports: up, down, left, right, topAction, bottomLeftAction, bottomRightAction, button1-9, 0, clear, enter
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["topaction"].contains(s) { return "topAction" }
            if ["bottomleftaction"].contains(s) { return "bottomLeftAction" }
            if ["bottomrightaction"].contains(s) { return "bottomRightAction" }
            if ["button1", "1", "a"].contains(s) { return "button1" }
            if ["button2", "2", "b"].contains(s) { return "button2" }
            if ["button3", "3", "x"].contains(s) { return "button3" }
            if ["button4", "4", "y"].contains(s) { return "button4" }
            if ["button5", "5", "l", "l1"].contains(s) { return "button5" }
            if ["button6", "6", "r", "r1"].contains(s) { return "button6" }
            if ["button7", "7", "l2"].contains(s) { return "button7" }
            if ["button8", "8", "r2"].contains(s) { return "button8" }
            if ["button9", "9", "l3"].contains(s) { return "button9" }
            if ["button0", "0", "r3"].contains(s) { return "button0" }
            if ["clear", "select"].contains(s) { return "clear" }
            if ["enter", "start"].contains(s) { return "enter" }
            return s
        case .Supervision:
            /// Supervision button normalization - similar to Intellivision
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["topaction", "a"].contains(s) { return "topAction" }
            if ["bottomleftaction", "b"].contains(s) { return "bottomLeftAction" }
            if ["bottomrightaction", "c"].contains(s) { return "bottomRightAction" }
            if ["button1", "1"].contains(s) { return "button1" }
            if ["button2", "2"].contains(s) { return "button2" }
            if ["button3", "3"].contains(s) { return "button3" }
            if ["button4", "4"].contains(s) { return "button4" }
            if ["button5", "5"].contains(s) { return "button5" }
            if ["button6", "6"].contains(s) { return "button6" }
            if ["button7", "7"].contains(s) { return "button7" }
            if ["button8", "8"].contains(s) { return "button8" }
            if ["button9", "9"].contains(s) { return "button9" }
            if ["button0", "0"].contains(s) { return "button0" }
            if ["clear", "select"].contains(s) { return "clear" }
            if ["enter", "start"].contains(s) { return "enter" }
            return s
        case .Odyssey2:
            /// Odyssey2 button normalization - supports: up, down, left, right, action, key0-9
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["action", "a", "i", "b", "x", "y"].contains(s) { return "action" }
            if ["key0", "0"].contains(s) { return "key0" }
            if ["key1", "1"].contains(s) { return "key1" }
            if ["key2", "2"].contains(s) { return "key2" }
            if ["key3", "3"].contains(s) { return "key3" }
            if ["key4", "4"].contains(s) { return "key4" }
            if ["key5", "5"].contains(s) { return "key5" }
            if ["key6", "6"].contains(s) { return "key6" }
            if ["key7", "7"].contains(s) { return "key7" }
            if ["key8", "8"].contains(s) { return "key8" }
            if ["key9", "9"].contains(s) { return "key9" }
            return s
        case .PokemonMini:
            /// Pokemon Mini button normalization - supports: menu, a, b, c, up, down, left, right, power, shake
            if ["menu", "select"].contains(s) { return "menu" }
            if ["a", "b", "c"].contains(s) { return s }
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["power", "start"].contains(s) { return "power" }
            if ["shake", "l", "l1"].contains(s) { return "shake" }
            return s
        case .NGP, .NGPC:
            /// NeoGeo Pocket button normalization - supports: up, down, left, right, a, b, option
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["a", "i", "1"].contains(s) { return "a" }
            if ["b", "ii", "2"].contains(s) { return "b" }
            if ["option", "select"].contains(s) { return "option" }
            return s
        case .Atari5200:
            /// Atari 5200 button normalization - supports: up, down, left, right, fire1, fire2, start, pause, reset, number1-9, 0, *, #
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["fire1", "a"].contains(s) { return "fire1" }
            if ["fire2", "b"].contains(s) { return "fire2" }
            if ["start", "s"].contains(s) { return "start" }
            if ["pause", "p", "select"].contains(s) { return "pause" }
            if ["reset", "r"].contains(s) { return "reset" }
            if ["number1", "1"].contains(s) { return "number1" }
            if ["number2", "2"].contains(s) { return "number2" }
            if ["number3", "3"].contains(s) { return "number3" }
            if ["number4", "4"].contains(s) { return "number4" }
            if ["number5", "5"].contains(s) { return "number5" }
            if ["number6", "6"].contains(s) { return "number6" }
            if ["number7", "7"].contains(s) { return "number7" }
            if ["number8", "8"].contains(s) { return "number8" }
            if ["number9", "9"].contains(s) { return "number9" }
            if ["number0", "0"].contains(s) { return "number0" }
            if ["asterisk", "*"].contains(s) { return "asterisk" }
            if ["pound", "#"].contains(s) { return "pound" }
            return s
        case .Atari7800:
            /// Atari 7800 button normalization - supports: up, down, left, right, fire1, fire2, select, pause, reset, leftDiff, rightDiff
            if ["up", "down", "left", "right"].contains(s) { return s }
            if ["fire1", "a"].contains(s) { return "fire1" }
            if ["fire2", "b"].contains(s) { return "fire2" }
            if ["select", "s"].contains(s) { return "select" }
            if ["pause", "p", "start"].contains(s) { return "pause" }
            if ["reset", "r"].contains(s) { return "reset" }
            if ["leftdiff", "l", "l1"].contains(s) { return "leftDiff" }
            if ["rightdiff", "r", "r1"].contains(s) { return "rightDiff" }
            return s
        default:
            break
        }

        // Common
        if ![SystemIdentifier.DOS, .DOOM, .Quake, .Quake2, .Wolf3D].contains(system) &&
            ["run", "play"].contains(s) {
            return "start"
        }
        // 32X uses "mode" directly, so don't convert it to "select" for 32X
        if system != .Sega32X && ["mode", "option"].contains(s) { return "select" }
        /// Systems that use "l" and "r" directly (not "l1"/"r1"): VirtualBoy, 3DO, N64, Saturn, Dreamcast, GBA, DS, SNES
        /// Don't convert them to "l1"/"r1" in common handling
        if system != .VirtualBoy && system != ._3DO && system != .N64 && system != .Saturn &&
           system != .Dreamcast && system != .GBA && system != .DS && system != .SNES {
            if ["l", "lb", "lshoulder", "shoulderleft"].contains(s) { return "l1" }
            if ["r", "rb", "rshoulder", "shoulderright"].contains(s) { return "r1" }
        }
        if ["lt", "ltrigger", "ltrigger1", "triggerleft"].contains(s) { return "l1" }
        if ["rt", "rtrigger", "rtrigger1", "triggerright"].contains(s) { return "r1" }
        if ["lt2", "l2", "ltrigger2", "trigger2", "lefttrigger2"].contains(s) { return "l2" }
        if ["rt2", "r2", "rtrigger2", "trigger2", "righttrigger2"].contains(s) { return "r2" }
        if ["l3", "stickpressleft", "lstick"].contains(s) { return "l3" }
        if ["r3", "stickpressright", "rstick"].contains(s) { return "r3" }

        return s
    }

    /// Fallback to generic mapping when system-specific mapping is not available
    private func fallbackToGenericMapping(_ buttonId: String, isPressed: Bool, core: PVEmulatorCore) {
        // Map to button index and send to core
        let buttonIndex = mapButtonToIndex(buttonId)

        if isPressed {
            DLOG("Pressing button (generic mapping): \(buttonId) (index: \(buttonIndex))")
            if let responder = core as? PVControllerResponder {
                responder.controllerPressedButton(buttonIndex, forPlayer: 0)
            }
        } else {
            DLOG("Releasing button (generic mapping): \(buttonId) (index: \(buttonIndex))")
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
    @MainActor
    @objc private func handleReconnectEvent() {
        DLOG("DeltaSkinInputHandler handling reconnect event")
        performReconnection()
    }

    /// Handle skin change event
    @MainActor
    @objc private func handleSkinChangeEvent() {
        DLOG("DeltaSkinInputHandler handling skin change event")
        performReconnection()
    }

    /// Common logic to reconnect and reset state
    @MainActor
    private func performReconnection() {
        // Refresh emulator core reference on the main thread

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
//        if core.isEmulationPaused {
//            DLOG("Unpausing core during reconnect")
//            core.setPauseEmulation(false)
//        }

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
//                metalVC.safelyRefreshGPUView()
        }

        // Test button forwarding after reconnection
        self.testButtonForwarding()

        ILOG("✅ Reconnection complete")
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
