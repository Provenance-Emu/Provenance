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

/// The pad family a physical profile belongs to. Decides what printed labels and bare
/// "Button <n>" names mean, because the Nintendo Switch Online pads label their faces
/// differently: the N64 pad's A/B are its two face buttons, while the SNES pad's
/// B/A/Y/X are the RetroPad layout.
public enum PVPhysicalProfilePad: String, Sendable {
    case generic
    /// Nintendo Switch Online N64 controller (vendor name "N64 Controller").
    case n64
    /// Nintendo Switch Online SNES controller (vendor name "SNES Controller").
    case snes
    /// Nintendo Switch Online Mega Drive / Genesis control pad.
    case megaDrive

    /// Detects the family from what the system reports for the controller.
    public static func detect(vendorName: String?, productCategory: String?) -> PVPhysicalProfilePad {
        let haystack = ((vendorName ?? "") + " " + (productCategory ?? "")).lowercased()
        if haystack.contains("n64") { return .n64 }
        if haystack.contains("snes") || haystack.contains("super nintendo") || haystack.contains("super famicom") { return .snes }
        if haystack.contains("md/gen") || haystack.contains("mega drive") || haystack.contains("megadrive") || haystack.contains("genesis") { return .megaDrive }
        return .generic
    }

    /// The Switch Online pads, which the system exposes without an extended gamepad.
    public var isSwitchOnline: Bool { self != .generic }

    /// Whether the system's face element names ("Button A" …) are the printed labels
    /// rather than positions. True for the SNES pad: Apple's "Button A" is the button
    /// marked A (right), so binding it positionally swapped A/B and X/Y in every core
    /// (tester-confirmed with Contra III). The N64 and Mega Drive pads probably follow the
    /// same rule (Nintendo-built profiles; Joy-Cons need the same swap in
    /// `PVRemappableController`), but neither profile is verified, so they keep the
    /// positional reading until one is.
    public var namesFacesByLabel: Bool { self == .snes }
}

/// Resolves a physical-profile element name to a synthesized input.
///
/// Order: the GameController framework's own element names first (`GCInputButtonA`
/// is "Button A", and so on; on a pad whose ``PVPhysicalProfilePad/namesFacesByLabel``
/// the four face names resolve as printed labels), then the printed-label aliases of
/// the pad family, then
/// bare "Button <n>" names resolved through RetroArch's HID autoconfig for that pad
/// (libretro/retroarch-joypad-autoconfig, `hid/*_Switch_Online.cfg`).
///
/// RetroPad → extended gamepad: B → `buttonA`, A → `buttonB`, Y → `buttonX`,
/// X → `buttonY`, L/R → shoulders, L2/R2 → triggers, Select → `options`,
/// Start → `menu`, menu toggle → `home`. That is what the native bridges and the
/// thin libretro wrapper read.
public enum PVPhysicalProfileMapping {

    /// Element names the system uses for standard inputs.
    /// The system's face element names; on a ``PVPhysicalProfilePad/namesFacesByLabel`` pad
    /// these mean the printed labels and resolve through ``faceAliases``.
    static let standardFaceNames: Set<String> = ["button a", "button b", "button x", "button y"]

    static let standardNames: [String: PVSynthesizedInput] = [
        "button a": .buttonA, "button b": .buttonB, "button x": .buttonX, "button y": .buttonY,
        "direction pad": .dpad, "left thumbstick": .leftThumbstick, "right thumbstick": .rightThumbstick,
        "left shoulder": .leftShoulder, "right shoulder": .rightShoulder,
        "left trigger": .leftTrigger, "right trigger": .rightTrigger,
        "button menu": .menu, "button options": .options, "button home": .home,
    ]

    /// Labels common to every pad: shoulders, triggers, system buttons, directions.
    static let commonAliases: [String: PVSynthesizedInput] = [
        "zl": .leftTrigger, "l2": .leftTrigger, "zr": .rightTrigger, "r2": .rightTrigger,
        "select": .options, "minus": .options, "back": .options, "view": .options, "mode": .options,
        "start": .menu, "plus": .menu,
        "home": .home,
        "l": .leftShoulder, "left bumper": .leftShoulder, "l1": .leftShoulder,
        "r": .rightShoulder, "right bumper": .rightShoulder, "r1": .rightShoulder,
        "dpad": .dpad, "d pad": .dpad, "hat": .dpad,
        "left stick": .leftThumbstick, "joystick": .leftThumbstick, "stick": .leftThumbstick,
        "right stick": .rightThumbstick,
    ]

    /// Face labels per family (RetroPad layout: B bottom, A right, Y left, X top).
    static let faceAliases: [PVPhysicalProfilePad: [String: PVSynthesizedInput]] = [
        .generic: ["a": .buttonB, "b": .buttonA, "x": .buttonY, "y": .buttonX],
        .snes: ["a": .buttonB, "b": .buttonA, "x": .buttonY, "y": .buttonX],
        // N64_Nintendo_Switch_Online.cfg: A → RetroPad B, B → RetroPad Y, Z → L2, ZR → Select,
        // C buttons → right stick.
        .n64: [
            "a": .buttonA, "b": .buttonX,
            "z": .leftTrigger, "z trigger": .leftTrigger, "trigger z": .leftTrigger,
            "zr": .options,
            "c up": .rightStickUp, "cup": .rightStickUp, "c down": .rightStickDown, "cdown": .rightStickDown,
            "c left": .rightStickLeft, "cleft": .rightStickLeft, "c right": .rightStickRight, "cright": .rightStickRight,
        ],
        // MD_Gen_Control_Pad_Switch_Online.cfg: B → RetroPad B, A → Y, Y → X, X → L, Z → R, C → A, Mode → Select.
        .megaDrive: [
            "b": .buttonA, "a": .buttonX, "y": .buttonY, "x": .leftShoulder, "z": .rightShoulder, "c": .buttonB,
        ],
    ]

