import Foundation

/// Upright Wii Remote: Nunchuk stick and C/Z on the left, pointer surface over the picture.
public enum WiiRemoteFamily: OverlayFamily {
    public static let id = "wiiRemote"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .one, .two, .plus, .minus, .home, .c, .z]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let pointer = OverlayControl(id: "pointer", kind: .touchSurface(.wiiPointer),
                                     frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                     shape: .surface, paletteSlot: .shell)
        let lower = kit.portraitBottom
        let groups: [OverlayGroup] = [
            OverlayGroup(id: "pointer", controls: [pointer], placement: OverlayPlacement(anchor: .fill)),
            OverlayGroup(id: "nunchukStick", controls: [kit.stick(.left)],
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: kit.edge + 8, y: lower))),
            OverlayGroup(id: "nunchukCZ", controls: nunchukButtons(binding: binding),
                         placement: landscape
                            ? OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: kit.edge, y: 12))
                            : OverlayPlacement(anchor: .bottomLeading,
                                               inset: CGPoint(x: kit.edge + kit.stickSize + 20, y: lower + 20))),
            OverlayGroup(id: "dpad", controls: [kit.dpad(binding: binding, size: 100)],
                         placement: landscape
                            ? OverlayPlacement(anchor: .topLeading, inset: CGPoint(x: kit.edge, y: 12))
                            : OverlayPlacement(anchor: .bottomLeading,
                                               inset: CGPoint(x: kit.edge, y: lower + kit.stickSize + 24))),
            OverlayGroup(id: "ab", controls: abButtons(binding: binding),
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: kit.edge, y: lower))),
            OverlayGroup(id: "oneTwo", controls: oneTwoButtons(binding: binding),
                         placement: landscape
                            ? OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: kit.edge, y: 12))
                            : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: kit.edge, y: lower + 100))),
            OverlayGroup(id: "system", controls: kit.pillRow([.minus, .home, .plus], binding: binding),
                         placement: OverlayPlacement(anchor: .bottomCenter,
                                                     inset: CGPoint(x: 0, y: landscape ? 12 : 20)))
        ]
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }

    private static func abButtons(binding: SystemOverlayBinding) -> [OverlayControl] {
        [
            OverlayFamilyKit.button(.a, binding: binding, at: .zero, size: 64, palette: .primary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: 72, y: 24), size: 56,
                                    shape: .bar, palette: .utility)
        ]
    }

    private static func oneTwoButtons(binding: SystemOverlayBinding) -> [OverlayControl] {
        let size = OverlayFamilyKit.smallButton
        return [
            OverlayFamilyKit.button(.one, binding: binding, at: .zero, size: size, palette: .utility),
            OverlayFamilyKit.button(.two, binding: binding, at: CGPoint(x: size + 8, y: 0), size: size,
                                    palette: .utility)
        ]
    }

    private static func nunchukButtons(binding: SystemOverlayBinding) -> [OverlayControl] {
        let size = OverlayFamilyKit.smallButton
        return [
            OverlayFamilyKit.button(.c, binding: binding, at: .zero, size: size, palette: .utility),
            OverlayFamilyKit.button(.z, binding: binding, at: CGPoint(x: 0, y: size + 8), size: size,
                                    shape: .bar, palette: .utility)
        ]
    }
}
