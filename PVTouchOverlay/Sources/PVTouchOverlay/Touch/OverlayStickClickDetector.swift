import Foundation
import CoreGraphics

/// Recognises a tap on a stick as a stick click (L3/R3): the touch ends within
/// `maxTapDuration` of beginning and never travels `maxTravelFraction` of the stick radius
/// from where it began. Positions are in points; times are seconds on any monotonic clock.
public struct OverlayStickClickDetector: Sendable {
    public static let maxTapDuration: TimeInterval = 0.25
    public static let maxTravelFraction: CGFloat = 0.1

    private let maxTravel: CGFloat
    private var start: CGPoint?
    private var startTime: TimeInterval = 0
    private var travelled: CGFloat = 0

    public init(radius: CGFloat) {
        maxTravel = radius * Self.maxTravelFraction
    }

    public mutating func began(at point: CGPoint, time: TimeInterval) {
        start = point
        startTime = time
        travelled = 0
    }

    public mutating func moved(to point: CGPoint) {
        guard let start else { return }
        travelled = max(travelled, hypot(point.x - start.x, point.y - start.y))
    }

    /// Whether the gesture that just ended was a click. Clears the gesture either way.
    public mutating func ended(at time: TimeInterval) -> Bool {
        defer { start = nil }
        guard start != nil else { return false }
        return time - startTime <= Self.maxTapDuration && travelled < maxTravel
    }
}
