import Foundation

public enum ThreeFaceFamily: OverlayFamily {
    public static let id = "threeFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .c, .start]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let size = OverlayFamilyKit.faceButton
        // Genesis arc: A low-left, B middle, C high-right.
        let face = [
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: 0, y: 40), palette: .primary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: size + 8, y: 16), palette: .secondary),
            OverlayFamilyKit.button(.c, binding: binding, at: CGPoint(x: 2 * (size + 8), y: 0), palette: .tertiary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [], systemButtons: [.start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
