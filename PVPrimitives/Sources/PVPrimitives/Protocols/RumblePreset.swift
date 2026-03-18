//
//  RumblePreset.swift
//  PVPrimitives
//
//  A user-visible, named, shareable rumble profile preset.
//  Foundation-only — Tier 2 safe.
//

import Foundation

// MARK: - RumblePreset

/// A named, shareable rumble profile that wraps `RumbleSystemProfile` parameters.
///
/// Users can create custom presets, tune them via the UI, export them as JSON for
/// sharing (e.g. via AirDrop, iMessage, or iCloud), and import presets received from others.
///
/// The `id` is stable across encode/decode so Identifiable conformance works correctly
/// in SwiftUI lists.
public struct RumblePreset: Codable, Identifiable, Sendable, Hashable {

    // MARK: Properties

    /// Stable identifier — preserved through encode/decode.
    public let id: UUID

    /// User-visible name, e.g. "N64 Extra Heavy".
    public var name: String

    /// Low-frequency (heavy) motor scale [0, 1].
    public var lowFrequencyScale: Float

    /// High-frequency (buzz) motor scale [0, 1].
    public var highFrequencyScale: Float

    /// Perceptual sharpness [0 = soft/dull thump, 1 = sharp/precise buzz].
    public var sharpness: Float

    /// Minimum burst duration (seconds). Bursts shorter than this are suppressed.
    public var minBurstDuration: TimeInterval

    /// Schema version for forward-compatibility.
    public let version: Int

    // MARK: Init

    public init(
        id: UUID = UUID(),
        name: String,
        lowFrequencyScale: Float = 0.8,
        highFrequencyScale: Float = 0.6,
        sharpness: Float = 0.5,
        minBurstDuration: TimeInterval = 0.03
    ) {
        self.id = id
        self.name = name
        self.lowFrequencyScale = min(1, max(0, lowFrequencyScale))
        self.highFrequencyScale = min(1, max(0, highFrequencyScale))
        self.sharpness = min(1, max(0, sharpness))
        self.minBurstDuration = max(0, minBurstDuration)
        self.version = 1
    }

    // MARK: Codable (custom key names for share format)

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case lowFrequencyScale
        case highFrequencyScale
        case sharpness
        case minBurstDuration
    }
}

// MARK: - Conversion to/from RumbleSystemProfile

public extension RumblePreset {

    /// Create a preset from an existing `RumbleSystemProfile`.
    init(name: String, profile: RumbleSystemProfile) {
        self.init(
            name: name,
            lowFrequencyScale: profile.lowFrequencyScale,
            highFrequencyScale: profile.highFrequencyScale,
            sharpness: profile.sharpness,
            minBurstDuration: profile.minBurstDuration
        )
    }

    /// Convert to a `RumbleSystemProfile` using `.singleMotor` as a generic rumble type.
    func toSystemProfile(rumbleType: RumbleType = .singleMotor) -> RumbleSystemProfile {
        RumbleSystemProfile(
            rumbleType: rumbleType,
            lowFrequencyScale: lowFrequencyScale,
            highFrequencyScale: highFrequencyScale,
            sharpness: sharpness,
            minBurstDuration: minBurstDuration
        )
    }
}

// MARK: - JSON Share/Import Helpers

public extension RumblePreset {

    /// Encode this preset to a JSON `Data` for sharing (share sheet, iCloud, etc.).
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decode a preset from JSON `Data` received from another user.
    ///
    /// The original `id` is preserved so the same preset imported twice has the same UUID.
    /// Call `reidentified()` on the result if you need a fresh UUID (e.g. to avoid collisions
    /// when importing a preset that might already exist in the store).
    static func from(jsonData data: Data) throws -> RumblePreset {
        try JSONDecoder().decode(RumblePreset.self, from: data)
    }

    /// Return a copy of this preset with a brand-new UUID (safe to store alongside existing presets).
    func reidentified() -> RumblePreset {
        RumblePreset(
            id: UUID(),
            name: name,
            lowFrequencyScale: lowFrequencyScale,
            highFrequencyScale: highFrequencyScale,
            sharpness: sharpness,
            minBurstDuration: minBurstDuration
        )
    }
}

// MARK: - Built-in Presets

public extension RumblePreset {

    /// Convert a `RumbleSystemProfile` built-in preset to a display preset (no storage, ID is fixed).
    private static func builtIn(name: String, profile: RumbleSystemProfile) -> RumblePreset {
        RumblePreset(name: name, profile: profile)
    }

    /// All built-in system presets in display order.
    static let builtIns: [RumblePreset] = [
        .init(name: "Generic",             profile: .generic),
        .init(name: "N64 Rumble Pak",       profile: .n64RumblePak),
        .init(name: "PSX DualShock",        profile: .psxDualShock),
        .init(name: "PS3 DualShock 3",      profile: .ps3DualShock3),
        .init(name: "GBA Cartridge Motor",  profile: .gbaCartridgeMotor),
        .init(name: "GameCube",             profile: .gamecubeSingle),
        .init(name: "Switch HD Rumble",     profile: .switchHDRumble),
        .init(name: "Xbox Dual Motor",      profile: .xboxDualMotor),
    ]
}
