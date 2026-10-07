import Foundation

public enum DigitalPadFamily: OverlayFamily {
    public static let id = "digitalPad"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .l2, .r2, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let step = OverlayFamilyKit.faceButton
        // PlayStation diamond: triangle top, square left, circle right, cross bottom.
        // Slots: x = triangle, y = square, b = circle, a = cross.
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: step, y: 0), palette: .quaternary),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: 0, y: step), palette: .tertiary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: 2 * step, y: step), palette: .primary),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: step, y: 2 * step), palette: .secondary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r, .l2, .r2],
                                            systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
