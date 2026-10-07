import Foundation

public enum WiiClassicFamily: OverlayFamily {
    public static let id = "wiiClassic"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .l2, .r2, .plus, .minus, .home]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let step = OverlayFamilyKit.faceButton
        // Classic Controller: X top, Y left, A right, B bottom.
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: step, y: 0), palette: .utility),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: 0, y: step), palette: .utility),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: 2 * step, y: step), palette: .utility),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: step, y: 2 * step), palette: .utility)
        ]
        let base = OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r, .l2, .r2],
                                                systemButtons: [.minus, .home, .plus],
                                                binding: binding, padKind: padKind, orientation: orientation)
        // Reuse the dual-stick placement so the sticks sit under the pad; the Classic has no stick clicks.
        let dual = DualStickFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let sticks = dual.groups.filter { $0.id == "leftStick" || $0.id == "rightStick" }.map(withoutClicks)
        let lifted = OverlayFamilyKit.stackAboveSticks(base.groups, orientation: orientation)
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: lifted + sticks,
                               screenPolicy: base.screenPolicy)
    }

    private static func withoutClicks(_ group: OverlayGroup) -> OverlayGroup {
        var stripped = group
        stripped.controls = group.controls.map { control in
            var control = control
            if case .stick(let side, _) = control.kind { control.kind = .stick(side, click: nil) }
            return control
        }
        return stripped
    }
}