    /// RetroArch HID autoconfig button indices per family.
    static let hidButtons: [PVPhysicalProfilePad: [Int: PVSynthesizedInput]] = [
        // N64_Nintendo_Switch_Online.cfg
        .n64: [
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
        ],
        // SNES_Nintendo_Switch_Online.cfg
        .snes: [
            0: .buttonA,          // B
            1: .buttonB,          // A
            2: .buttonX,          // Y
            3: .buttonY,          // X
            4: .leftShoulder,     // L
            5: .rightShoulder,    // R
            6: .leftTrigger,      // ZL
            8: .options,          // Select
            9: .menu,             // Start
            15: .rightTrigger,    // ZR
        ],
        // MD_Gen_Control_Pad_Switch_Online.cfg
        .megaDrive: [
            0: .buttonA,          // B
            1: .buttonX,          // A
            2: .buttonY,          // Y
            4: .rightShoulder,    // Z
            5: .buttonB,          // C
            6: .leftShoulder,     // X
            7: .options,          // Mode
            9: .menu,             // Start
            12: .home,            // Home
        ],
    ]

    /// Lowercases, turns `-`/`_` into spaces and collapses whitespace.
    static func normalize(_ name: String) -> String {
        let spaced = name.lowercased().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return spaced.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The input an element should drive, or nil when the element is not one a core reads.
    /// - Parameters:
    ///   - name: the key of `physicalInputProfile.elements`.
    ///   - pad: the family, which selects the face labels and the "Button <n>" table.
    public static func input(forElementNamed name: String, pad: PVPhysicalProfilePad = .generic) -> PVSynthesizedInput? {
        let normalized = normalize(name)
        let bare = normalized.hasPrefix("button ") ? String(normalized.dropFirst("button ".count)) : normalized
        if pad.namesFacesByLabel, standardFaceNames.contains(normalized), let face = faceAliases[pad]?[bare] { return face }
        if let standard = standardNames[normalized] { return standard }
        if let face = faceAliases[pad]?[bare] { return face }
        if let common = commonAliases[bare] { return common }
        if let index = Int(bare) { return hidButtons[pad]?[index] }
        return nil
    }

    /// Resolves every element name; later names never override an earlier binding of the
    /// same input, so the system's standard names win over aliases regardless of order.
    public static func bindings(forElementNames names: [String], pad: PVPhysicalProfilePad = .generic) -> [String: PVSynthesizedInput] {
        var result: [String: PVSynthesizedInput] = [:]
        var taken: Set<PVSynthesizedInput> = []
        let ordered = names.sorted { lhs, rhs in
            let l = standardNames[normalize(lhs)] != nil, r = standardNames[normalize(rhs)] != nil
            return l != r ? l : lhs < rhs
        }
        for name in ordered {
            guard let input = input(forElementNamed: name, pad: pad), !taken.contains(input) else { continue }
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

    /// Select + Start, the pause chord for pads with no Home button.
    public static let selectStartChord: Set<PVSynthesizedInput> = [.options, .menu]

    /// How a synthesized pad opens the Provenance pause menu: its Home button when it
    /// has one, otherwise Select + Start held together. Start and Select alone always
    /// reach the game.
    ///
    /// The Switch Online SNES pad is the chord case. Apple's profile for it
    /// (`_GCNintendoSuperFamicomControllerProfile`, iOS 26 / tvOS 27) exposes only
    /// A, B, X, Y, L, R, Start ("Button Menu"), Select ("Button Options") and the
    /// D-pad: no Home, and no ZL/ZR although the pad has them.
    public static func pauseTrigger(forBindings bindings: [String: PVSynthesizedInput]) -> PVPauseTrigger? {
        let inputs = Set(bindings.values)
        if inputs.contains(.home) { return .home }
        if selectStartChord.isSubset(of: inputs) { return .chord(selectStartChord) }
        return nil
    }
}

/// What opens the Provenance pause menu on a synthesized pad.
public enum PVPauseTrigger: Equatable, Sendable {
    /// The pad's Home button.
    case home
    /// Every input in the set held at once.
    case chord(Set<PVSynthesizedInput>)

    /// Whether `pressed` completes this trigger.
    public func isSatisfied(by pressed: Set<PVSynthesizedInput>) -> Bool {
        switch self {
        case .home: return pressed.contains(.home)
        case .chord(let inputs): return !inputs.isEmpty && inputs.isSubset(of: pressed)
        }
    }

    /// Inputs that belong to the trigger and so are held back from the game once it fires.
    public var inputs: Set<PVSynthesizedInput> {
        switch self {
        case .home: return [.home]
        case .chord(let inputs): return inputs
        }
    }
}
