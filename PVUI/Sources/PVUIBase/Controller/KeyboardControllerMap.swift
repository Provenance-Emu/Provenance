import Foundation
import GameController
import PVSettings
import Defaults

/// A remappable action on the virtual keyboard-controller.
public enum KeyboardControllerAction: String, CaseIterable, Codable {
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftStickUp, leftStickDown, leftStickLeft, leftStickRight
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight
    case buttonA, buttonB, buttonX, buttonY
    case l1, l2, r1, r2, l3, r3
    case menu, options, select, start

    public var displayName: String {
        switch self {
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .leftStickUp: return "Left Stick Up"
        case .leftStickDown: return "Left Stick Down"
        case .leftStickLeft: return "Left Stick Left"
        case .leftStickRight: return "Left Stick Right"
        case .rightStickUp: return "Right Stick Up"
        case .rightStickDown: return "Right Stick Down"
        case .rightStickLeft: return "Right Stick Left"
        case .rightStickRight: return "Right Stick Right"
        case .buttonA: return "A"
        case .buttonB: return "B"
        case .buttonX: return "X"
        case .buttonY: return "Y"
        case .l1: return "L1"
        case .l2: return "L2"
        case .r1: return "R1"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .menu: return "Menu"
        case .options: return "Options"
        case .select: return "Select"
        case .start: return "Start"
        }
    }
}

/// Keyboard→controller bindings, persisted to Defaults. Falls back to `standard`
/// (the historical hardcoded map) for any action with no stored binding.
public struct KeyboardControllerMap {
    private var bindings: [KeyboardControllerAction: [GCKeyCode]]

    /// The historical hardcoded layout (see the ASCII art above GCKeyboard.createController()).
    public static let standard = KeyboardControllerMap(bindings: [
        .dpadUp: [.upArrow], .dpadDown: [.downArrow], .dpadLeft: [.leftArrow], .dpadRight: [.rightArrow],
        .leftStickUp: [.keyW], .leftStickDown: [.keyS], .leftStickLeft: [.keyA], .leftStickRight: [.keyD],
        .rightStickUp: [.equalSign, .keyO], .rightStickDown: [.hyphen, .keyL],
        .rightStickLeft: [.openBracket, .keyK], .rightStickRight: [.closeBracket, .semicolon],
        .buttonA: [.spacebar, .returnOrEnter], .buttonB: [.keyF, .escape],
        .buttonX: [.keyQ], .buttonY: [.keyE],
        .l1: [.tab, .capsLock], .l2: [.leftShift],
        .r1: [.keyR], .r2: [.keyV],
        .l3: [.keyX], .r3: [.keyC],
        .menu: [.graveAccentAndTilde], .options: [.one, .keyU],
        .select: [.slash], .start: [.rightShift]
    ])

    public init(bindings: [KeyboardControllerAction: [GCKeyCode]]) {
        self.bindings = bindings
    }

    /// The effective map: stored overrides merged over `standard`.
    public static var current: KeyboardControllerMap {
        let stored = Defaults[.keyboardControllerBindings]
        guard !stored.isEmpty else { return .standard }
        var merged = standard.bindings
        for (raw, codes) in stored {
            guard let action = KeyboardControllerAction(rawValue: raw) else { continue }
            merged[action] = codes.map { GCKeyCode(rawValue: $0) }
        }
        return KeyboardControllerMap(bindings: merged)
    }

    public func keys(for action: KeyboardControllerAction) -> [GCKeyCode] {
        bindings[action] ?? []
    }

    public mutating func set(keys: [GCKeyCode], for action: KeyboardControllerAction) {
        bindings[action] = keys
    }

    /// Persist only the diff vs `standard` (so future default-map improvements reach users).
    public func save() {
        var diff: [String: [Int]] = [:]
        for (action, codes) in bindings where Self.standard.bindings[action] != codes {
            diff[action.rawValue] = codes.map { $0.rawValue }
        }
        Defaults[.keyboardControllerBindings] = diff
    }
}
