//
//  GyroPointerFilter.swift
//  PVCoreBridge
//
//  Turns a pad's rotation rate into pointer movement.
//

import Foundation

/// Converts gyro rotation (rad/s) into a cursor movement in fractions of the screen.
///
/// Turning the pad left or right (yaw) moves the cursor across, tilting its top up or down
/// (pitch) moves it up or down. Rotation slower than the dead zone is ignored, and the
/// dead zone is subtracted from faster rotation, so movement starts from zero instead of jumping.
public struct GyroPointerFilter: Equatable, Sendable {
    /// Screen widths the cursor crosses per radian turned at sensitivity 1: about 40 degrees across.
    static let screensPerRadian = 1.4
    public static let sensitivityRange: ClosedRange<Double> = 0.1...5.0
    public static let deadZoneRange: ClosedRange<Double> = 0.0...0.5

    public var sensitivity: Double
    /// Rotation, in rad/s, below which the pad counts as still.
    public var deadZone: Double
    public var invertX: Bool
    public var invertY: Bool

    public init(sensitivity: Double = 1.0, deadZone: Double = 0.05, invertX: Bool = false, invertY: Bool = false) {
        self.sensitivity = sensitivity.clamped(to: Self.sensitivityRange)
        self.deadZone = deadZone.clamped(to: Self.deadZoneRange)
        self.invertX = invertX
        self.invertY = invertY
    }

    /// The cursor movement for `dt` seconds of rotation. `yawRate` is positive turning right,
    /// `pitchRate` positive tilting the top up; the result's +y is down the screen.
    public func screenDelta(yawRate: Double, pitchRate: Double, dt: TimeInterval) -> CGPoint {
        guard dt > 0 else { return .zero }
        let scale = Self.screensPerRadian * sensitivity * dt
        let dx = afterDeadZone(yawRate) * scale * (invertX ? -1 : 1)
        let dy = -afterDeadZone(pitchRate) * scale * (invertY ? -1 : 1)
        return CGPoint(x: dx, y: dy)
    }

    private func afterDeadZone(_ rate: Double) -> Double {
        let magnitude = abs(rate) - deadZone
        return magnitude > 0 ? magnitude * (rate < 0 ? -1 : 1) : 0
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
