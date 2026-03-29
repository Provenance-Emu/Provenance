import GameController
import Foundation
import PVLogging
import PVSettings

/// Identifies which button on a controller
public enum ButtonIdentifier: String, Codable, CaseIterable {
    // Standard buttons
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case menu
    case options
    case home

    // Extended inputs
    case leftThumbstickButton
    case rightThumbstickButton
    case share

    // DualSense specific
    case touchpad
    case touchpadButton
    case micButton
    case createButton

    // Xbox specific
    case paddleOne
    case paddleTwo
    case paddleThree
    case paddleFour
    case shareButton

    // Switch Pro specific
    case capture
    case plusButton
    case minusButton
    case leftSL
    case leftSR
    case rightSL
    case rightSR
}

/// Represents special controller features
public enum ControllerFeature {
    case touchpad(x: Float, y: Float)
    case gyro(x: Float, y: Float, z: Float)
    case accelerometer(x: Float, y: Float, z: Float)
    case lightBar(red: Float, green: Float, blue: Float)
    case rumble(lowFrequency: Float, highFrequency: Float)
    case adaptiveTrigger(mode: AdaptiveTriggerMode, startPosition: Float, endPosition: Float, force: Float)
}

/// DualSense adaptive trigger modes
@available(iOS 14.5, tvOS 14.5, *)
public enum AdaptiveTriggerMode {
    case off
    case rigid
    case vibration
    case feedback
    case weapon
}

/// Represents a button mapping configuration
public struct ButtonMapping: Codable, Equatable {
    /// The original button input
    public let sourceId: ButtonIdentifier
    /// The button to map to
    public let destinationId: ButtonIdentifier

    public init(source: ButtonIdentifier, destination: ButtonIdentifier) {
        self.sourceId = source
        self.destinationId = destination
    }
}

/// A wrapper around GCController that supports button remapping and special features
public final class PVRemappableController: NSObject {
    /// The underlying controller being wrapped
    private let wrappedController: GCController

    /// Underlying `GCController` for hardware features (light bar, etc.) used by PVUIBase extensions.
    internal var backingGCController: GCController { wrappedController }

    /// Dictionary of button remappings
    private var buttonMappings: [ButtonIdentifier: ButtonMapping] = [:]

    /// Feature handlers
    private var touchpadHandler: ((Float, Float) -> Void)?
    private var gyroHandler: ((Float, Float, Float) -> Void)?
    private var accelerometerHandler: ((Float, Float, Float) -> Void)?

    /// Initialize with a GCController to wrap
    public init(wrapping controller: GCController) {
        self.wrappedController = controller
        super.init()

        // Load saved mappings first (if any exist)
        loadMappings()

        // Set up default mappings (e.g., Joy-Con auto-fix) only if no mappings exist.
        // This ensures user's manual remappings take precedence over auto-fix.
        if buttonMappings.isEmpty {
            setupDefaultMappings()
        }

        // Set up input handlers
        setupInputHandlers()

        // Set up special features
        setupSpecialFeatures()
    }

