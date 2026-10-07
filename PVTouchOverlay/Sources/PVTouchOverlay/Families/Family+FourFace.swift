import Foundation

public enum FourFaceFamily: OverlayFamily {
    public static let id = "fourFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let size = OverlayFamilyKit.faceButton
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: size, y: 0), palette: .tertiary),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: 0, y: size), palette: .quaternary),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: 2 * size, y: size), palette: .primary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: size, y: 2 * size), palette: .secondary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
