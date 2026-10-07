import Foundation

public enum WiiRemoteSidewaysFamily: OverlayFamily {
    public static let id = "wiiRemoteSideways"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .one, .two, .plus, .minus, .home]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let size = kit.faceButton
        // Held sideways: d-pad left thumb, 1/2 right thumb (2 is the primary), A/B above.
        let face = [
            kit.button(.one, binding: binding, at: CGPoint(x: 0, y: 24), size: size, palette: .utility),
            kit.button(.two, binding: binding, at: CGPoint(x: size + 12, y: 0), size: size, palette: .utility)
        ]
        let small = kit.smallButton
        let abButtons = [
            kit.button(.b, binding: binding, at: .zero, size: small, shape: .bar, palette: .utility),
            kit.button(.a, binding: binding, at: CGPoint(x: small + 8, y: 0), size: small, palette: .primary)
        ]
        let base = kit.padTemplate(face: face, shoulders: [], systemButtons: [.minus, .home, .plus],
                                   binding: binding, padKind: padKind, orientation: orientation)
        let landscape = orientation == .landscape
        let abGroup = OverlayGroup(
            id: "ab", controls: abButtons,
            placement: OverlayPlacement(anchor: landscape ? .topTrailing : .bottomTrailing,
                                        inset: CGPoint(x: kit.edge, y: landscape ? 12 : kit.portraitBottom + 140)))
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: base.groups + [abGroup],
                               screenPolicy: base.screenPolicy)
    }
}