    /// Set up special controller features
    private func setupSpecialFeatures() {
        if #available(iOS 14.0, tvOS 14.0, *) {
            // DualSense features
            if let dualSense = wrappedController.physicalInputProfile as? GCDualSenseGamepad {
                setupDualSenseFeatures(dualSense)
            }
            // DualShock 4 features
            else if let dualShock = wrappedController.physicalInputProfile as? GCDualShockGamepad {
                setupDualShockFeatures(dualShock)
            }

            // Xbox features
            if let xbox = wrappedController.physicalInputProfile as? GCXboxGamepad {
                setupXboxFeatures(xbox)
            }

            // Switch features (only for controllers that are not DualSense/DS4/Xbox)
            if wrappedController.physicalInputProfile as? GCDualSenseGamepad == nil,
               wrappedController.physicalInputProfile as? GCDualShockGamepad == nil,
               wrappedController.physicalInputProfile as? GCXboxGamepad == nil,
               let switchPro = wrappedController.physicalInputProfile as? GCExtendedGamepad {
                setupSwitchFeatures(switchPro)
            }
        }
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private func setupDualSenseFeatures(_ dualSense: GCDualSenseGamepad) {
        // Touchpad
        if #available(iOS 14.5, tvOS 14.5, *) {
            dualSense.touchpadButton.valueChangedHandler = { [weak self] (button: GCControllerButtonInput, value: Float, pressed: Bool) in
                if pressed {
                    self?.handleSpecialButton(.touchpadButton)
                }
            }

            dualSense.touchpadPrimary.valueChangedHandler = { [weak self] (pad: GCControllerDirectionPad, x: Float, y: Float) in
                self?.touchpadHandler?(x, y)
            }

            // Microphone button — posts a notification so the emulator VC can toggle audio mute.
            // Apple does not expose a typed property for the DualSense mute button;
            // access it by name from the physical input profile.
            if let micButton = dualSense.buttons["Button Mute"] {
                micButton.pressedChangedHandler = { [weak self] (_: GCControllerButtonInput, _: Float, pressed: Bool) in
                    guard pressed else { return }
                    self?.handleMicButtonPressed()
                }
            }

            // Note: DualSense buttonOptions (Create button) is handled by the remapping pipeline
            // in setupButtonRemappingHandlers (keyed as .createButton). Do NOT install a
            // valueChangedHandler here — it would overwrite the pipeline's handler.
        }
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private func setupDualShockFeatures(_ dualShock: GCDualShockGamepad) {
        // Touchpad click — expose as remappable button.
        dualShock.touchpadButton.valueChangedHandler = { [weak self] (_, _, pressed) in
            if pressed {
                self?.handleSpecialButton(.touchpadButton)
            }
        }

        dualShock.touchpadPrimary.valueChangedHandler = { [weak self] (_, x, y) in
            self?.touchpadHandler?(x, y)
        }

        // Note: DS4 buttonOptions (Share button) is handled by the remapping pipeline in
        // setupButtonRemappingHandlers (keyed as .share). Do NOT install a valueChangedHandler
        // here — it would overwrite the pipeline's handler.
    }

