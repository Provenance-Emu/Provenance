import Foundation

/// A single fire button and a horizontal slider that reports the stick's x axis only.
public enum PaddleFamily: OverlayFamily {
    public static let id = "paddle"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .start, .select]

    public static let sliderSize = CGSize(width: 200, height: 56)

    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let slider = OverlayControl(id: "leftStick", kind: .stick(.left, click: nil),
                                    frame: CGRect(origin: .zero, size: sliderSize),
                                    shape: .pill, paletteSlot: .stick, axis: .horizontal)
        let sliderPlacement = landscape
            ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: kit.edge, y: 0))
            : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: kit.edge, y: kit.portraitBottom))
        let facePlacement = landscape
            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: kit.edge, y: 0))
            : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: kit.edge, y: kit.portraitBottom))
        var groups = [
            OverlayGroup(id: "paddle", controls: [slider], placement: sliderPlacement),
            OverlayGroup(id: "face",
                         controls: [kit.button(.a, binding: binding, at: .zero, palette: .primary),
                                    kit.button(.b, binding: binding, at: CGPoint(x: kit.faceButton + 12, y: 0),
                                               palette: .secondary)],
                         placement: facePlacement)
        ]
        let pills = kit.pillRow([.select, .start], binding: binding)
        if !pills.isEmpty {
            groups.append(OverlayGroup(id: "system", controls: pills,
                                       placement: OverlayPlacement(anchor: .bottomCenter,
                                                                   inset: CGPoint(x: 0, y: landscape ? 12 : 20))))
        }
        if let actions = kit.actionsGroup(binding: binding) { groups.append(actions) }
        if let switches = kit.switchesGroup(binding: binding, orientation: orientation) { groups.append(switches) }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }
}
