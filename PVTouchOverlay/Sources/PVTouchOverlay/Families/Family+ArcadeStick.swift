import Foundation

/// An arcade panel: a ball-top 8-way stick on the left, two staggered rows of buttons on the right, and
/// coin, select and start above the buttons. A pad with only one button in the top row (Neo Geo's A B C D)
/// draws a single row of four.
public enum ArcadeStickFamily: OverlayFamily {
    public static let id = "arcadeStick"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .c, .x, .y, .z, .start, .select, .coin]

    private static let buttonSize: CGFloat = 48
    private static let buttonGap: CGFloat = 10
    /// How far the bottom row sits right of the top row, as on a real panel.
    private static let rowStagger: CGFloat = 16
    private static let stickSize: CGFloat = 120
    private static let pillSize = CGSize(width: 56, height: 28)
    private static let pillGap: CGFloat = 12
    private static let rowCount = 2

    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let top = visible([.x, .y, .z], binding)
        let bottom = visible([.a, .b, .c], binding)
        let singleRow = top.count < 2
        let faceHeight = singleRow ? buttonSize : CGFloat(rowCount) * buttonSize + buttonGap
        let pills = kit.pillRow([.coin, .select, .start], binding: binding, size: pillSize, gap: pillGap)

        var groups: [OverlayGroup] = [
            OverlayGroup(id: "stick", controls: [kit.dpad(binding: binding, size: stickSize, shape: .circle,
                                                          palette: .stick)],
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomLeading,
                                               inset: CGPoint(x: kit.edge, y: kit.portraitBottom))),
            OverlayGroup(id: "face", controls: faceButtons(top: top, bottom: bottom, singleRow: singleRow, binding: binding),
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomTrailing,
                                               inset: CGPoint(x: kit.edge, y: kit.portraitBottom)))
        ]
        if !pills.isEmpty {
            groups.append(OverlayGroup(
                id: "system", controls: pills,
                placement: landscape
                    ? OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: 12))
                    : OverlayPlacement(anchor: .bottomTrailing,
                                       inset: CGPoint(x: kit.edge, y: kit.portraitBottom + faceHeight + 12))))
        }
        if let actions = kit.actionsGroup(binding: binding) { groups.append(actions) }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }

    private static func visible(_ slots: [OverlayFamilySlot], _ binding: SystemOverlayBinding) -> [OverlayFamilySlot] {
        slots.filter { !binding.isHidden($0) }
    }

    private static func faceButtons(top: [OverlayFamilySlot], bottom: [OverlayFamilySlot], singleRow: Bool,
                                    binding: SystemOverlayBinding) -> [OverlayControl] {
        let kit = OverlayFamilyKit.self
        let pitch = buttonSize + buttonGap
        func row(_ slots: [OverlayFamilySlot], originX: CGFloat, originY: CGFloat) -> [OverlayControl] {
            slots.enumerated().map { index, slot in
                kit.button(slot, binding: binding, at: CGPoint(x: originX + CGFloat(index) * pitch, y: originY),
                           size: buttonSize, palette: paletteSlot(for: slot))
            }
        }
        if singleRow { return row(bottom + top, originX: 0, originY: 0) }
        return row(top, originX: 0, originY: 0) + row(bottom, originX: rowStagger, originY: pitch)
    }

    /// Four colours cover the six buttons: the bottom row takes the first three, the top row repeats them.
    private static func paletteSlot(for slot: OverlayFamilySlot) -> OverlayPaletteSlot {
        switch slot {
        case .a: return .primary
        case .b: return .secondary
        case .c: return .tertiary
        case .x: return .quaternary
        case .y: return .primary
        default: return .secondary
        }
    }
}