    private func handleMicButtonPressed() {
        let action = Defaults[.dualSenseMicButtonAction]
        switch action {
        case "muteAudio":
            NotificationCenter.default.post(name: .PVControllerMicButtonToggleMute, object: wrappedController)
        default:
            break
        }
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private func setupXboxFeatures(_ xbox: GCXboxGamepad) {
        // Xbox buttonOptions (Share on Elite/Series X) is handled by the remapping pipeline
        // in setupButtonRemappingHandlers (keyed as .shareButton).
        // Note: Xbox Elite paddle buttons (P1–P4) are not individually accessible via
        // GCXboxGamepad in the current GCController API. They surface through the
        // standard button inputs, so no additional setup is needed here.
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private func setupSwitchFeatures(_ switchPro: GCExtendedGamepad) {
        // Switch Pro buttonOptions (Capture) is handled by the remapping pipeline in
        // setupButtonRemappingHandlers (keyed as .options for generic GCExtendedGamepad).
    }

    /// Handle special button press
    private func handleSpecialButton(_ button: ButtonIdentifier) {
        if let mapping = buttonMappings[button] {
            // Forward to the mapped destination button via valueChangedHandler only.
            // valueChangedHandler is the primary path used by PVControllerManager and
            // the remapping pipeline. Calling pressedChangedHandler separately would
            // double-fire actions when both handlers are set on the destination button.
            // Synthesize an immediate release (0.0/false) so the destination is not
            // left stuck in the pressed state.
            if let gamepad = wrappedController.extendedGamepad,
               let destButton = self.button(for: mapping.destinationId, on: gamepad) {
                destButton.valueChangedHandler?(destButton, 1.0, true)
                destButton.valueChangedHandler?(destButton, 0.0, false)
            }
        }
    }

    /// Set handler for touchpad input
    public func setTouchpadHandler(_ handler: @escaping (Float, Float) -> Void) {
        touchpadHandler = handler
    }

    /// Set handler for gyro input
    public func setGyroHandler(_ handler: @escaping (Float, Float, Float) -> Void) {
        gyroHandler = handler
    }

    /// Set handler for accelerometer input
    public func setAccelerometerHandler(_ handler: @escaping (Float, Float, Float) -> Void) {
        accelerometerHandler = handler
    }

    /// Configure special controller features
    @available(iOS 14.5, tvOS 14.5, *)
    public func setFeature(_ feature: ControllerFeature) {
        if let dualSense = wrappedController.physicalInputProfile as? GCDualSenseGamepad {
            switch feature {
            case .lightBar(let r, let g, let b):
                dualSense.controller?.light?.color = GCColor(red: r, green: g, blue: b)
            case .adaptiveTrigger(let mode, let start, let end, let force):
                let triggerMode: GCDualSenseAdaptiveTrigger.Mode = switch mode {
                case .off: .off
                case .rigid: .slopeFeedback
                case .vibration: .vibration
                case .feedback: .feedback
                case .weapon: .weapon
                }

                // Apply mode based on type
                switch triggerMode {
                case .off:
                    dualSense.leftTrigger.setModeOff()
                    dualSense.rightTrigger.setModeOff()
                case .feedback:
                    dualSense.leftTrigger.setModeFeedbackWithStartPosition(start, resistiveStrength: force)
                    dualSense.rightTrigger.setModeFeedbackWithStartPosition(start, resistiveStrength: force)
                case .weapon:
                    dualSense.leftTrigger.setModeWeaponWithStartPosition(start, endPosition: end, resistiveStrength: force)
                    dualSense.rightTrigger.setModeWeaponWithStartPosition(start, endPosition: end, resistiveStrength: force)
                case .vibration:
                    dualSense.leftTrigger.setModeVibrationWithStartPosition(start, amplitude: force, frequency: 0.5)
                    dualSense.rightTrigger.setModeVibrationWithStartPosition(start, amplitude: force, frequency: 0.5)
                case .slopeFeedback:
                    if #available(iOS 15.4, tvOS 15.4, *) {
                        dualSense.leftTrigger.setModeSlopeFeedback(startPosition: start, endPosition: end, startStrength: force, endStrength: force)
                        dualSense.rightTrigger.setModeSlopeFeedback(startPosition: start, endPosition: end, startStrength: force, endStrength: force)
                    }
                @unknown default:
                    break
                }
            default: break
            }
        }
    }

    /// Set up any default button mappings
    private func setupDefaultMappings() {
        // Detect Joy-Con controllers and fix button swaps
        if isJoyConController() {
            // Joy-Con controllers have swapped A/B and X/Y buttons
            // Fix: Swap A<->B and X<->Y
            swapButtons(.buttonA, .buttonB)
            swapButtons(.buttonX, .buttonY)
            // Save mappings so they persist across reconnections
            saveMappings()
            ILOG("Joy-Con controller detected - auto-corrected A/B and X/Y button mappings")
        }
    }

    /// Check if this is a Joy-Con controller
    private func isJoyConController() -> Bool {
        guard let vendorName = wrappedController.vendorName else { return false }

        // Joy-Con controllers appear with different identifiers:
        // - "Joy-Con (L)" or "Joy-Con (R)" when connected separately
        // - "Nintendo" when connected as a pair
        // - Product category might be "Nintendo Switch"
        let vendorLower = vendorName.lowercased()
        let productCategory = wrappedController.productCategory.lowercased()

        // Check for explicit Joy-Con identifiers
        if vendorLower.contains("joy-con") || vendorLower.contains("joycon") {
            return true
        }

        // Check for Nintendo Switch controllers (includes Joy-Cons and Pro Controller)
        // Joy-Cons often appear as separate Left/Right controllers
        if vendorLower.contains("nintendo") {
            // If it's a Switch controller and not explicitly a Pro Controller, assume Joy-Con
            if productCategory.contains("switch") && !vendorLower.contains("pro") {
                return true
            }
            // Left/Right in name usually indicates Joy-Con
            if vendorLower.contains("left") || vendorLower.contains("right") {
                return true
            }
        }

        return false
    }

    /// Get button from identifier
    private func button(for id: ButtonIdentifier, on gamepad: GCExtendedGamepad) -> GCControllerButtonInput? {
        switch id {
        case .buttonA: return gamepad.buttonA
        case .buttonB: return gamepad.buttonB
        case .buttonX: return gamepad.buttonX
        case .buttonY: return gamepad.buttonY
        case .leftShoulder: return gamepad.leftShoulder
        case .rightShoulder: return gamepad.rightShoulder
        case .leftTrigger: return gamepad.leftTrigger
        case .rightTrigger: return gamepad.rightTrigger
        case .dpadUp: return gamepad.dpad.up
        case .dpadDown: return gamepad.dpad.down
        case .dpadLeft: return gamepad.dpad.left
        case .dpadRight: return gamepad.dpad.right
        case .menu: return gamepad.buttonMenu
        case .options:
            if #available(iOS 14.0, tvOS 14.0, *) {
                return gamepad.buttonOptions
            }
            return gamepad.buttonMenu
        case .home:
            if #available(iOS 14.0, tvOS 14.0, *) {
                return gamepad.buttonHome
            }
            return gamepad.buttonMenu
        case .leftThumbstickButton: return gamepad.leftThumbstickButton
        case .rightThumbstickButton: return gamepad.rightThumbstickButton
        case .share:
            if #available(iOS 14.5, tvOS 14.5, *),
               let dualSense = gamepad as? GCDualSenseGamepad {
                return dualSense.buttonOptions
            }
            return nil
        case .touchpad, .touchpadButton, .micButton, .createButton:
            if #available(iOS 14.5, tvOS 14.5, *),
               let dualSense = gamepad as? GCDualSenseGamepad {
                switch id {
                case .touchpad: return nil // Touchpad surface is not a GCControllerButtonInput
                case .touchpadButton: return dualSense.touchpadButton
                case .micButton: return dualSense.buttons["Button Mute"]
                case .createButton: return dualSense.buttonOptions
                default: return nil
                }
            }
            return nil
        case .paddleOne, .paddleTwo, .paddleThree, .paddleFour:
            // Xbox Elite paddle buttons are not individually accessible as
            // GCControllerButtonInput via the GCController API.
            return nil
        case .shareButton:
            if #available(iOS 14.5, tvOS 14.5, *),
               let xbox = gamepad as? GCXboxGamepad {
                return xbox.buttonOptions
            }
            return nil
        case .capture, .plusButton, .minusButton, .leftSL, .leftSR, .rightSL, .rightSR:
            // Switch Pro specific buttons not directly accessible
            return nil
        }
    }

    /// Stored original handler to chain after remapping
    private var originalValueChangedHandler: GCExtendedGamepadValueChangedHandler?

    /// Track which buttons are currently being remapped to prevent infinite loops
    private var remappingInProgress: Set<ButtonIdentifier> = []

    /// Store original handlers for each button to prevent loops
    private var originalButtonHandlers: [ButtonIdentifier: GCControllerButtonValueChangedHandler] = [:]

    /// Set up input handlers for button remapping
    private func setupInputHandlers() {
        guard let gamepad = wrappedController.extendedGamepad else { return }

        // Store original handler if one exists (set by cores or other parts)
        originalValueChangedHandler = gamepad.valueChangedHandler

        // Set up individual button handlers for remapping
        setupButtonRemappingHandlers(on: gamepad)

        // Chain the original handler after remapping
        gamepad.valueChangedHandler = { [weak self] (gamepad, element) in
            guard let self = self else { return }

            // Chain original handler so we don't break existing functionality
            self.originalValueChangedHandler?(gamepad, element)
        }
    }

    /// Set up individual button handlers to apply remapping
    private func setupButtonRemappingHandlers(on gamepad: GCExtendedGamepad) {
        // Set up handlers for all mappable buttons
        let buttons: [(GCControllerButtonInput, ButtonIdentifier)] = [
            (gamepad.buttonA, .buttonA),
            (gamepad.buttonB, .buttonB),
            (gamepad.buttonX, .buttonX),
            (gamepad.buttonY, .buttonY),
            (gamepad.leftShoulder, .leftShoulder),
            (gamepad.rightShoulder, .rightShoulder),
            (gamepad.leftTrigger, .leftTrigger),
            (gamepad.rightTrigger, .rightTrigger),
            (gamepad.dpad.up, .dpadUp),
            (gamepad.dpad.down, .dpadDown),
            (gamepad.dpad.left, .dpadLeft),
            (gamepad.dpad.right, .dpadRight),
            (gamepad.buttonMenu, .menu)
        ]

        for (button, buttonId) in buttons {
            // Store original handler BEFORE we modify it
            originalButtonHandlers[buttonId] = button.valueChangedHandler

            // Set new handler that applies remapping
            button.valueChangedHandler = { [weak self] (button, value, pressed) in
                guard let self = self else { return }

                // Prevent infinite loops from swapped buttons
                guard !self.remappingInProgress.contains(buttonId) else {
                    // Already remapping this button, just call original handler
                    self.originalButtonHandlers[buttonId]?(button, value, pressed)
                    return
                }

                // Check if this button has a remapping
                if let mapping = self.buttonMappings[buttonId],
                   let destButton = self.button(for: mapping.destinationId, on: gamepad) {
                    // Mark as in progress to prevent loops
                    self.remappingInProgress.insert(buttonId)

                    // Get the ORIGINAL handler of destination button (before our remapping)
                    // This prevents infinite loops when buttons are swapped
                    if let destId = self.identifier(for: destButton),
                       let destOriginalHandler = self.originalButtonHandlers[destId] {
                        // Call destination's original handler with destination button
                        destOriginalHandler(destButton, value, pressed)
                    } else {
                        // Fallback: call destination's current handler
                        destButton.valueChangedHandler?(destButton, value, pressed)
                    }

                    // Remove from in-progress set
                    self.remappingInProgress.remove(buttonId)

                    // Also call original handler for this button to maintain compatibility
                    self.originalButtonHandlers[buttonId]?(button, value, pressed)
                } else {
                    // No remapping, call original handler
                    self.originalButtonHandlers[buttonId]?(button, value, pressed)
                }
            }
        }

        // Handle the platform-specific options/share/create button.
        // Use the correct ButtonIdentifier for the controller type so user mappings for
        // .createButton (DualSense), .share (DS4), .shareButton (Xbox), or .options
        // (generic) are all routed through the same remapping pipeline — and so this
        // single handler installation is never clobbered by setupSpecialFeatures().
        if #available(iOS 14.0, tvOS 14.0, *), let optionsButton = gamepad.buttonOptions {
            let platformId: ButtonIdentifier
            if #available(iOS 14.5, tvOS 14.5, *), gamepad is GCDualSenseGamepad {
                platformId = .createButton
            } else if gamepad is GCDualShockGamepad {
                platformId = .share
            } else if gamepad is GCXboxGamepad {
                platformId = .shareButton
            } else {
                platformId = .options
            }

            originalButtonHandlers[platformId] = optionsButton.valueChangedHandler
            optionsButton.valueChangedHandler = { [weak self] (button, value, pressed) in
                guard let self = self else { return }
                guard !self.remappingInProgress.contains(platformId) else {
                    self.originalButtonHandlers[platformId]?(button, value, pressed)
                    return
                }
                if let mapping = self.buttonMappings[platformId],
                   let destButton = self.button(for: mapping.destinationId, on: gamepad) {
                    self.remappingInProgress.insert(platformId)
                    if let destId = self.identifier(for: destButton),
                       let destOriginalHandler = self.originalButtonHandlers[destId] {
                        destOriginalHandler(destButton, value, pressed)
                    } else {
                        destButton.valueChangedHandler?(destButton, value, pressed)
                    }
                    self.remappingInProgress.remove(platformId)
                    self.originalButtonHandlers[platformId]?(button, value, pressed)
                } else {
                    self.originalButtonHandlers[platformId]?(button, value, pressed)
                }
            }
        }
    }

    /// Get identifier for a button input
    /// Public wrapper — used by TapToRemapView to identify which physical button was pressed.
    public func buttonIdentifier(for element: GCControllerElement) -> ButtonIdentifier? {
        identifier(for: element)
    }

    private func identifier(for element: GCControllerElement) -> ButtonIdentifier? {
        guard let gamepad = wrappedController.extendedGamepad else { return nil }

        switch element {
        case gamepad.buttonA: return .buttonA
        case gamepad.buttonB: return .buttonB
        case gamepad.buttonX: return .buttonX
        case gamepad.buttonY: return .buttonY
        case gamepad.leftShoulder: return .leftShoulder
        case gamepad.rightShoulder: return .rightShoulder
        case gamepad.leftTrigger: return .leftTrigger
        case gamepad.rightTrigger: return .rightTrigger
        case gamepad.dpad.up: return .dpadUp
        case gamepad.dpad.down: return .dpadDown
        case gamepad.dpad.left: return .dpadLeft
        case gamepad.dpad.right: return .dpadRight
        case gamepad.buttonMenu: return .menu
        case gamepad.leftThumbstickButton: return .leftThumbstickButton
        case gamepad.rightThumbstickButton: return .rightThumbstickButton
        default:
            if #available(iOS 14.5, tvOS 14.5, *) {
                // Platform-specific mappings take precedence over the generic options button.
                // DualSense: buttonOptions is the "Create" button.
                if let dualSense = gamepad as? GCDualSenseGamepad {
                    switch element {
                    case dualSense.buttonOptions: return .createButton
                    case dualSense.touchpadButton: return .touchpadButton
                    default: break
                    }
                }
                // Xbox: buttonOptions is the "Share" button on Elite/Series X.
                if let xbox = gamepad as? GCXboxGamepad {
                    switch element {
                    case xbox.buttonOptions: return .shareButton
                    default: break
                    }
                }
            }
            // DualShock 4 (iOS 14.0+): buttonOptions is the "Share" button; touchpadButton is remappable.
            if #available(iOS 14.0, tvOS 14.0, *),
               let dualShock = gamepad as? GCDualShockGamepad {
                switch element {
                case dualShock.buttonOptions: return .share
                case dualShock.touchpadButton: return .touchpadButton
                default: break
                }
            }
            // Generic GCExtendedGamepad options button (e.g. PS4 Options, Switch Pro Capture).
            if #available(iOS 14.0, tvOS 14.0, *),
               let optionsButton = gamepad.buttonOptions, optionsButton === element {
                return .options
            }
            return nil
        }
    }

    /// Remap a button to another button
    public func remap(button source: ButtonIdentifier, to destination: ButtonIdentifier) {
        let mapping = ButtonMapping(source: source, destination: destination)
        buttonMappings[source] = mapping
    }

    /// Remove remapping for a button
    public func clearMapping(for button: ButtonIdentifier) {
        buttonMappings.removeValue(forKey: button)
    }

    /// Clear all button remappings
    public func clearAllMappings() {
        buttonMappings.removeAll()
    }
}

