//
//  PointerCursor.swift
//  PVCoreBridge
//
//  The cursor a controller's touchpad or gyro moves, and how fast it moves.
//

import CoreGraphics
import Foundation

/// How far the cursor travels for a movement on the pad.
public struct PointerSpeedCurve: Equatable, Sendable {
    public static let speedRange: ClosedRange<Double> = 0.1...5.0
    public static let accelerationRange: ClosedRange<Double> = 0.0...1.0

    /// Screen widths crossed by one full sweep of the pad (2 pad units) at speed 1.
    private static let screensPerPadUnit = 0.5
    /// Finger speed, in pad units per second, at which acceleration reaches its full effect:
    /// a sweep of the whole pad in a quarter of a second.
    private static let fullBoostVelocity = 8.0
    /// The most a fast movement is multiplied by at acceleration 1.
    private static let maxBoost = 2.0

    /// Multiplier on every movement. At 1 a slow sweep of the whole pad crosses the screen once.
    public var speed: Double
    /// How much faster movements travel further, from 0 (not at all) to 1.
    public var acceleration: Double

    public init(speed: Double = 1.0, acceleration: Double = 0.3) {
        self.speed = min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        self.acceleration = min(max(acceleration, Self.accelerationRange.lowerBound), Self.accelerationRange.upperBound)
    }

    /// The cursor movement, as a fraction of the screen, for a pad movement made over `dt` seconds.
    ///
    /// Over the same distance a faster movement never travels less than a slower one.
    public func screenDelta(padDX: Double, padDY: Double, dt: TimeInterval) -> (dx: Double, dy: Double) {
        let gain = Self.screensPerPadUnit * speed * boost(padDX: padDX, padDY: padDY, dt: dt)
        return (padDX * gain, padDY * gain)
    }

    private func boost(padDX: Double, padDY: Double, dt: TimeInterval) -> Double {
        guard acceleration > 0, dt > 0 else { return 1 }
        let velocity = (padDX * padDX + padDY * padDY).squareRoot() / dt
        return 1 + acceleration * Self.maxBoost * min(velocity / Self.fullBoostVelocity, 1)
    }
}

/// A cursor position as a fraction of the emulated screen: (0, 0) top left, (1, 1) bottom right.
public struct PointerCursor: Equatable, Sendable {
    public static let centre = CGPoint(x: 0.5, y: 0.5)

    public private(set) var position: CGPoint

    public init(position: CGPoint = PointerCursor.centre) {
        self.position = Self.clamped(position)
    }

    /// Moves the cursor and returns the movement that fitted on the screen.
    @discardableResult
    public mutating func apply(dx: Double, dy: Double) -> CGPoint {
        let old = position
        position = Self.clamped(CGPoint(x: old.x + dx, y: old.y + dy))
        return CGPoint(x: position.x - old.x, y: position.y - old.y)
    }

    public mutating func set(_ newPosition: CGPoint) {
        position = Self.clamped(newPosition)
    }

    public mutating func recenter() {
        position = Self.centre
    }

    private static func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }
}
