//
//  ShakeDetector.swift
//  PVCoreBridge
//
//  Turns a pad's accelerometer into a held "shake" input.
//

import Foundation

/// Decides when a pad is being shaken, from its total acceleration in g.
///
/// Gravity is tracked with a low-pass filter, so a pad held still at any angle reads about
/// zero. A sample whose acceleration differs from gravity by `threshold` or more is strong.
/// The pad counts as shaking until `holdDuration` after the last strong sample, so a
/// continuous shake holds the input down through the moments the pad changes direction.
public struct ShakeDetector: Sendable {

    public struct Tuning: Equatable, Sendable {
        /// Seconds for the gravity estimate to follow a change of angle.
        public var gravityTimeConstant: TimeInterval
        /// g away from gravity that counts as a jolt.
        public var threshold: Double
        /// Seconds the shake stays held after the last jolt.
        public var holdDuration: TimeInterval

        public init(gravityTimeConstant: TimeInterval = 0.4, threshold: Double = 0.9,
                    holdDuration: TimeInterval = 0.15) {
            self.gravityTimeConstant = gravityTimeConstant
            self.threshold = threshold
            self.holdDuration = holdDuration
        }
    }

    public var tuning: Tuning
    public private(set) var isShaking = false

    private var gravity: SIMD3<Double>?
    private var lastSampleTime: TimeInterval = 0
    private var lastStrongTime: TimeInterval?

    public init(tuning: Tuning = Tuning()) {
        self.tuning = tuning
    }

    /// Takes one sample. Returns the new shake state when it changes, otherwise nil.
    /// The first sample only sets the gravity estimate.
    public mutating func update(acceleration: SIMD3<Double>, at time: TimeInterval) -> Bool? {
        guard let previous = gravity else {
            gravity = acceleration
            lastSampleTime = time
            return nil
        }
        let elapsed = max(0, time - lastSampleTime)
        lastSampleTime = time

        let jolt = acceleration - previous
        if (jolt * jolt).sum().squareRoot() >= tuning.threshold {
            lastStrongTime = time
        }
        /// Follow gravity after measuring against it, so the jolt itself is not absorbed first.
        let blend = elapsed / (tuning.gravityTimeConstant + elapsed)
        gravity = previous + (acceleration - previous) * blend

        let shaking = lastStrongTime.map { time - $0 < tuning.holdDuration } ?? false
        guard shaking != isShaking else { return nil }
        isShaking = shaking
        return shaking
    }

    /// Forgets everything. Returns `false` if the pad was shaking, so the caller can let go.
    public mutating func reset() -> Bool? {
        let wasShaking = isShaking
        isShaking = false
        gravity = nil
        lastStrongTime = nil
        return wasShaking ? false : nil
    }
}

/// Combines the shake of several players who share one emulated controller port.
///
/// The port's shake input is held while any of them is shaking, and let go when the last one stops.
public struct SharedShakeState: Sendable {
    private var shakingPlayers: [Int: Set<Int>] = [:]

    public init() {}

    /// Records `player`'s shake on `port`. Returns the port's new state when it changes, otherwise nil.
    public mutating func set(_ shaking: Bool, player: Int, port: Int) -> Bool? {
        var players = shakingPlayers[port] ?? []
        let wasHeld = !players.isEmpty
        if shaking { players.insert(player) } else { players.remove(player) }
        shakingPlayers[port] = players.isEmpty ? nil : players
        let isHeld = !players.isEmpty
        return isHeld == wasHeld ? nil : isHeld
    }
}