// MARK: - GCController Interface Forwarding
extension PVRemappableController {
    /// Forward properties and methods from GCController
    public var playerIndex: GCControllerPlayerIndex {
        get { wrappedController.playerIndex }
        set { wrappedController.playerIndex = newValue }
    }

    public var extendedGamepad: GCExtendedGamepad? {
        wrappedController.extendedGamepad
    }

    public var microGamepad: GCMicroGamepad? {
        wrappedController.microGamepad
    }

    public var vendorName: String? {
        wrappedController.vendorName
    }
}

// MARK: - Persistence
extension PVRemappableController {
    /// Save current mappings to UserDefaults
    public func saveMappings() {
        do {
            let mappingsData = try JSONEncoder().encode(buttonMappings)
            UserDefaults.standard.set(mappingsData, forKey: "PVControllerMappings_\(wrappedController.vendorName ?? "unknown")")
        } catch {
            ELOG("Failed to encode controller mappings for '\(wrappedController.vendorName ?? "unknown")': \(error)")
        }
    }

    /// Load saved mappings from UserDefaults
    public func loadMappings() {
        guard let mappingsData = UserDefaults.standard.data(forKey: "PVControllerMappings_\(wrappedController.vendorName ?? "unknown")"),
              let loadedMappings = try? JSONDecoder().decode([ButtonIdentifier: ButtonMapping].self, from: mappingsData) else {
            return
        }
        buttonMappings = loadedMappings
    }
}

