import GameController
import Foundation

/// Identifies which button on a controller
public enum ButtonIdentifier: String, Codable {
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
    let sourceId: ButtonIdentifier
    /// The button to map to
    let destinationId: ButtonIdentifier

    init(source: ButtonIdentifier, destination: ButtonIdentifier) {
        self.sourceId = source
        self.destinationId = destination
    }
}

/// A wrapper around GCController that supports button remapping and special features
public final class PVRemappableController: NSObject {
    /// The underlying controller being wrapped
    private let wrappedController: GCController

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

        // Forward controller properties
        wrappedController.playerIndex = controller.playerIndex

        // Set up initial mappings
        setupDefaultMappings()

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

            // Xbox features
            if let xbox = wrappedController.physicalInputProfile as? GCXboxGamepad {
                setupXboxFeatures(xbox)
            }

            // Switch features
            if let switchPro = wrappedController.physicalInputProfile as? GCExtendedGamepad {
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
        }

        // Motion
//        if #available(iOS 14.5, tvOS 14.5, *) {
//            dualSense.controller?.physicalInputProfile.motionInput?.valueChangedHandler = { [weak self] (motion: GCMotion) in
//                self?.gyroHandler?(
//                    Float(motion.gravity.x),
//                    Float(motion.gravity.y),
//                    Float(motion.gravity.z)
//                )
//                self?.accelerometerHandler?(
//                    Float(motion.userAcceleration.x),
//                    Float(motion.userAcceleration.y),
//                    Float(motion.userAcceleration.z)
//                )
//            }
//        }
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private func setupXboxFeatures(_ xbox: GCXboxGamepad) {
        if #available(iOS 14.5, tvOS 14.5, *) {
            // Paddle buttons
            xbox.buttonA.pressedChangedHandler = { [weak self] (button: GCControllerButtonInput, value: Float, pressed: Bool) in
                if pressed { self?.handleSpecialButton(.paddleOne) }
            }
            xbox.buttonB.pressedChangedHandler = { [weak self] (button: GCControllerButtonInput, value: Float, pressed: Bool) in
                if pressed { self?.handleSpecialButton(.paddleTwo) }
            }
            xbox.buttonX.pressedChangedHandler = { [weak self] (button: GCControllerButtonInput, value: Float, pressed: Bool) in
                if pressed { self?.handleSpecialButton(.paddleThree) }
            }
            xbox.buttonY.pressedChangedHandler = { [weak self] (button: GCControllerButtonInput, value: Float, pressed: Bool) in
                if pressed { self?.handleSpecialButton(.paddleFour) }
            }

            // Share button
            xbox.buttonOptions?.pressedChangedHandler = { [weak self] (button: GCControllerButtonInput, value: Float, pressed: Bool) in
                if pressed { self?.handleSpecialButton(.shareButton) }
            }
        }
    }

    @available(iOS 14.0, tvOS 14.0, *)
    private func setupSwitchFeatures(_ switchPro: GCExtendedGamepad) {
        if #available(iOS 14.5, tvOS 14.5, *) {
            // Special Switch Pro buttons if available
            if let button = switchPro.buttonOptions {
                button.pressedChangedHandler = { [weak self] button, value, pressed in
                    if pressed { self?.handleSpecialButton(.capture) }
                }
            }
        }
    }

    /// Handle special button press
    private func handleSpecialButton(_ button: ButtonIdentifier) {
        if let mapping = buttonMappings[button] {
            // Forward to mapped button
            if let gamepad = wrappedController.extendedGamepad,
               let destButton = self.button(for: mapping.destinationId, on: gamepad) {
                destButton.pressedChangedHandler?(destButton, 1.0, true)
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
        // Example: Map B button to A button
        if let gamepad = wrappedController.extendedGamepad {
            remap(button: .buttonB, to: .buttonA)
        }
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
                case .touchpad: return nil // Touchpad is not a button
                case .touchpadButton: return dualSense.touchpadButton
                case .micButton: return dualSense.buttonOptions
                case .createButton: return dualSense.buttonOptions
                default: return nil
                }
            }
            return nil
        case .paddleOne, .paddleTwo, .paddleThree, .paddleFour:
            if #available(iOS 14.5, tvOS 14.5, *),
               let xbox = gamepad as? GCXboxGamepad {
                switch id {
                case .paddleOne: return xbox.buttonA
                case .paddleTwo: return xbox.buttonB
                case .paddleThree: return xbox.buttonX
                case .paddleFour: return xbox.buttonY
                default: return nil
                }
            }
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

    /// Set up input handlers for button remapping
    private func setupInputHandlers() {
        guard let gamepad = wrappedController.extendedGamepad else { return }

        gamepad.valueChangedHandler = { [weak self] (gamepad, element) in
            guard let self = self else { return }

            // Find if this button has a mapping
            if let sourceId = self.identifier(for: element),
               let mapping = self.buttonMappings[sourceId],
               let destButton = self.button(for: mapping.destinationId, on: gamepad) {
                // Forward the pressed state
                if let buttonInput = element as? GCControllerButtonInput {
                    destButton.pressedChangedHandler?(destButton, buttonInput.value, buttonInput.isPressed)
                }
            }
        }
    }

    /// Get identifier for a button input
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
                if let dualSense = gamepad as? GCDualSenseGamepad {
                    switch element {
                    case dualSense.buttonOptions: return .share
                    case dualSense.touchpadButton: return .touchpadButton
                    case dualSense.buttonOptions: return .micButton
                    case dualSense.buttonOptions: return .createButton
                    default: break
                    }
                }
                if let xbox = gamepad as? GCXboxGamepad {
                    switch element {
                    case xbox.buttonA: return .paddleOne
                    case xbox.buttonB: return .paddleTwo
                    case xbox.buttonX: return .paddleThree
                    case xbox.buttonY: return .paddleFour
                    case xbox.buttonOptions: return .shareButton
                    default: break
                    }
                }
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
        // Convert mappings to serializable format
        let mappingsData = try? JSONEncoder().encode(buttonMappings)
        UserDefaults.standard.set(mappingsData, forKey: "PVControllerMappings_\(wrappedController.vendorName ?? "unknown")")
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
