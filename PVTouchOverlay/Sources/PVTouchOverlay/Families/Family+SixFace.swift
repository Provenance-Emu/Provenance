import Foundation

public enum SixFaceFamily: OverlayFamily {
    public static let id = "sixFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .c, .x, .y, .z, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let size = OverlayFamilyKit.smallButton
        let gap: CGFloat = 8
        func col(_ index: Int) -> CGFloat { CGFloat(index) * (size + gap) }
        func button(_ slot: OverlayFamilySlot, _ column: Int, _ originY: CGFloat,
                    _ palette: OverlayPaletteSlot) -> OverlayControl {
            OverlayFamilyKit.button(slot, binding: binding, at: CGPoint(x: col(column), y: originY),
                                    size: size, palette: palette)
        }
        // Top row X Y Z, bottom row A B C, arcing up to the right like the real pad.
        let face = [
            button(.x, 0, 24, .tertiary),
            button(.y, 1, 12, .quaternary),
            button(.z, 2, 0, .utility),
            button(.a, 0, 24 + size + gap, .primary),
            button(.b, 1, 12 + size + gap, .secondary),
            button(.c, 2, size + gap, .tertiary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
