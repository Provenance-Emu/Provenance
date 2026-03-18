//
//  RumbleBurstClassifier.swift
//  PVPrimitives
//
//  Classifies rumble burst timing into human-perceptible haptic pattern categories.
//  Foundation-only — safe to use in Tier 2 modules.
//

import Foundation

// MARK: - RumblePattern

/// Categories of rumble burst derived from on/off timing analysis.
///
/// Emulator cores often expose rumble as binary on/off (e.g. N64 RumblePak, GBA cart motor).
/// By tracking burst duration and pulse frequency, we can select haptic parameters that
/// better match the *intent* of the original rumble hardware, even without variable intensity.
public enum RumblePattern: Equatable, Sendable, CaseIterable {

    /// Very short sharp impact — burst < 80 ms.
    /// Examples: bullet hit, jump landing, item pickup.
    /// Maps to: high-sharpness transient, brief high-frequency buzz.
    case shortTransient

    /// Mid-length burst — 80–250 ms.
    /// Examples: explosion, grenade blast, collect item with feedback.
    /// Maps to: medium intensity, balanced low/high frequency.
    case mediumBurst

    /// Long sustained vibration — > 250 ms.
    /// Examples: driving, Blast Corps machinery, engine noise.
    /// Maps to: low-frequency continuous, low sharpness.
    case longSustained

    /// Three or more rapid on/off cycles within a 500 ms window.
    /// Examples: rapid weapon fire, mechanical chatter, spinning parts.
    /// Maps to: series of transient events (rattling feel).
    case rapidPulse
}

// MARK: - RumbleBurstClassifier

/// Pure, stateless classifier for rumble burst timing patterns.
/// Foundation-only; safe to use in Tier 2 modules (PVPrimitives).
public struct RumbleBurstClassifier: Sendable {

    /// Classify a rumble pattern based on burst timing data.
    ///
    /// - Parameters:
    ///   - duration: Duration in seconds of the current burst (time from ON to OFF).
    ///   - pulseCount: Number of on/off cycles observed within `windowDuration`.
    ///   - windowDuration: Time span (seconds) over which `pulseCount` was measured.
    /// - Returns: The most appropriate `RumblePattern` for the given timing.
    public static func classify(
        duration: TimeInterval,
        pulseCount: Int = 1,
        windowDuration: TimeInterval = 1.0
    ) -> RumblePattern {
        if pulseCount >= 3 && windowDuration <= 0.5 {
            return .rapidPulse
        }
        switch duration {
        case ..<0.08:
            return .shortTransient
        case 0.08..<0.25:
            return .mediumBurst
        default:
            return .longSustained
        }
    }
}
