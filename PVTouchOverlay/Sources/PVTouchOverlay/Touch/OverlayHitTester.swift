import Foundation
import CoreGraphics

public enum OverlayDPadDirection: Hashable, Sendable, CaseIterable { case up, down, left, right }

public enum OverlayHit: Hashable, Sendable {
    case control(id: String)
    case dpad(id: String, OverlayDPadDirection)
}

public enum OverlayHitTester {
    public static let deadZoneFraction: CGFloat = 0.18
    public static let hysteresisDegrees: CGFloat = 8

    private static let octantWidth: CGFloat = 45
    private static let octantCount = 8

    public static func hits(at points: [CGPoint], controls: [ResolvedControl],
                            previousDPad: [String: Set<OverlayDPadDirection>]) -> Set<OverlayHit> {
        var result = Set<OverlayHit>()
        for point in points {
            guard let target = topControl(at: point, in: controls) else { continue }
            if case .dpad = target.control.kind {
                let directions = dpadDirections(point: point, in: target.frame,
                                                previous: previousDPad[target.id] ?? [])
                for direction in directions { result.insert(.dpad(id: target.id, direction)) }
            } else {
                result.insert(.control(id: target.id))
            }
        }
        return result
    }

    /// A finger inside a draw frame wins; otherwise the nearest centre among hit frames.
    public static func topControl(at point: CGPoint, in controls: [ResolvedControl]) -> ResolvedControl? {
        if let inside = controls.first(where: { $0.frame.contains(point) }) { return inside }
        return controls.filter { $0.hitFrame.contains(point) }
            .min { distance(point, $0.frame.center) < distance(point, $1.frame.center) }
    }

    public static func dpadDirections(point: CGPoint, in frame: CGRect,
                                      previous: Set<OverlayDPadDirection>) -> Set<OverlayDPadDirection> {
        let deltaX = point.x - frame.midX
        let deltaY = point.y - frame.midY
        let radius = min(frame.width, frame.height) / 2
        guard hypot(deltaX, deltaY) > radius * deadZoneFraction else { return [] }
        // 0 degrees = up, clockwise.
        var degrees = atan2(deltaX, -deltaY) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        let current = octant(containing: degrees)
        if let held = octantIndex(of: previous), held != current {
            // Stay on the previous octant while within hysteresis of its edge.
            var offset = abs(degrees - CGFloat(held) * octantWidth)
            if offset > 180 { offset = 360 - offset }
            if offset <= octantWidth / 2 + hysteresisDegrees { return directions(forOctant: held) }
        }
        return directions(forOctant: current)
    }

    /// Octants are 45 degrees wide, centred on 0, 45, 90, and so on.
    private static func octant(containing degrees: CGFloat) -> Int {
        Int(((degrees + octantWidth / 2).truncatingRemainder(dividingBy: 360)) / octantWidth) % octantCount
    }

    static func directions(forOctant octant: Int) -> Set<OverlayDPadDirection> {
        switch octant {
        case 0: return [.up]
        case 1: return [.up, .right]
        case 2: return [.right]
        case 3: return [.down, .right]
        case 4: return [.down]
        case 5: return [.down, .left]
        case 6: return [.left]
        default: return [.up, .left]
        }
    }

    static func octantIndex(of directions: Set<OverlayDPadDirection>) -> Int? {
        (0..<octantCount).first { Self.directions(forOctant: $0) == directions }
    }

    static func distance(_ from: CGPoint, _ to: CGPoint) -> CGFloat { hypot(from.x - to.x, from.y - to.y) }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
