//
//  JITGamePreference.swift
//  PVSettings
//
//  Per-game JIT preference that lets users pre-configure JIT behavior
//  for individual games before launch.
//

import Foundation
@_exported import Defaults

/// Per-game JIT preference for controlling JIT behavior on a per-game basis.
///
/// Stored in `Defaults` keyed by the game's MD5 hash.
/// Only meaningful for games whose system has JIT-capable emulator cores.
public enum JITGamePreference: String, Codable, Equatable, Defaults.Serializable, CaseIterable, Sendable {

    /// Follow the system/core default behavior (no override).
    case automatic

    /// Attempt to acquire and use JIT before launching this game.
    /// For `.requiredOrCrash` cores this is the same as the default.
    /// For `.optional(fallback:)` cores this enables the JIT path explicitly.
    case preferJIT

    /// Suppress the pre-launch JIT prompt for this game and launch immediately.
    ///
    /// This preference controls **UI prompting only** — it does not disable JIT
    /// acquisition at the core level. If JIT is already acquired the core will still
    /// use it; if JIT is unavailable the core falls back to its default interpreter
    /// path (only valid for `.optional(fallback:)` cores; ignored for `.requiredOrCrash`).
    case skipJIT

    // MARK: Display

    public var displayTitle: String {
        switch self {
        case .automatic: return "Automatic"
        case .preferJIT: return "Prefer JIT"
        case .skipJIT:   return "Skip JIT"
        }
    }

    public var displayDescription: String {
        switch self {
        case .automatic:
            return "Use the default behavior for this core"
        case .preferJIT:
            return "Try to enable JIT (Performance Mode) before launching"
        case .skipJIT:
            return "Skip the pre-launch JIT prompt and launch immediately"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .automatic: return "gearshape"
        case .preferJIT: return "bolt.fill"
        case .skipJIT:   return "tortoise.fill"
        }
    }
}

// MARK: - Defaults Keys

public extension Defaults.Keys {

    // MARK: - JIT Game Preferences

    /// Per-game JIT preference dictionary.
    ///
    /// Keys are game MD5 hash strings; values are `JITGamePreference` raw strings.
    /// Only games that have a non-`.automatic` preference are stored here
    /// (`.automatic` is the default and need not be stored explicitly).
    static let jitGamePreferences = Key<[String: JITGamePreference]>("jitGamePreferences", default: [:])
}

// MARK: - Helpers

public extension Defaults {

    /// Returns the JIT preference for a game identified by its MD5 hash.
    /// - Parameter md5: The game's MD5 hash (primary key in Realm).
    /// - Returns: The stored preference, or `.automatic` if none was set.
    static func jitPreference(forGameMD5 md5: String) -> JITGamePreference {
        guard !md5.isEmpty else { return .automatic }
        return Defaults[.jitGamePreferences][md5] ?? .automatic
    }

    /// Sets the JIT preference for a game identified by its MD5 hash.
    /// - Parameters:
    ///   - preference: The preference to store. `.automatic` removes the stored value.
    ///   - md5: The game's MD5 hash.
    static func setJITPreference(_ preference: JITGamePreference, forGameMD5 md5: String) {
        guard !md5.isEmpty else { return }
        if preference == .automatic {
            Defaults[.jitGamePreferences].removeValue(forKey: md5)
        } else {
            Defaults[.jitGamePreferences][md5] = preference
        }
    }
}
