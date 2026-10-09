import Foundation
import CoreGraphics

public enum OverlaySurfaceRole: String, Codable, Sendable, Hashable { case dsScreen, wiiPointer, lightGun, trackpad }
public enum OverlayAction: String, Codable, Sendable, Hashable {
    case menu, quickSave, quickLoad, fastForward, toggleKeyboard, toggleMouse, screenshot
    /// Shows or hides the template's keypad group. Handled inside the overlay; the core never sees it.
    case keypad
    /// Lynx: rotates the picture for games drawn sideways.
    case flip
    /// Famicom Disk System: turns the disk over.
    case diskSide
    /// Arcade service / test switch.
    case service

    /// Text on the action's pill.
    public var defaultLabel: String {
        switch self {
        case .menu: return "MENU"
        case .quickSave: return "SAVE"
        case .quickLoad: return "LOAD"
        case .fastForward: return "FF"
        case .toggleKeyboard: return "KEYS"
        case .toggleMouse: return "MOUSE"
        case .screenshot: return "SHOT"
        case .keypad: return "KEYPAD"
        case .flip: return "FLIP"
        case .diskSide: return "DISK"
        case .service: return "SERVICE"
        }
    }
}

/// Which axes a stick reports. A paddle only turns left and right.
public enum OverlayStickAxis: String, Codable, Sendable, Hashable {
    case both, horizontal

    /// Drops the vertical component of a horizontal-only stick.
    public func constrained(x horizontal: Float, y vertical: Float) -> (x: Float, y: Float) {
        self == .horizontal ? (horizontal, 0) : (horizontal, vertical)
    }
}
public enum OverlayStickSide: String, Codable, Sendable, Hashable {
    case left, right
    /// Token understood by `DeltaSkinInputHandler.analogStickMoved(_:x:y:)`.
    public var token: String { self == .left ? "leftThumbstick" : "rightThumbstick" }
}

public enum OverlayControlKind: Hashable, Codable, Sendable {
    case button(OverlayInputID)
    case dpad(up: OverlayInputID, down: OverlayInputID, left: OverlayInputID, right: OverlayInputID)
    case stick(OverlayStickSide, click: OverlayInputID?)
    case analogTrigger(OverlayInputID)
    case touchSurface(OverlaySurfaceRole)
    case hardwareSwitch(descriptorID: String)
    case action(OverlayAction)
}

public enum OverlayShape: String, Codable, Sendable, Hashable, CaseIterable {
    case circle, kidney, pill, bar, cross, ring, knob, key, surface
}

public enum OverlayPaletteSlot: String, Codable, Sendable, Hashable {
    case shell, primary, secondary, tertiary, quaternary, utility, dpad, stick, label
}

public struct OverlayControl: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var kind: OverlayControlKind
    /// Group-local points at reference scale (390pt-wide phone).
    public var frame: CGRect
    public var label: String?
    public var shape: OverlayShape
    public var paletteSlot: OverlayPaletteSlot
    /// Only meaningful for sticks.
    public var axis: OverlayStickAxis

    public init(id: String, kind: OverlayControlKind, frame: CGRect, label: String? = nil,
                shape: OverlayShape, paletteSlot: OverlayPaletteSlot, axis: OverlayStickAxis = .both) {
        self.id = id; self.kind = kind; self.frame = frame
        self.label = label; self.shape = shape; self.paletteSlot = paletteSlot; self.axis = axis
    }
}
