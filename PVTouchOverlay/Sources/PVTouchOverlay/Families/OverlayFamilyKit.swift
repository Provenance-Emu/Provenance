import Foundation
import CoreGraphics

/// Shared building blocks so families stay short and consistent.
public enum OverlayFamilyKit {
    public static let faceButton: CGFloat = 56
    public static let smallButton: CGFloat = 44
    public static let dpadSize: CGFloat = 150
    public static let stickSize: CGFloat = 120
    public static let shoulderSize = CGSize(width: 90, height: 40)
    public static let pillSize = CGSize(width: 70, height: 30)
    public static let edge: CGFloat = 16
    /// Stick size on two-stick pads in landscape, where height is scarce.
    public static let landscapeStickSize: CGFloat = 80
    /// Height of the lowest control band above the safe bottom in portrait.
    public static let portraitBottom: CGFloat = 60

    public static func button(_ slot: OverlayFamilySlot, binding: SystemOverlayBinding, at origin: CGPoint,
                              size: CGFloat = faceButton, shape: OverlayShape = .circle,
                              palette: OverlayPaletteSlot) -> OverlayControl {
        OverlayControl(id: slot.rawValue, kind: .button(binding.inputID(slot)),
                       frame: CGRect(origin: origin, size: CGSize(width: size, height: size)),
                       label: binding.label(slot), shape: shape, paletteSlot: palette)
    }

    public static func dpad(binding: SystemOverlayBinding, size: CGFloat = dpadSize) -> OverlayControl {
        let system = binding.system
        return OverlayControl(
            id: "dpad",
            kind: .dpad(up: OverlayInputID(system: system, token: "up"),
                        down: OverlayInputID(system: system, token: "down"),
                        left: OverlayInputID(system: system, token: "left"),
                        right: OverlayInputID(system: system, token: "right")),
            frame: CGRect(x: 0, y: 0, width: size, height: size), shape: .cross, paletteSlot: .dpad)
    }

    public static func stick(_ side: OverlayStickSide, click: OverlayInputID? = nil,
                             size: CGFloat = stickSize) -> OverlayControl {
        OverlayControl(id: side == .left ? "leftStick" : "rightStick", kind: .stick(side, click: click),
                       frame: CGRect(x: 0, y: 0, width: size, height: size), shape: .ring, paletteSlot: .stick)
    }

    public static func shoulder(_ slot: OverlayFamilySlot, binding: SystemOverlayBinding,
                                at origin: CGPoint = .zero, analog: Bool = false) -> OverlayControl {
        let inputID = binding.inputID(slot)
        return OverlayControl(id: slot.rawValue, kind: analog ? .analogTrigger(inputID) : .button(inputID),
                              frame: CGRect(origin: origin, size: shoulderSize), label: binding.label(slot),
                              shape: .bar, paletteSlot: .utility)
    }

    /// Start/Select style pills in a row, 16pt apart.
    public static func pillRow(_ slots: [OverlayFamilySlot], binding: SystemOverlayBinding) -> [OverlayControl] {
        slots.enumerated().map { index, slot in
            OverlayControl(id: slot.rawValue, kind: .button(binding.inputID(slot)),
                           frame: CGRect(x: CGFloat(index) * (pillSize.width + edge), y: 0,
                                         width: pillSize.width, height: pillSize.height),
                           label: binding.label(slot), shape: .pill, paletteSlot: .utility)
        }
    }

    // Standard group set shared by the pad families. `face` is supplied by the family.
    // swiftlint:disable:next function_parameter_count
    public static func padTemplate(face: [OverlayControl], shoulders: [OverlayFamilySlot],
                                   systemButtons: [OverlayFamilySlot], binding: SystemOverlayBinding,
                                   padKind: OverlayPadKind, orientation: OverlayOrientation,
                                   analogShoulders: Bool = false) -> OverlayTemplate {
        let landscape = orientation == .landscape
        let dpadPlacement = landscape
            ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: edge, y: 0))
            : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: edge, y: portraitBottom))
        let facePlacement = landscape
            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: edge, y: 0))
            : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: edge, y: portraitBottom))
        var groups: [OverlayGroup] = [
            OverlayGroup(id: "dpad", controls: [dpad(binding: binding)], placement: dpadPlacement),
            OverlayGroup(id: "face", controls: face, placement: facePlacement)
        ]
        let shoulderY: CGFloat = portraitBottom + dpadSize + 24
        for (index, slot) in shoulders.enumerated() {
            let leading = slot.rawValue.hasPrefix("l")
            let row = CGFloat(index / 2)        // l, r on row 0; l2, r2 on row 1
            let anchor: OverlayPlacement.Anchor = landscape ? (leading ? .topLeading : .topTrailing)
                                                            : (leading ? .bottomLeading : .bottomTrailing)
            let rowOffset = row * (shoulderSize.height + 8)
            let inset = landscape ? CGPoint(x: edge, y: 12 + rowOffset)
                                  : CGPoint(x: edge, y: shoulderY + rowOffset)
            groups.append(OverlayGroup(id: "shoulder-\(slot.rawValue)",
                                       controls: [shoulder(slot, binding: binding, analog: analogShoulders)],
                                       placement: OverlayPlacement(anchor: anchor, inset: inset)))
        }
        if !systemButtons.isEmpty {
            groups.append(OverlayGroup(
                id: "system", controls: pillRow(systemButtons, binding: binding),
                placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 12 : 20))))
        }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }

    /// For pads with two sticks along the bottom edge. Portrait: lifts the d-pad, face cluster and shoulders
    /// above the sticks and sits the system pills just above the stick band. Landscape: the sticks sit in the
    /// bottom corners, so the d-pad and face cluster move up onto them and the centre column stays wide.
    public static func stackAboveSticks(_ groups: [OverlayGroup],
                                        orientation: OverlayOrientation) -> [OverlayGroup] {
        let landscape = orientation == .landscape
        let lift = stickSize + 12
        let pillY = 12 + stickSize + 8
        let landscapeClusterY = 12 + landscapeStickSize + 6
        return groups.map { group in
            var moved = group
            switch group.id {
            case "system" where !landscape:
                moved.placement.inset.y = pillY
            case "dpad" where landscape:
                moved.placement = OverlayPlacement(anchor: .bottomLeading,
                                                   inset: CGPoint(x: edge, y: landscapeClusterY))
            case "face" where landscape:
                moved.placement = OverlayPlacement(anchor: .bottomTrailing,
                                                   inset: CGPoint(x: edge, y: landscapeClusterY))
            case "dpad", "face", _ where group.id.hasPrefix("shoulder-"):
                if !landscape { moved.placement.inset.y += lift }
            default:
                break
            }
            return moved
        }
    }
}
