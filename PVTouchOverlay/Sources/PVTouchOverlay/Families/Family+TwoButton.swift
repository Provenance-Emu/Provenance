import Foundation

public enum TwoButtonFamily: OverlayFamily {
    public static let id = "twoButton"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let size = OverlayFamilyKit.faceButton
        let face = [
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: 0, y: 24), size: size, palette: .secondary),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: size + 12, y: 0), size: size,
                                    palette: .primary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
