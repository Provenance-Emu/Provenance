/// Maps Delta skin button input identifiers to DSU packet button bits and analog values.
///
/// Delta skins use descriptive string IDs for buttons (`"a"`, `"l2"`, `"dpad_up"`, etc.)
/// while the DSU/CemuHook protocol encodes controller state in PlayStation-style bitmasks
/// and analog byte values (0-255). This mapper bridges the two representations.
///
/// Reference bit layout:
/// - `buttons1`: `[share, l3, r3, options, dpadUp, dpadDown, dpadLeft, dpadRight]` (MSB → LSB)
/// - `buttons2`: `[l1, r1, l2, r2, cross, circle, square, triangle]` (MSB → LSB)

import Foundation

// MARK: - Button effect

/// The change that pressing or releasing a skin button applies to a `DSUControllerData`.
public struct DSUButtonEffect: Sendable {
    /// Bit mask to OR into `buttons1` when pressed (0 = not in byte 1).
    public let buttons1Mask: UInt8
    /// Bit mask to OR into `buttons2` when pressed (0 = not in byte 2).
    public let buttons2Mask: UInt8
    /// Closure that writes the analog value (0 or 255) for pressed/released state.
    public let applyAnalog: @Sendable (Bool, inout DSUControllerData) -> Void

    public init(
        buttons1Mask: UInt8 = 0,
        buttons2Mask: UInt8 = 0,
        applyAnalog: @Sendable @escaping (Bool, inout DSUControllerData) -> Void = { _, _ in }
    ) {
        self.buttons1Mask = buttons1Mask
        self.buttons2Mask = buttons2Mask
        self.applyAnalog = applyAnalog
    }
}

// MARK: - Mapper

/// Maps Delta skin input IDs to DSU button effects.
///
/// Delta skins use lowercase snake_case identifiers. Many systems use non-PlayStation
/// button names (e.g. `"a"` on Nintendo = Cross on PlayStation). This mapper accepts
/// *both* the Delta/Nintendo naming and the DSU/PlayStation naming for each button,
/// normalising them to a single `DSUButtonEffect`.
public enum DSUSkinButtonMapper {

    // MARK: - Public API

    /// Returns the `DSUButtonEffect` for the given input ID, or `nil` for unknown IDs.
    ///
    /// Input IDs are case-insensitive and may include underscores, hyphens, or spaces.
    public static func effect(for inputID: String) -> DSUButtonEffect? {
        table[normalize(inputID)]
    }

    /// Applies a button press or release from a skin input ID to `data`.
    ///
    /// - Parameters:
    ///   - inputID: The Delta skin button identifier (e.g. `"a"`, `"l2"`, `"dpad_up"`).
    ///   - pressed: `true` for press, `false` for release.
    ///   - data: The controller data struct to mutate in-place.
    public static func apply(inputID: String, pressed: Bool, to data: inout DSUControllerData) {
        guard let effect = effect(for: inputID) else { return }
        if pressed {
            data.buttons1 |= effect.buttons1Mask
            data.buttons2 |= effect.buttons2Mask
        } else {
            data.buttons1 &= ~effect.buttons1Mask
            data.buttons2 &= ~effect.buttons2Mask
        }
        effect.applyAnalog(pressed, &data)
    }

    /// Updates an analog stick from a skin joystick input ID.
    ///
    /// - Parameters:
    ///   - inputID: The Delta skin directional/joystick identifier (e.g. `"leftthumbstick"`, `"rightthumbstick"`).
    ///   - x: Horizontal axis, range -1.0 to +1.0.
    ///   - y: Vertical axis, range -1.0 to +1.0 (positive = up in skin space).
    ///   - data: The controller data struct to mutate in-place.
    public static func applyAnalogStick(inputID: String, x: Float, y: Float, to data: inout DSUControllerData) {
        let clampedX = max(-1.0, min(1.0, x))
        // DSU Y axis: 0 = up, 255 = down; skin Y is typically positive-up, so we invert.
        let clampedY = max(-1.0, min(1.0, -y))
        // Round so that the neutral position (0,0) maps to the DSU centre value of 128.
        let byteX = UInt8(min(255.0, max(0.0, (clampedX + 1.0) * 127.5)).rounded())
        let byteY = UInt8(min(255.0, max(0.0, (clampedY + 1.0) * 127.5)).rounded())

        switch normalize(inputID) {
        case "leftthumbstick", "leftstick", "thumbstickleft", "leftthumstick", "l3stick":
            data.leftStickX = byteX
            data.leftStickY = byteY
        case "rightthumbstick", "rightstick", "thumbstickright", "rightthumstick", "r3stick":
            data.rightStickX = byteX
            data.rightStickY = byteY
        default:
            break
        }
    }

    // MARK: - Lookup table

