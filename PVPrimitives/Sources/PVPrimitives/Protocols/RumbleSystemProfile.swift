//
//  RumbleSystemProfile.swift
//  PVPrimitives
//
//  Per-system haptic tuning profiles — maps original rumble hardware characteristics
//  to iOS/tvOS CoreHaptics parameters.
//  Foundation-only — safe to use in Tier 2 modules.
//

import Foundation

// MARK: - RumbleSystemProfile

/// Haptic tuning profile for a specific game system's rumble hardware.
///
/// Different systems use fundamentally different rumble actuators:
/// - N64 Rumble Pak: ~120 Hz ERM, binary on/off, single heavy motor
/// - PSX DualShock: large (low-freq) + small (high-freq) ERM motors
/// - GBA cartridge: small pager motor, very high frequency, sharp
/// - Switch HD Rumble: LRA with precise frequency + amplitude control
///
/// These profiles tune CoreHaptics parameters to approximate the
/// original motor characteristics on modern haptic actuators.
public struct RumbleSystemProfile: Codable, Sendable {

    // MARK: Properties

    /// Hardware rumble classification for this system.
    public let rumbleType: RumbleType

    /// Scale factor applied to the low-frequency (heavy) motor intensity [0, 1].
    public let lowFrequencyScale: Float

    /// Scale factor applied to the high-frequency (buzz) motor intensity [0, 1].
    public let highFrequencyScale: Float

    /// Perceptual sharpness of the haptic [0 = soft/dull thump, 1 = sharp/precise buzz].
    /// N64 ERM ≈ 0.1 (heavy thud); GBA pager motor ≈ 0.85 (sharp buzz).
    public let sharpness: Float

    /// Minimum burst duration to treat as a meaningful event.
    /// Bursts shorter than this are suppressed as noise.
    public let minBurstDuration: TimeInterval

    // MARK: Init

    public init(
        rumbleType: RumbleType,
        lowFrequencyScale: Float,
        highFrequencyScale: Float,
        sharpness: Float,
        minBurstDuration: TimeInterval = 0.03
    ) {
        self.rumbleType = rumbleType
        self.lowFrequencyScale = min(1, max(0, lowFrequencyScale))
        self.highFrequencyScale = min(1, max(0, highFrequencyScale))
        self.sharpness = min(1, max(0, sharpness))
        self.minBurstDuration = max(0, minBurstDuration)
    }
}

// MARK: - Built-in Presets

public extension RumbleSystemProfile {

    // MARK: N64

    /// N64 Rumble Pak — single eccentric rotating mass (ERM), ~120 Hz, binary on/off.
    /// Heavy, low-frequency, dull thump.
    public static let n64RumblePak = RumbleSystemProfile(
        rumbleType: .rumblePak,
        lowFrequencyScale: 1.0,
        highFrequencyScale: 0.2,
        sharpness: 0.1
    )

    // MARK: PlayStation

    /// PSX / PS2 DualShock — large (low-freq) + small (high-freq) ERM motors.
    public static let psxDualShock = RumbleSystemProfile(
        rumbleType: .dualMotor,
        lowFrequencyScale: 1.0,
        highFrequencyScale: 0.8,
        sharpness: 0.4
    )

    /// PS3 DualShock 3 / Sixaxis — similar to PSX but slightly softer.
    public static let ps3DualShock3 = RumbleSystemProfile(
        rumbleType: .dualMotor,
        lowFrequencyScale: 0.9,
        highFrequencyScale: 0.75,
        sharpness: 0.45
    )

    // MARK: GBA

    /// GBA cartridge motor — Drill Dozer, Pokémon Pinball R/S, Wario Land 4.
    /// Tiny pager motor: very sharp, high-frequency buzz.
    public static let gbaCartridgeMotor = RumbleSystemProfile(
        rumbleType: .singleMotor,
        lowFrequencyScale: 0.5,
        highFrequencyScale: 0.95,
        sharpness: 0.85,
        minBurstDuration: 0.02
    )

    // MARK: SNES

    /// SNES cartridge motor (extremely rare, prototype hardware only).
    public static let snesCartridgeMotor = RumbleSystemProfile(
        rumbleType: .singleMotor,
        lowFrequencyScale: 0.5,
        highFrequencyScale: 0.9,
        sharpness: 0.8,
        minBurstDuration: 0.03
    )

    // MARK: GameCube / Wii

    /// GameCube controller — single ERM, moderate frequency.
    public static let gamecubeSingle = RumbleSystemProfile(
        rumbleType: .singleMotor,
        lowFrequencyScale: 0.8,
        highFrequencyScale: 0.4,
        sharpness: 0.3
    )

    // MARK: Switch

    /// Nintendo Switch HD Rumble — linear resonant actuator (LRA), frequency + amplitude.
    public static let switchHDRumble = RumbleSystemProfile(
        rumbleType: .hdRumble,
        lowFrequencyScale: 0.7,
        highFrequencyScale: 0.7,
        sharpness: 0.5
    )

    // MARK: Xbox / Generic Dual-Motor

    /// Xbox 360 / Xbox One / Xbox Series — dual ERM motors.
    public static let xboxDualMotor = RumbleSystemProfile(
        rumbleType: .dualMotor,
        lowFrequencyScale: 0.9,
        highFrequencyScale: 0.7,
        sharpness: 0.4
    )

    /// Generic dual-motor fallback.
    public static let genericDualMotor = RumbleSystemProfile(
        rumbleType: .dualMotor,
        lowFrequencyScale: 0.85,
        highFrequencyScale: 0.65,
        sharpness: 0.4
    )

    /// Fully generic fallback for unknown systems.
    public static let generic = RumbleSystemProfile(
        rumbleType: .singleMotor,
        lowFrequencyScale: 0.8,
        highFrequencyScale: 0.6,
        sharpness: 0.5
    )

    // MARK: - System ID Lookup

    /// Return the best-matching haptic profile for a Provenance system identifier.
    ///
    /// - Parameter systemId: Provenance system identifier string (e.g. `"com.provenance.n64"`).
    public static func profile(forSystemIdentifier systemId: String) -> RumbleSystemProfile {
        let id = systemId.lowercased()

        // Nintendo 64
        if id.contains("n64") || id.contains("nintendo64") { return .n64RumblePak }

        // PlayStation (check PS3 before generic PSX to avoid prefix match)
        if id.contains("ps3") || id.contains("playstation3") { return .ps3DualShock3 }
        if id.contains("psx") || id.contains("ps1") || id.contains("ps2")
            || id.contains("playstation") { return .psxDualShock }

        // GBA
        if id.contains("gba") || id.contains("gameboyadvance") { return .gbaCartridgeMotor }

        // SNES
        if id.contains("snes") || id.contains("superfamicom") { return .snesCartridgeMotor }

        // GameCube / Wii
        if id.contains("gamecube") || id.contains(".gc") || id.contains("wii") { return .gamecubeSingle }

        // Switch
        if id.contains("switch") { return .switchHDRumble }

        // Xbox
        if id.contains("xbox") { return .xboxDualMotor }

        return .generic
    }
}
