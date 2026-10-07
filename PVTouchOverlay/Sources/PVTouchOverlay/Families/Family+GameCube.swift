import Foundation

public enum GameCubeFamily: OverlayFamily {
    public static let id = "gameCube"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .z, .l, .r, .start]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                                orientation: OverlayOrientation) -> OverlayTemplate {
        let kit = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let lower = landscape ? 12 : kit.portraitBottom
        let upper = kit.portraitBottom + 110
        let zOrigin = CGPoint(x: 0, y: kit.shoulderSize.height + 8)
        let triggerInset = CGPoint(x: kit.edge, y: landscape ? 12 : kit.portraitBottom + 270)
        let groups: [OverlayGroup] = [
            OverlayGroup(id: "leftStick", controls: [kit.stick(.left)],
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: kit.edge + 8, y: upper))),
            OverlayGroup(id: "dpad", controls: [kit.dpad(binding: binding, size: 100)],
                         placement: OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: kit.edge, y: lower))),
            OverlayGroup(id: "face", controls: faceButtons(binding: binding),
                         placement: landscape
                            ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: kit.edge, y: 0))
                            : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: kit.edge, y: upper))),
            OverlayGroup(id: "rightStick", controls: [kit.stick(.right, size: 90)],
                         placement: OverlayPlacement(anchor: .bottomTrailing,
                                                     inset: CGPoint(x: kit.edge + 20, y: lower))),
            OverlayGroup(id: "shoulder-l", controls: [kit.shoulder(.l, binding: binding, analog: true)],
                         placement: OverlayPlacement(anchor: landscape ? .topLeading : .bottomLeading,
                                                     inset: triggerInset)),
            OverlayGroup(id: "shoulder-r",
                         controls: [kit.shoulder(.r, binding: binding, analog: true),
                                    kit.shoulder(.z, binding: binding, at: zOrigin)],
                         placement: OverlayPlacement(anchor: landscape ? .topTrailing : .bottomTrailing,
                                                     inset: triggerInset)),
            OverlayGroup(id: "system", controls: kit.pillRow([.start], binding: binding),
                         placement: OverlayPlacement(anchor: .bottomCenter,
                                                     inset: CGPoint(x: 0, y: landscape ? 12 : 20)))
        ]
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }

    /// Big green A centre, red B lower-left, X kidney right, Y kidney top.
    private static func faceButtons(binding: SystemOverlayBinding) -> [OverlayControl] {
        let kit = OverlayFamilyKit.self
        let big: CGFloat = 72, small: CGFloat = 44
        return [
            kit.button(.a, binding: binding, at: CGPoint(x: 52, y: 52), size: big, palette: .primary),
            kit.button(.b, binding: binding, at: CGPoint(x: 0, y: 100), size: small, palette: .secondary),
            kit.button(.x, binding: binding, at: CGPoint(x: 130, y: 44), size: small,
                       shape: .kidney, palette: .utility),
            kit.button(.y, binding: binding, at: CGPoint(x: 60, y: 0), size: small,
                       shape: .kidney, palette: .utility)
        ]
    }
}
