import Foundation
import CoreGraphics

public struct OverlayPlacement: Hashable, Codable, Sendable {
    public enum Anchor: String, Codable, Sendable, Hashable {
        case bottomLeading, bottomTrailing, bottomCenter
        case topLeading, topTrailing, topCenter
        case centerLeading, centerTrailing, center
        case fill, fillInset
    }
    public var anchor: Anchor
    /// Distance from the anchored edges in points. For center anchors the matching component is ignored.
    public var inset: CGPoint
    public init(anchor: Anchor, inset: CGPoint = .zero) { self.anchor = anchor; self.inset = inset }
}

public struct OverlayGroup: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var controls: [OverlayControl]
    public var placement: OverlayPlacement
    public var scale: CGFloat
    public var opacity: CGFloat

    public init(id: String, controls: [OverlayControl], placement: OverlayPlacement,
                scale: CGFloat = 1, opacity: CGFloat = 1) {
        self.id = id; self.controls = controls; self.placement = placement
        self.scale = scale; self.opacity = opacity
    }

    /// Union of control frames at reference scale, origin-normalised to (0,0).
    public var naturalSize: CGSize {
        let union = controls.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        return union.isNull ? .zero : CGSize(width: union.maxX, height: union.maxY)
    }
}
