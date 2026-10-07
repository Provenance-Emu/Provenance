import Foundation
import CoreGraphics

/// A centre point stored relative to the nearest canvas edge (or the centre line
/// when the point lies in the middle third), so it survives device changes.
public struct AnchoredCenter: Hashable, Codable, Sendable {
    public enum Edge: String, Codable, Sendable { case min, mid, max }
    public var h: Edge
    public var x: CGFloat
    public var v: Edge
    public var y: CGFloat

    public init(h: Edge, x: CGFloat, v: Edge, y: CGFloat) { self.h = h; self.x = x; self.v = v; self.y = y }

    public static func make(center: CGPoint, in canvas: OverlayCanvas) -> AnchoredCenter {
        func anchor(_ value: CGFloat, length: CGFloat) -> (Edge, CGFloat) {
            let third = length / 3
            if value < third { return (.min, value) }
            if value > 2 * third { return (.max, length - value) }
            return (.mid, value - length / 2)
        }
        let (h, x) = anchor(center.x, length: canvas.size.width)
        let (v, y) = anchor(center.y, length: canvas.size.height)
        return AnchoredCenter(h: h, x: x, v: v, y: y)
    }

    public func resolve(in canvas: OverlayCanvas) -> CGPoint {
        func value(_ edge: Edge, _ distance: CGFloat, length: CGFloat) -> CGFloat {
            switch edge {
            case .min: return distance
            case .max: return length - distance
            case .mid: return length / 2 + distance
            }
        }
        return CGPoint(x: value(h, x, length: canvas.size.width), y: value(v, y, length: canvas.size.height))
    }
}

public struct ControlOverride: Hashable, Codable, Sendable {
    public var offset: CGPoint
    public var scale: CGFloat
    public init(offset: CGPoint = .zero, scale: CGFloat = 1) { self.offset = offset; self.scale = scale }
}

public struct GroupOverride: Hashable, Codable, Sendable {
    public var center: AnchoredCenter?
    public var scale: CGSize?
    public var opacity: CGFloat?
    public var buttons: [String: ControlOverride]
    public init(center: AnchoredCenter?, scale: CGSize?, opacity: CGFloat?, buttons: [String: ControlOverride]) {
        self.center = center; self.scale = scale; self.opacity = opacity; self.buttons = buttons
    }
    public static let empty = GroupOverride(center: nil, scale: nil, opacity: nil, buttons: [:])
}

public struct OverlayLayoutOverrides: Hashable, Codable, Sendable {
    public var groups: [String: GroupOverride]
    public init(groups: [String: GroupOverride] = [:]) { self.groups = groups }
    public static let empty = OverlayLayoutOverrides()
}
