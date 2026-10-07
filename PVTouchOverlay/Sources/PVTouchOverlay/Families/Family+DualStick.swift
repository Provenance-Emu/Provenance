import Foundation

public enum DualStickFamily: OverlayFamily {
    public static let id = "dualStick"
    public static let requiredSlots: [OverlayFamilySlot] = DigitalPadFamily.requiredSlots + [.l3, .r3]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let base = DigitalPadFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let landscape = orientation == .landscape
        let kit = OverlayFamilyKit.self
        // Sticks sit below and inside the d-pad / face clusters so thumbs rest on them.
        let inset = landscape ? CGPoint(x: kit.edge + kit.dpadSize + 12, y: 12) : CGPoint(x: kit.edge + 20, y: 12)
        let groups = base.groups + [
            OverlayGroup(id: "leftStick", controls: [kit.stick(.left, click: binding.inputID(.l3))],
                         placement: OverlayPlacement(anchor: .bottomLeading, inset: inset)),
            OverlayGroup(id: "rightStick", controls: [kit.stick(.right, click: binding.inputID(.r3))],
                         placement: OverlayPlacement(anchor: .bottomTrailing, inset: inset))
        ]
        // In portrait, lift the d-pad and face above the sticks.
        let lifted = groups.map { group -> OverlayGroup in
            guard !landscape, group.id == "dpad" || group.id == "face" else { return group }
            var lifted = group
            lifted.placement.inset.y += kit.stickSize + 24
            return lifted
        }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: lifted,
                               screenPolicy: base.screenPolicy)
    }
}