    /// Normalises an input ID for table lookup (lowercased, stripping punctuation).
    private static func normalize(_ id: String) -> String {
        id.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    // swiftlint:disable closure_body_length
    private static let table: [String: DSUButtonEffect] = {
        var t: [String: DSUButtonEffect] = [:]

        // MARK: D-pad
        // buttons1 bits: dpadRight=1, dpadLeft=2, dpadDown=4, dpadUp=8 (bits 0-3 from LSB)
        t["dpadup"]      = DSUButtonEffect(buttons1Mask: 0x08, applyAnalog: { p, d in d.dpadUp    = p ? 255 : 0 })
        t["up"]          = t["dpadup"]!
        t["dpaddown"]    = DSUButtonEffect(buttons1Mask: 0x04, applyAnalog: { p, d in d.dpadDown  = p ? 255 : 0 })
        t["down"]        = t["dpaddown"]!
        t["dpadleft"]    = DSUButtonEffect(buttons1Mask: 0x02, applyAnalog: { p, d in d.dpadLeft  = p ? 255 : 0 })
        t["left"]        = t["dpadleft"]!
        t["dpadright"]   = DSUButtonEffect(buttons1Mask: 0x01, applyAnalog: { p, d in d.dpadRight = p ? 255 : 0 })
        t["right"]       = t["dpadright"]!

        // MARK: Meta buttons
        // buttons1 bits: options/start=16, r3=32, l3=64, share/select=128
        t["start"]       = DSUButtonEffect(buttons1Mask: 0x10)
        t["options"]     = t["start"]!
        t["plus"]        = t["start"]!   // Nintendo Switch "+" maps to options/start
        t["r3"]          = DSUButtonEffect(buttons1Mask: 0x20)
        t["r3button"]    = t["r3"]!
        t["thumbstickrightbutton"] = t["r3"]!
        t["l3"]          = DSUButtonEffect(buttons1Mask: 0x40)
        t["l3button"]    = t["l3"]!
        t["thumbstickleftbutton"]  = t["l3"]!
        t["select"]      = DSUButtonEffect(buttons1Mask: 0x80)
        t["share"]       = t["select"]!
        t["minus"]       = t["select"]!  // Nintendo Switch "-" maps to share/select
        t["back"]        = t["select"]!
        t["ps"]          = DSUButtonEffect(applyAnalog: { p, d in d.psButton     = p ? 1 : 0 })
        t["home"]        = t["ps"]!
        t["guide"]       = t["ps"]!
        t["touchpad"]    = DSUButtonEffect(applyAnalog: { p, d in d.touchButton  = p ? 1 : 0 })
        t["touchbutton"] = t["touchpad"]!

        // MARK: Face buttons
        // buttons2 bits: triangle=1, square=2, circle=4, cross=8, r2=16, l2=32, r1=64, l1=128
        // Delta / Nintendo naming: a=cross, b=circle, x=square, y=triangle
        t["a"]           = DSUButtonEffect(buttons2Mask: 0x08, applyAnalog: { p, d in d.buttonCross    = p ? 255 : 0 })
        t["cross"]       = t["a"]!
        t["b"]           = DSUButtonEffect(buttons2Mask: 0x04, applyAnalog: { p, d in d.buttonCircle   = p ? 255 : 0 })
        t["circle"]      = t["b"]!
        t["x"]           = DSUButtonEffect(buttons2Mask: 0x02, applyAnalog: { p, d in d.buttonSquare   = p ? 255 : 0 })
        t["square"]      = t["x"]!
        t["y"]           = DSUButtonEffect(buttons2Mask: 0x01, applyAnalog: { p, d in d.buttonTriangle = p ? 255 : 0 })
        t["triangle"]    = t["y"]!

        // MARK: Shoulder buttons
        t["l1"]          = DSUButtonEffect(buttons2Mask: 0x80, applyAnalog: { p, d in d.buttonL1 = p ? 255 : 0 })
        t["lb"]          = t["l1"]!   // Xbox naming
        t["l"]           = t["l1"]!   // SNES/N64 L button
        t["r1"]          = DSUButtonEffect(buttons2Mask: 0x40, applyAnalog: { p, d in d.buttonR1 = p ? 255 : 0 })
        t["rb"]          = t["r1"]!
        t["r"]           = t["r1"]!   // SNES/N64 R button
        t["l2"]          = DSUButtonEffect(buttons2Mask: 0x20, applyAnalog: { p, d in d.buttonL2  = p ? 255 : 0; d.triggerL2 = p ? 255 : 0 })
        t["lt"]          = t["l2"]!
        t["zl"]          = t["l2"]!   // Nintendo ZL
        t["r2"]          = DSUButtonEffect(buttons2Mask: 0x10, applyAnalog: { p, d in d.buttonR2  = p ? 255 : 0; d.triggerR2 = p ? 255 : 0 })
        t["rt"]          = t["r2"]!
        t["zr"]          = t["r2"]!   // Nintendo ZR

        return t
    }()
    // swiftlint:enable closure_body_length
}
