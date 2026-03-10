//
//  PVRumbleProtocol.swift
//  PVPrimitives
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - Rumble Type

/// Describes the rumble hardware model a system uses.
/// Used for mapping emulator rumble output to the appropriate physical actuator pattern.
public enum RumbleType: Int, Codable, Sendable, CaseIterable {
    /// No rumble support.
    case none
    /// N64-style Rumble Pak: single eccentric-mass motor, on/off.
    case rumblePak
    /// PSX DualShock style: two independent motors (large low-freq, small high-freq).
    case dualMotor
    /// Single motor in a cartridge (e.g., GBA Drill Dozer, Pokemon Pinball).
    case singleMotor
    /// Switch HD Rumble: linear resonant actuator with frequency + amplitude control.
    case hdRumble
}

// MARK: - Rumble Locality

/// Describes which haptic actuators should receive a rumble event.
/// Platform-agnostic mirror of `GCHapticsLocality` — concrete implementations
/// map these to `GCHapticsLocality` values at the `GameController` layer.
public enum RumbleLocality: Int, Codable, Sendable, CaseIterable {
    /// All available actuators on the device or controller.
    case all
    /// Default actuator (device Taptic Engine, or controller's primary motor).
    case `default`
    /// Left handle motor (e.g., DualSense L, Xbox Series L).
    case leftHandle
    /// Right handle motor (e.g., DualSense R, Xbox Series R).
    case rightHandle
    /// Left trigger motor (e.g., Xbox Series left trigger).
    case leftTrigger
    /// Right trigger motor (e.g., Xbox Series right trigger).
    case rightTrigger
    /// Handgrip actuators (both handles together).
    case handles
    /// Trigger actuators (both triggers together).
    case triggers
}

// MARK: - Rumble Event

/// A single rumble event describing intensity and duration.
public struct RumbleEvent: Sendable {
    /// Low-frequency (heavy, rumble) motor intensity in the range [0, 1].
    public let lowFrequency: Float
    /// High-frequency (buzz, vibration) motor intensity in the range [0, 1].
    public let highFrequency: Float
    /// Duration in seconds. Pass `0` to stop ongoing rumble immediately.
    public let duration: TimeInterval
    /// Which actuator locality to target. Defaults to `.default`.
    public let locality: RumbleLocality

    public init(
        lowFrequency: Float,
        highFrequency: Float,
        duration: TimeInterval,
        locality: RumbleLocality = .default
    ) {
        self.lowFrequency = lowFrequency.clamped(to: 0...1)
        self.highFrequency = highFrequency.clamped(to: 0...1)
        self.duration = max(0, duration)
        self.locality = locality
    }

    /// Convenience: a stopped event (all intensities zero).
    public static let stop = RumbleEvent(lowFrequency: 0, highFrequency: 0, duration: 0)
}

// MARK: - Protocol

/// Platform-agnostic protocol for delivering rumble/haptic feedback from emulator cores.
///
/// Conforming types are responsible for routing rumble events to whichever
/// physical actuators are available (device Taptic Engine, external controller
/// motors via `GCDeviceHaptics`, etc.). This protocol intentionally imports
/// only Foundation so it can be defined in `PVPrimitives` (Tier 2) without
/// pulling in `GameController`, `CoreHaptics`, or `UIKit`.
///
/// Typical usage from a core bridge:
/// ```swift
/// PVHapticsManager.shared.rumble(
///     RumbleEvent(lowFrequency: 0.8, highFrequency: 0.4, duration: 0.5)
/// )
/// ```
public protocol PVRumbleProtocol: AnyObject {

    /// Whether rumble output is currently enabled.
    var isRumbleEnabled: Bool { get set }

    /// Global intensity multiplier applied to all rumble output, in the range [0, 1].
    var rumbleIntensity: Float { get set }

    /// Fire a rumble event for the specified player.
    /// - Parameters:
    ///   - event: The rumble event describing intensities, duration, and locality.
    ///   - player: Zero-based player index. Defaults to 0.
    func rumble(_ event: RumbleEvent, player: Int)

    /// Immediately stop all ongoing rumble for the specified player.
    /// - Parameter player: Zero-based player index. Pass `nil` to stop all players.
    func stopRumble(player: Int?)

    /// Notify the manager that a new controller connected for the given player.
    /// Implementations should refresh their haptic engine for that slot.
    func controllerDidConnect(player: Int)

    /// Notify the manager that the controller for the given player disconnected.
    func controllerDidDisconnect(player: Int)
}

// MARK: - Default Implementations

public extension PVRumbleProtocol {
    /// Fire a rumble event for player 0.
    func rumble(_ event: RumbleEvent) {
        rumble(event, player: 0)
    }

    /// Convenience wrapper mapping separate low/high frequency values and duration.
    func rumble(
        lowFrequency: Float,
        highFrequency: Float,
        duration: TimeInterval,
        player: Int = 0,
        locality: RumbleLocality = .default
    ) {
        rumble(
            RumbleEvent(
                lowFrequency: lowFrequency,
                highFrequency: highFrequency,
                duration: duration,
                locality: locality
            ),
            player: player
        )
    }

    /// Stop all rumble for all players.
    func stopAllRumble() {
        stopRumble(player: nil)
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
