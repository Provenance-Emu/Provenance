import Foundation

/// Two d-pads (Virtual Boy, WonderSwan): the second sits above the two face buttons on the right.
public enum DualDPadFamily: OverlayFamily {
    public static let id = "dualDPad"
    public static let requiredSlots: [OverlayFamilySlot] = [
        .a, .b, .l, .r, .start, .select, .dpad2Up, .dpad2Down, .dpad2Left, .dpad2Right
    ]

    private static let secondDPadSize: CGFloat = 96
    private static let faceHeight: CGFloat = 68
    private static let stackGap: CGFloat = 8

    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let size = kit.faceButton
        let face = [
            kit.button(.b, binding: binding, at: CGPoint(x: 0, y: faceHeight - size), palette: .secondary),
            kit.button(.a, binding: binding, at: CGPoint(x: size + 12, y: 0), palette: .primary)
        ]
        let base = kit.padTemplate(face: face, shoulders: [.l, .r], systemButtons: [.select, .start],
                                   binding: binding, padKind: padKind, orientation: orientation)
        var groups = base.groups
        // Landscape: the face buttons drop to the bottom corner so the second d-pad has the side's middle.
        if landscape, let index = groups.firstIndex(where: { $0.id == "face" }) {
            groups[index].placement = OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: kit.edge, y: 12))
        }
        let pad2Placement = landscape
            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: kit.edge, y: 0))
            : OverlayPlacement(anchor: .bottomTrailing,
                               inset: CGPoint(x: kit.edge, y: kit.portraitBottom + faceHeight + stackGap))
        groups.append(OverlayGroup(id: "dpad2", controls: [kit.secondDPad(binding: binding, size: secondDPadSize)],
                                   placement: pad2Placement))
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: base.screenPolicy)
    }
}
