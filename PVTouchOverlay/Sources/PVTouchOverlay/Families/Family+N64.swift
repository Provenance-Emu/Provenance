import Foundation

public enum N64Family: OverlayFamily {
    public static let id = "n64"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .z, .l, .r, .start, .cUp, .cDown, .cLeft, .cRight]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let face = kit.faceButton, cell = kit.smallButton
        let faceButtons = [
            kit.button(.b, binding: binding, at: .zero, palette: .quaternary),                   // green B upper-left
            // Blue A, larger, diagonally down-right of B; clear of B so the two never overlap.
            kit.button(.a, binding: binding, at: CGPoint(x: face + 4, y: face - 4), size: face + 8,
                       palette: .tertiary)
        ]
        let cCluster = cButtons(binding: binding)
        let shoulderInset = CGPoint(x: kit.edge, y: landscape ? 12 : kit.portraitBottom + kit.stickSize + 140)
        let zBottom = 20 + kit.pillSize.height + 12
        let groups: [OverlayGroup] = [
            OverlayGroup(id: "leftStick", controls: [kit.stick(.left)],
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomLeading,
                                               inset: CGPoint(x: kit.edge + 12, y: kit.portraitBottom))),
            OverlayGroup(id: "dpad", controls: [kit.dpad(binding: binding, size: 110)],
                         placement: landscape
                            ? OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: kit.edge, y: 12))
                            : OverlayPlacement(anchor: .bottomLeading,
                                               inset: CGPoint(x: kit.edge,
                                                              y: kit.portraitBottom + kit.stickSize + 20))),
            OverlayGroup(id: "face", controls: faceButtons,
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerTrailing,
                                               inset: CGPoint(x: kit.edge + 3 * cell + 12, y: 0))
                            : OverlayPlacement(anchor: .bottomTrailing,
                                               inset: CGPoint(x: kit.edge + 3 * cell + 12, y: kit.portraitBottom))),
            OverlayGroup(id: "cCluster", controls: cCluster,
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomTrailing,
                                               inset: CGPoint(x: kit.edge, y: kit.portraitBottom + 20))),
            OverlayGroup(id: "shoulder-l", controls: [kit.shoulder(.l, binding: binding)],
                         placement: OverlayPlacement(anchor: landscape ? .topLeading : .bottomLeading,
                                                     inset: shoulderInset)),
            OverlayGroup(id: "shoulder-r", controls: [kit.shoulder(.r, binding: binding)],
                         placement: OverlayPlacement(anchor: landscape ? .topTrailing : .bottomTrailing,
                                                     inset: shoulderInset)),
            OverlayGroup(id: "z", controls: [kit.shoulder(.z, binding: binding)],
                         placement: OverlayPlacement(anchor: .bottomCenter,
                                                     inset: CGPoint(x: 0, y: landscape ? 60 : zBottom))),
            OverlayGroup(id: "system", controls: kit.pillRow([.start], binding: binding),
                         placement: OverlayPlacement(anchor: .bottomCenter,
                                                     inset: CGPoint(x: 0, y: landscape ? 12 : 20)))
        ]
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }

    private static func cButtons(binding: SystemOverlayBinding) -> [OverlayControl] {
        let kit = OverlayFamilyKit.self
        let cell = kit.smallButton
        return [
            kit.button(.cUp, binding: binding, at: CGPoint(x: cell, y: 0), size: cell, palette: .secondary),
            kit.button(.cLeft, binding: binding, at: CGPoint(x: 0, y: cell), size: cell, palette: .secondary),
            kit.button(.cRight, binding: binding, at: CGPoint(x: 2 * cell, y: cell), size: cell, palette: .secondary),
            kit.button(.cDown, binding: binding, at: CGPoint(x: cell, y: 2 * cell), size: cell, palette: .secondary)
        ]
    }
}
