//
//  PVPhysicalProfileMapping.swift
//  PVSupport
//
//  Maps the element names of a controller's physical input profile onto the
//  extended-gamepad inputs every core reads. Pure strings, so it compiles and
//  tests on every platform.
//

import Foundation

/// One input of the extended gamepad a ``PVPhysicalProfileController`` synthesizes.
public enum PVSynthesizedInput: String, CaseIterable, Sendable {
    case dpad, leftThumbstick, rightThumbstick
    case buttonA, buttonB, buttonX, buttonY
    case leftShoulder, rightShoulder, leftTrigger, rightTrigger
    case menu, options, home
    /// Digital buttons that stand in for the right thumbstick: the N64 C cluster.
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight
}

/// Resolves a physical-profile element name to a synthesized input.
///
/// Order: the GameController framework's own element names first (`GCInputButtonA`
/// is "Button A", and so on), then the aliases a non-standard pad may use, then,
/// for the Nintendo Switch Online N64 controller only, bare "Button <n>" names
/// resolved through RetroArch's HID autoconfig for that pad.
///
/// The semantics follow RetroArch's `N64_Nintendo_Switch_Online.cfg`: A → RetroPad B
/// (extended `buttonA`), B → RetroPad Y (`buttonX`), Z → L2 (`leftTrigger`),
/// ZR → Select (`options`), Start → `menu`, Home → `home`, the C buttons → right
/// stick directions, L/R → shoulders. The native N64 bridge and the thin libretro
/// wrapper both read exactly those extended inputs for the N64 layout.
public enum PVPhysicalProfileMapping {

    /// Element names the system uses for standard inputs.
    static let standardNames: [String: PVSynthesizedInput] = [
        "button a": .buttonA, "button b": .buttonB, "button x": .buttonX, "button y": .buttonY,
        "direction pad": .dpad, "left thumbstick": .leftThumbstick, "right thumbstick": .rightThumbstick,
        "left shoulder": .leftShoulder, "right shoulder": .rightShoulder,
        "left trigger": .leftTrigger, "right trigger": .rightTrigger,
        "button menu": .menu, "button options": .options, "button home": .home,
    ]

    /// Aliases for pads whose element names are the labels printed on the buttons.
    static let aliases: [String: PVSynthesizedInput] = [
        "a": .buttonA, "b": .buttonX,
        "x": .buttonY, "y": .buttonB,
        "c up": .rightStickUp, "cup": .rightStickUp, "c down": .rightStickDown, "cdown": .rightStickDown,
        "c left": .rightStickLeft, "cleft": .rightStickLeft, "c right": .rightStickRight, "cright": .rightStickRight,
        "z": .leftTrigger, "z trigger": .leftTrigger, "trigger z": .leftTrigger, "zl": .leftTrigger,
        "zr": .options, "select": .options, "minus": .options, "back": .options, "view": .options,
        "start": .menu, "plus": .menu,
        "home": .home,
        "l": .leftShoulder, "left bumper": .leftShoulder, "l1": .leftShoulder,
        "r": .rightShoulder, "right bumper": .rightShoulder, "r1": .rightShoulder,
        "l2": .leftTrigger, "r2": .rightTrigger,
        "dpad": .dpad, "d pad": .dpad, "hat": .dpad,
        "left stick": .leftThumbstick, "joystick": .leftThumbstick, "stick": .leftThumbstick,
        "right stick": .rightThumbstick,
    ]

    /// RetroArch `N64_Nintendo_Switch_Online.cfg` (hid driver) button indices.
    static let n64HIDButtons: [Int: PVSynthesizedInput] = [
        0: .buttonX,          // B
        1: .buttonA,          // A
        2: .rightStickUp,     // C Up
        3: .rightStickLeft,   // C Left
        4: .leftShoulder,     // L
        5: .rightShoulder,    // R
        6: .leftTrigger,      // Z
        7: .rightStickDown,   // C Down
        8: .rightStickRight,  // C Right
        9: .menu,             // Start
        10: .options,         // ZR
        12: .home,            // Home
    ]

    /// True for the Nintendo Switch Online N64 controller (vendor name "N64 Controller").
    public static func isN64Pad(vendorName: String?, productCategory: String?) -> Bool {
        let haystack = ((vendorName ?? "") + " " + (productCategory ?? "")).lowercased()
        return haystack.contains("n64")
    }

    /// Lowercases, turns `-`/`_` into spaces, collapses whitespace and drops a leading "button ".
    static func normalize(_ name: String) -> String {
        let spaced = name.lowercased().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        let collapsed = spaced.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed
    }

    /// The input an element should drive, or nil when the element is not one a core reads.
    /// - Parameters:
    ///   - name: the key of `physicalInputProfile.elements`.
    ///   - isN64Pad: enables the "Button <n>" fallback from RetroArch's N64 autoconfig.
    public static func input(forElementNamed name: String, isN64Pad: Bool = false) -> PVSynthesizedInput? {
        let normalized = normalize(name)
        if let standard = standardNames[normalized] { return standard }
        let bare = normalized.hasPrefix("button ") ? String(normalized.dropFirst("button ".count)) : normalized
        if let alias = aliases[bare] { return alias }
        if isN64Pad, let index = Int(bare) { return n64HIDButtons[index] }
        return nil
    }

    /// Resolves every element name; later names never override an earlier binding of the
    /// same input, so the system's standard names win over aliases regardless of order.
    public static func bindings(forElementNames names: [String], isN64Pad: Bool = false) -> [String: PVSynthesizedInput] {
        var result: [String: PVSynthesizedInput] = [:]
        var taken: Set<PVSynthesizedInput> = []
        let ordered = names.sorted { lhs, rhs in
            let l = standardNames[normalize(lhs)] != nil, r = standardNames[normalize(rhs)] != nil
            return l != r ? l : lhs < rhs
        }
        for name in ordered {
            guard let input = input(forElementNamed: name, isN64Pad: isN64Pad), !taken.contains(input) else { continue }
            result[name] = input
            taken.insert(input)
        }
        return result
    }

    /// Whether a profile exposes enough to be worth synthesizing: a direction input and a face button.
    public static func isUsable(bindings: [String: PVSynthesizedInput]) -> Bool {
        let inputs = Set(bindings.values)
        let hasDirection = !inputs.isDisjoint(with: [.dpad, .leftThumbstick])
        let hasButton = !inputs.isDisjoint(with: [.buttonA, .buttonB, .buttonX, .buttonY])
        return hasDirection && hasButton
    }
}
