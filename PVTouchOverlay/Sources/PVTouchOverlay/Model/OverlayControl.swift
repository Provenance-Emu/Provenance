import Foundation
import CoreGraphics

public enum OverlaySurfaceRole: String, Codable, Sendable, Hashable { case dsScreen, wiiPointer, lightGun, trackpad }
public enum OverlayAction: String, Codable, Sendable, Hashable {
    case menu, quickSave, quickLoad, fastForward, toggleKeyboard, toggleMouse, screenshot
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

    public init(id: String, kind: OverlayControlKind, frame: CGRect, label: String? = nil,
                shape: OverlayShape, paletteSlot: OverlayPaletteSlot) {
        self.id = id; self.kind = kind; self.frame = frame
        self.label = label; self.shape = shape; self.paletteSlot = paletteSlot
    }
}
