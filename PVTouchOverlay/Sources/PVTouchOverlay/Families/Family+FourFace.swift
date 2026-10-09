import Foundation

public enum FourFaceFamily: OverlayFamily {
    public static let id = "fourFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let size = OverlayFamilyKit.faceButton
        let top = CGPoint(x: size, y: 0), left = CGPoint(x: 0, y: size)
        let right = CGPoint(x: 2 * size, y: size), bottom = CGPoint(x: size, y: 2 * size)
        let dreamcast = binding.faceArrangement == .dreamcast
        func button(_ slot: OverlayFamilySlot, _ origin: CGPoint, _ palette: OverlayPaletteSlot) -> OverlayControl {
            OverlayFamilyKit.button(slot, binding: binding, at: origin, palette: palette)
        }
        let face = [
            button(.x, dreamcast ? left : top, .tertiary),
            button(.y, dreamcast ? top : left, .quaternary),
            button(.a, dreamcast ? bottom : right, .primary),
            button(.b, dreamcast ? right : bottom, .secondary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation,
                                            analogShoulders: binding.analogShoulders)
    }
}