// MARK: - Convenience Methods
extension PVRemappableController {
    /// Swap two buttons (bidirectional mapping)
    public func swapButtons(_ buttonA: ButtonIdentifier, _ buttonB: ButtonIdentifier) {
        remap(button: buttonA, to: buttonB)
        remap(button: buttonB, to: buttonA)
    }

    /// Check if a button has a custom mapping
    public func hasMapping(for button: ButtonIdentifier) -> Bool {
        buttonMappings[button] != nil
    }

    /// Get the destination button for a mapped button
    public func mappedButton(for button: ButtonIdentifier) -> ButtonIdentifier? {
        buttonMappings[button]?.destinationId
    }
}

// MARK: - ButtonIdentifier display name

extension ButtonIdentifier {
    /// Human-readable display name for use in UI labels.
    public var displayName: String {
        switch self {
        case .buttonA: return "A"
        case .buttonB: return "B"
        case .buttonX: return "X"
        case .buttonY: return "Y"
        case .leftShoulder: return "L1"
        case .rightShoulder: return "R1"
        case .leftTrigger: return "L2"
        case .rightTrigger: return "R2"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .menu: return "Menu"
        case .options: return "Options"
        case .home: return "Home"
        case .leftThumbstickButton: return "L3"
        case .rightThumbstickButton: return "R3"
        case .share: return "Share"
        case .touchpad: return "Touchpad"
        case .touchpadButton: return "Touchpad Button"
        case .micButton: return "Mic"
        case .createButton: return "Create"
        case .paddleOne: return "Paddle 1"
        case .paddleTwo: return "Paddle 2"
        case .paddleThree: return "Paddle 3"
        case .paddleFour: return "Paddle 4"
        case .shareButton: return "Share"
        case .capture: return "Capture"
        case .plusButton: return "+"
        case .minusButton: return "−"
        case .leftSL: return "Left SL"
        case .leftSR: return "Left SR"
        case .rightSL: return "Right SL"
        case .rightSR: return "Right SR"
        }
    }
}

// MARK: - Debug Helpers
extension PVRemappableController {
    /// Get a description of current mappings
    public var mappingsDescription: String {
        var description = "Button Mappings for \(wrappedController.vendorName ?? "Unknown Controller"):\n"
        for (_, mapping) in buttonMappings {
            description += "- \(mapping.sourceId) -> \(mapping.destinationId)\n"
        }
        return description
    }
}
