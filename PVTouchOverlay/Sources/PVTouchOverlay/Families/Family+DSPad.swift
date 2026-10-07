import Foundation

public enum DSPadFamily: OverlayFamily {
    public static let id = "dsPad"
    public static let requiredSlots: [OverlayFamilySlot] = FourFaceFamily.requiredSlots
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let base = FourFaceFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let stylus = OverlayControl(id: "stylus", kind: .touchSurface(.dsScreen),
                                    frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                    shape: .surface, paletteSlot: .shell)
        let surface = OverlayGroup(id: "stylus", controls: [stylus], placement: OverlayPlacement(anchor: .fill))
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: base.groups + [surface],
                               screenPolicy: orientation == .portrait ? .dualStacked : .centerColumn)
    }
}
