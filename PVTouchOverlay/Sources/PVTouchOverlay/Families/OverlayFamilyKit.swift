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

    public static func dpad(binding: SystemOverlayBinding, size: CGFloat = dpadSize,
                            shape: OverlayShape = .cross, palette: OverlayPaletteSlot = .dpad) -> OverlayControl {
        let system = binding.system
        return OverlayControl(
            id: "dpad",
            kind: .dpad(up: OverlayInputID(system: system, token: "up"),
                        down: OverlayInputID(system: system, token: "down"),
                        left: OverlayInputID(system: system, token: "left"),
                        right: OverlayInputID(system: system, token: "right")),
            frame: CGRect(x: 0, y: 0, width: size, height: size), shape: shape, paletteSlot: palette)
    }

    /// A second d-pad whose directions come from the binding's `dpad2*` slots.
    public static func secondDPad(binding: SystemOverlayBinding, size: CGFloat) -> OverlayControl {
        OverlayControl(
            id: "dpad2",
            kind: .dpad(up: binding.inputID(.dpad2Up), down: binding.inputID(.dpad2Down),
                        left: binding.inputID(.dpad2Left), right: binding.inputID(.dpad2Right)),
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

    /// Start/Select style pills in a row, 16pt apart. Hidden slots leave no gap.
    public static func pillRow(_ slots: [OverlayFamilySlot], binding: SystemOverlayBinding,
                               size: CGSize = pillSize, gap: CGFloat = edge) -> [OverlayControl] {
        slots.filter { !binding.isHidden($0) }.enumerated().map { index, slot in
            OverlayControl(id: slot.rawValue, kind: .button(binding.inputID(slot)),
                           frame: CGRect(x: CGFloat(index) * (size.width + gap), y: 0,
                                         width: size.width, height: size.height),
                           label: binding.label(slot), shape: .pill, paletteSlot: .utility)
        }
    }

    /// One pill per action, in a row, appended after `controls` (used for the system row's extras).
    public static func actionPills(_ actions: [OverlayAction], startingAt column: Int = 0,
                                   size: CGSize = pillSize, gap: CGFloat = edge) -> [OverlayControl] {
        actions.enumerated().map { index, action in
            OverlayControl(id: "action-\(action.rawValue)", kind: .action(action),
                           frame: CGRect(x: CGFloat(column + index) * (size.width + gap), y: 0,
                                         width: size.width, height: size.height),
                           label: action.defaultLabel, shape: .pill, paletteSlot: .utility)
        }
    }

    /// The binding's function buttons floating at the top-right corner, or nil when it has none.
    public static func actionsGroup(binding: SystemOverlayBinding) -> OverlayGroup? {
        let actions = binding.actions.filter { $0 != .keypad }
        guard !actions.isEmpty else { return nil }
        return OverlayGroup(id: "actions", controls: actionPills(actions),
                            placement: OverlayPlacement(anchor: .topTrailing, inset: CGPoint(x: edge, y: 8)))
    }

    /// Latching console switches (2600 difficulty and TV type) as pills in a row. Each press flips the switch
    /// through `DeltaSkinInputHandler`'s position-less tokens.
    public static func switchesGroup(binding: SystemOverlayBinding, orientation: OverlayOrientation) -> OverlayGroup? {
        let switches = binding.hardwareSwitches.compactMap { OverlayHardwareSwitch.named($0) }
        guard !switches.isEmpty else { return nil }
        let controls = switches.enumerated().map { index, entry in
            OverlayControl(id: "switch-\(entry.id)",
                           kind: .button(OverlayInputID(system: binding.system, token: entry.token)),
                           frame: CGRect(x: CGFloat(index) * (pillSize.width + edge), y: 0,
                                         width: pillSize.width, height: pillSize.height),
                           label: entry.label, shape: .pill, paletteSlot: .utility)
        }
        let landscape = orientation == .landscape
        // Above the system pills in landscape; above the d-pad and face row in portrait, where the
        // clusters flank too little room for a row beside them.
        let bottom = landscape ? 12 + pillSize.height + 8 : portraitBottom + dpadSize + 24
        return OverlayGroup(id: "switches", controls: controls,
                            placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: bottom)))
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
        // l, r on row 0; l2, r2 on row 1, or row 0 when l and r are hidden.
        let hasFirstRow = shoulders.contains { !$0.rawValue.hasSuffix("2") && !binding.isHidden($0) }
        for slot in shoulders where !binding.isHidden(slot) {
            let leading = slot.rawValue.hasPrefix("l")
            let row: CGFloat = slot.rawValue.hasSuffix("2") && hasFirstRow ? 1 : 0
            let anchor: OverlayPlacement.Anchor = landscape ? (leading ? .topLeading : .topTrailing)
                                                            : (leading ? .bottomLeading : .bottomTrailing)
            let rowOffset = row * (shoulderSize.height + 8)
            let inset = landscape ? CGPoint(x: edge, y: 12 + rowOffset)
                                  : CGPoint(x: edge, y: shoulderY + rowOffset)
            groups.append(OverlayGroup(id: "shoulder-\(slot.rawValue)",
                                       controls: [shoulder(slot, binding: binding, analog: analogShoulders)],
                                       placement: OverlayPlacement(anchor: anchor, inset: inset)))
        }
        let pills = pillRow(systemButtons, binding: binding)
        if !pills.isEmpty {
            groups.append(OverlayGroup(
                id: "system", controls: pills,
                placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 12 : 20))))
        }
        if let actions = actionsGroup(binding: binding) { groups.append(actions) }
        if let switches = switchesGroup(binding: binding, orientation: orientation) { groups.append(switches) }
        if binding.leftStick {
            // One stick in the bottom-left corner under the d-pad (`DualStickFamily` adds the pair).
            let size = landscape ? landscapeStickSize : stickSize
            groups.append(OverlayGroup(id: "leftStick", controls: [stick(.left, size: size)],
                                       placement: OverlayPlacement(
                                        anchor: .bottomLeading,
                                        inset: CGPoint(x: edge + (landscape ? 30 : 20), y: 12))))
            groups = stackAboveSticks(groups, orientation: orientation)
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
            case let id where !landscape && (id == "dpad" || id == "face" || id.hasPrefix("shoulder-")):
                moved.placement.inset.y += lift
            default:
                break
            }
            return moved
        }
    }
}
