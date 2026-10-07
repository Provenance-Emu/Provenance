import Foundation

public enum DualStickFamily: OverlayFamily {
    public static let id = "dualStick"
    public static let requiredSlots: [OverlayFamilySlot] = DigitalPadFamily.requiredSlots + [.l3, .r3]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let base = DigitalPadFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let landscape = orientation == .landscape
        let kit = OverlayFamilyKit.self
        // Portrait: sticks along the bottom, inset toward the middle. Landscape: small sticks in the bottom
        // corners under the d-pad and face cluster.
        let stickSize = landscape ? kit.landscapeStickSize : kit.stickSize
        let inset = landscape ? CGPoint(x: kit.edge + 30, y: 12) : CGPoint(x: kit.edge + 20, y: 12)
        let groups = base.groups + [
            OverlayGroup(id: "leftStick", controls: [kit.stick(.left, click: binding.inputID(.l3), size: stickSize)],
                         placement: OverlayPlacement(anchor: .bottomLeading, inset: inset)),
            OverlayGroup(id: "rightStick", controls: [kit.stick(.right, click: binding.inputID(.r3), size: stickSize)],
                         placement: OverlayPlacement(anchor: .bottomTrailing, inset: inset))
        ]
        let stacked = kit.stackAboveSticks(groups, orientation: orientation)
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: stacked,
                               screenPolicy: base.screenPolicy)
    }
}
