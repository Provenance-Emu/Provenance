import Foundation

/// A pad with fire buttons and a 12-key keypad that a pill in the system row shows and hides. The keypad
/// is a toggled group (`OverlayGroup.toggledBy`), so while it is off nothing is laid out for it.
public enum KeypadFamily: OverlayFamily {
    public static let id = "keypad"
    public static let requiredSlots: [OverlayFamilySlot] =
        [.a, .b, .c, .start, .select, .reset] + OverlayFamilySlot.keypadKeys

    private static let columns = 3
    private static let keySize = OverlayFamilyKit.smallButton
    private static let keyGap: CGFloat = 6
    private static let keypadTopInset: CGFloat = 8

    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let size = kit.faceButton
        // Fire buttons climb to the right like the real pad's side buttons.
        let face = [
            kit.button(.a, binding: binding, at: CGPoint(x: 0, y: size), palette: .primary),
            kit.button(.b, binding: binding, at: CGPoint(x: size + 6, y: size / 2), palette: .secondary),
            kit.button(.c, binding: binding, at: CGPoint(x: 2 * (size + 6), y: 0), palette: .tertiary)
        ]
        let base = kit.padTemplate(face: face, shoulders: [], systemButtons: [.select, .start, .reset],
                                   binding: binding, padKind: padKind, orientation: orientation)
        var groups = base.groups
        let toggle = kit.actionPills([.keypad], startingAt: kit.pillRow([.select, .start, .reset], binding: binding).count)
        if let index = groups.firstIndex(where: { $0.id == "system" }) {
            groups[index].controls += toggle
        } else {
            groups.append(OverlayGroup(id: "system", controls: toggle,
                                       placement: OverlayPlacement(anchor: .bottomCenter,
                                                                   inset: CGPoint(x: 0, y: orientation == .landscape ? 12 : 20))))
        }
        groups.append(keypadGroup(binding: binding))
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: base.screenPolicy)
    }

    /// 3x4 grid of keys, 1-2-3 on top, floating at the top centre over the picture while shown.
    static func keypadGroup(binding: SystemOverlayBinding) -> OverlayGroup {
        let controls = OverlayFamilySlot.keypadKeys.enumerated().map { index, slot in
            OverlayControl(id: slot.rawValue, kind: .button(binding.inputID(slot)),
                           frame: CGRect(x: CGFloat(index % columns) * (keySize + keyGap),
                                         y: CGFloat(index / columns) * (keySize + keyGap),
                                         width: keySize, height: keySize),
                           label: binding.label(slot), shape: .key, paletteSlot: .utility)
        }
        return OverlayGroup(id: "keypad", controls: controls,
                            placement: OverlayPlacement(anchor: .topCenter, inset: CGPoint(x: 0, y: keypadTopInset)),
                            toggledBy: .keypad)
    }
}
