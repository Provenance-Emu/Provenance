//
//  LightGunGameSettings.swift
//  PVSettings
//
//  Per-game light gun override settings.
//  Stored in `Defaults` keyed by game MD5 hash.
//

import Foundation
@_exported import Defaults

// MARK: - LightGunMode

/// Per-game control over whether light gun input is active.
public enum LightGunMode: String, Codable, Equatable, Defaults.Serializable,
    CaseIterable, Sendable {

    /// Follow the system-level auto-detect logic (default).
    case automatic

    /// Force light gun input on for this game regardless of auto-detect.
    case enabled

    /// Force light gun input off for this game regardless of auto-detect.
    case disabled

    // MARK: Display

    public var displayTitle: String {
        switch self {
        case .automatic: return "Automatic"
        case .enabled:   return "Enabled"
        case .disabled:  return "Disabled"
        }
    }

    public var displayDescription: String {
        switch self {
        case .automatic:
            return "Auto-detect light gun support for this game"
        case .enabled:
            return "Always activate light gun input for this game"
        case .disabled:
            return "Never activate light gun input for this game"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .automatic: return "gearshape"
        case .enabled:   return "scope"
        case .disabled:  return "nosign"
        }
    }
}

// MARK: - LightGunGameSettings

/// Per-game light gun preferences stored as a single value in `Defaults`.
///
/// Only games with non-default values are stored — `nil` entries are
/// pruned to keep the dictionary compact.
public struct LightGunGameSettings: Codable, Equatable, Defaults.Serializable, Sendable {

    /// Whether light gun input is forced on, off, or left to auto-detect.
    public var mode: LightGunMode

    /// Per-game crosshair style override. `nil` falls back to the global default.
    public var crosshairStyle: LightGunCrosshairStyle?

    /// Per-game sensitivity multiplier override (0.1 – 5.0). `nil` falls back to the global default.
    public var sensitivityOverride: Double?

    public init(
        mode: LightGunMode = .automatic,
        crosshairStyle: LightGunCrosshairStyle? = nil,
        sensitivityOverride: Double? = nil
    ) {
        self.mode = mode
        self.crosshairStyle = crosshairStyle
        self.sensitivityOverride = sensitivityOverride
    }

    /// Returns `true` when all fields equal the defaults (nothing to persist).
    public var isDefault: Bool {
        return mode == .automatic && crosshairStyle == nil && sensitivityOverride == nil
    }
}

// MARK: - Defaults Keys

public extension Defaults.Keys {

    // MARK: Global light gun settings

    /// Global crosshair style used when a game does not have a per-game override.
    static let lightGunCrosshairStyle = Key<LightGunCrosshairStyle>(
        "lightGunCrosshairStyle", default: .crosshair
    )

    /// Global auto-detect toggle. When `true` the engine attempts to detect
    /// light gun support from the system identifier and loaded core. When `false`
    /// all games default to light gun off unless overridden per-game.
    static let lightGunAutoDetect = Key<Bool>("lightGunAutoDetect", default: true)

    // MARK: Per-game overrides

    /// Dictionary of per-game light gun settings keyed by game MD5 hash.
    /// Only games with at least one non-default value are stored here.
    static let lightGunGameSettings = Key<[String: LightGunGameSettings]>(
        "lightGunGameSettings", default: [:]
    )
}

// MARK: - Defaults Helpers

public extension Defaults {

    /// Returns the effective light gun settings for a game, falling back to defaults.
    static func lightGunSettings(forGameMD5 md5: String) -> LightGunGameSettings {
        guard !md5.isEmpty else { return LightGunGameSettings() }
        return Defaults[.lightGunGameSettings][md5] ?? LightGunGameSettings()
    }

    /// Persists light gun settings for a game. Removes the entry if all values
    /// are defaults (keeps the dictionary compact).
    static func setLightGunSettings(_ settings: LightGunGameSettings, forGameMD5 md5: String) {
        guard !md5.isEmpty else { return }
        if settings.isDefault {
            Defaults[.lightGunGameSettings].removeValue(forKey: md5)
        } else {
            Defaults[.lightGunGameSettings][md5] = settings
        }
    }

    /// Returns the effective crosshair style for a game:
    /// per-game override if set, otherwise the global default.
    static func effectiveCrosshairStyle(forGameMD5 md5: String) -> LightGunCrosshairStyle {
        return Defaults[.lightGunGameSettings][md5]?.crosshairStyle
            ?? Defaults[.lightGunCrosshairStyle]
    }

    /// Returns the effective sensitivity for a game:
    /// per-game override if set, otherwise the global light gun mouse sensitivity.
    static func effectiveLightGunSensitivity(forGameMD5 md5: String) -> Double {
        return Defaults[.lightGunGameSettings][md5]?.sensitivityOverride
            ?? Defaults[.lightGunMouseSensitivity]
    }
}
