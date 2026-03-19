//
//  MouseGameRegistry.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Thread-safe registry for per-game mouse support detection.
//
//  There are two levels of mouse awareness:
//
//  1. **System level**: some systems always have mouse support (DOS, Macintosh).
//     Others have it for a handful of titles only (SNES ~5 games, Dreamcast, etc.).
//
//  2. **Game level**: within a "conditional" system, a specific game is identified
//     by its MD5 hash or title keywords and listed in the known-games database.
//
//  A user override (stored in UserDefaults) always wins over automatic detection.
//  This lets players force-enable mouse for an unlisted game or force-disable it
//  for a misidentified one.
//
//  ## Adding new games
//
//  To add a newly discovered mouse title:
//
//  **By MD5** (preferred – most accurate):
//  ```swift
//  MouseGameRegistry.shared.registerKnownMouseGameMD5("abc123...")
//  ```
//
//  **By title keyword** (fallback):
//  ```swift
//  MouseGameRegistry.shared.registerTitlePattern("my game", forSystem: .SNES)
//  ```
//
//  The baseline sets `alwaysMouseSystems`, `conditionalMouseSystems`,
//  `knownMouseGameMD5s`, and `knownMouseGameTitlePatterns` document the
//  rationale for each entry.
//

import Foundation
import PVSystems

// MARK: - MouseGamesProvider

/// Implement on a **core class** to declare compile-time mouse game support.
/// Optional — cores may also register support dynamically at runtime.
///
/// ```swift
/// extension PVMySNESCore: MouseGamesProvider {
///     static var mouseAlwaysSupportedSystems: Set<SystemIdentifier> { [] }
///     static var mouseConditionalSystems: Set<SystemIdentifier> { [.SNES] }
///     static var knownMouseGameMD5s: Set<String> {
///         ["d6f64fd0642a514a5fba4707fca4f1ed"] // Mario Paint USA
///     }
///     static var knownMouseGameTitlePatterns: [SystemIdentifier: [String]] {
///         [.SNES: ["mario paint"]]
///     }
/// }
/// ```
public protocol MouseGamesProvider: AnyObject {
    /// Systems where every game supports mouse input.
    static var mouseAlwaysSupportedSystems: Set<SystemIdentifier> { get }
    /// Systems where only specific games use a mouse.
    static var mouseConditionalSystems: Set<SystemIdentifier> { get }
    /// MD5 hashes (lowercased) of known mouse-using games.
    static var knownMouseGameMD5s: Set<String> { get }
    /// Title keyword fragments (lowercased) per system for known mouse games.
    static var knownMouseGameTitlePatterns: [SystemIdentifier: [String]] { get }
}

// MARK: - MouseGameRegistry

/// Thread-safe registry that determines at runtime whether the currently loaded
/// game supports a mouse peripheral.
///
/// Consult via:
/// ```swift
/// let supportsMouse = MouseGameRegistry.shared.gameSupportsMouse(
///     systemIdentifier: sysID, md5: romMD5, title: romName
/// )
/// ```
public final class MouseGameRegistry: @unchecked Sendable {

    // MARK: Singleton

    public static let shared = MouseGameRegistry()

    // MARK: State

    private let lock = NSLock()

    private var _alwaysSystems: Set<SystemIdentifier>
    private var _conditionalSystems: Set<SystemIdentifier>
    private var _knownMD5s: Set<String>          // all lowercased
    private var _titlePatterns: [SystemIdentifier: Set<String>]  // all lowercased

    // MARK: - Baseline data

    /// Systems where **every** game supports mouse input.
    /// Cores that are primarily mouse-driven (desktop emulators, FPS) live here.
    public static let alwaysMouseSystems: Set<SystemIdentifier> = [
        .DOS,        // DOSBox — virtually all DOS software uses a mouse
        .AppleII,    // Apple II emulator with pointer support
        .Macintosh,  // Classic Mac OS — mouse is the primary input
        .AtariST,    // Atari ST — GEM desktop relies on mouse
        .Atari8bit,  // Atari 8-bit with trackball/mouse peripheral
        .MSX,        // MSX mouse peripheral
        .MSX2,       // MSX2 mouse peripheral
        .PC98,       // PC-98 — mouse required for many titles
        .EP128,      // Enterprise 128 with mouse
        .DOOM,       // DOOM — mouse-look support
        .Quake,      // Quake — mouse-look support
        .Quake2,     // Quake II — mouse-look support
        .Wolf3D,     // Wolfenstein 3D — mouse-look support
        .ZXSpectrum, // ZX Spectrum +3 / Interface II with mouse
    ]

    /// Systems where only **specific titles** use a mouse.
    /// For these systems `gameSupportsMouse` also checks MD5/title.
    public static let conditionalMouseSystems: Set<SystemIdentifier> = [
        .SNES,      // Mario Paint, Mario & Wario, Undead Line, Dezaemon, Battle Cross
        .Saturn,    // Virtua Fighter Kids, ManX TT Super Bike, Typing of the Dead
        .Dreamcast, // Typing of the Dead, Planet Ring
        .PSX,       // Point Blank series and a handful of others
        .N64,       // 64DD titles (very rare)
    ]

    /// MD5 hashes (lowercased) of games that are known to use a mouse.
    ///
    /// Source: No-Intro / Redump databases.  Add new entries by calling
    /// `registerKnownMouseGameMD5(_:)` at runtime.
    public static let knownMouseGameMD5s: Set<String> = [
        // ── SNES ──────────────────────────────────────────────────────────────
        // Mario Paint (USA)
        "d6f64fd0642a514a5fba4707fca4f1ed",
        // Mario Paint (Japan)
        "c28bf66ac5d2d7d436a1c06e35ce2b6c",
        // Mario Paint (Europe)
        "1f3f05b1c5e0e42e25a60fe07b5c88f1",
        // Mario & Wario (Japan) — requires SNES Mouse
        "f38d7df7e27c7b08a3c40be30049d74d",
        // Undead Line (Japan)
        "a8f95e8e0c47acef4aad5d855f785e6e",
    ]

    /// Title keyword fragments (lowercased) per system.  A game matches if its
    /// lowercased title **contains** any entry in the list for its system.
    ///
    /// Keep patterns specific enough to avoid false positives.
    public static let knownMouseGameTitlePatterns: [SystemIdentifier: [String]] = [
        .SNES: [
            "mario paint",
            "mario & wario",
            "mario and wario",
            "undead line",
            "dezaemon",        // Dezaemon — SNES sprite/music editor, uses mouse
            "battle cross",    // Battle Cross
        ],
        .Saturn: [
            "virtua fighter kids",
            "manx tt",
            "typing of the dead",
        ],
        .Dreamcast: [
            "typing of the dead",
            "planet ring",
        ],
        .PSX: [
            "point blank",     // Point Blank / Gun Bullet series
        ],
    ]

    // MARK: UserDefaults key for user overrides

    private static let overrideKeyPrefix = "MouseGameRegistry.mouseEnabled."

    // MARK: Init

    private init() {
        _alwaysSystems = Self.alwaysMouseSystems
        _conditionalSystems = Self.conditionalMouseSystems
        _knownMD5s = Set(Self.knownMouseGameMD5s.map { $0.lowercased() })

        var patterns: [SystemIdentifier: Set<String>] = [:]
        for (sys, list) in Self.knownMouseGameTitlePatterns {
            patterns[sys] = Set(list.map { $0.lowercased() })
        }
        _titlePatterns = patterns
    }

    // MARK: - Dynamic Registration

    /// Register a system where every game supports mouse.
    /// Safe to call from any thread.
    public func registerAlwaysMouseSystem(_ system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        _alwaysSystems.insert(system)
        _conditionalSystems.remove(system)
    }

    /// Register a system where only specific games use a mouse.
    /// Has no effect if the system is already in `_alwaysSystems`.
    /// Safe to call from any thread.
    public func registerConditionalMouseSystem(_ system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        guard !_alwaysSystems.contains(system) else { return }
        _conditionalSystems.insert(system)
    }

    /// Register the MD5 hash of a mouse-supporting game.
    /// `md5` may be any case — it is normalised to lowercase internally.
    /// Safe to call from any thread.
    public func registerKnownMouseGameMD5(_ md5: String) {
        lock.lock(); defer { lock.unlock() }
        _knownMD5s.insert(md5.lowercased())
    }

    /// Register a title keyword fragment for a mouse-supporting game.
    /// `pattern` may be any case — it is normalised to lowercase internally.
    /// Safe to call from any thread.
    public func registerTitlePattern(_ pattern: String, forSystem system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        let key = pattern.lowercased()
        if _titlePatterns[system] == nil {
            _titlePatterns[system] = [key]
        } else {
            _titlePatterns[system]!.insert(key)
        }
    }

    /// Convenience: pull all mouse game data from a `MouseGamesProvider` core class.
    public func registerProvider(_ provider: MouseGamesProvider.Type) {
        for sys in provider.mouseAlwaysSupportedSystems {
            registerAlwaysMouseSystem(sys)
        }
        for sys in provider.mouseConditionalSystems {
            registerConditionalMouseSystem(sys)
        }
        for md5 in provider.knownMouseGameMD5s {
            registerKnownMouseGameMD5(md5)
        }
        for (sys, list) in provider.knownMouseGameTitlePatterns {
            for pattern in list {
                registerTitlePattern(pattern, forSystem: sys)
            }
        }
    }

    // MARK: - User Override

    /// Returns the user-set override for a game, or `nil` if none is set.
    ///
    /// - Parameter md5: The ROM's MD5 hash (any case).
    public func userOverride(forMD5 md5: String) -> Bool? {
        let key = Self.overrideKeyPrefix + md5.lowercased()
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Set or clear the user override for a specific game.
    ///
    /// - Parameters:
    ///   - enabled: `true` to force mouse on, `false` to force off, `nil` to clear.
    ///   - md5: The ROM's MD5 hash (any case).
    public func setUserOverride(_ enabled: Bool?, forMD5 md5: String) {
        let key = Self.overrideKeyPrefix + md5.lowercased()
        if let enabled {
            UserDefaults.standard.set(enabled, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Query

    /// Determine whether the currently loaded game supports a mouse peripheral.
    ///
    /// Decision order:
    /// 1. User override (UserDefaults) — always wins.
    /// 2. Always-mouse system → `true`.
    /// 3. System not in any mouse list → `false`.
    /// 4. Known MD5 in database → `true`.
    /// 5. Title keyword match in database → `true`.
    /// 6. Default → `false` (prevents false positives for unlisted SNES games).
    ///
    /// - Parameters:
    ///   - systemIdentifier: The system the game runs on.
    ///   - md5: The ROM's MD5 hash, or `nil` if unavailable.
    ///   - title: The game's title string, or `nil` if unavailable.
    public func gameSupportsMouse(
        systemIdentifier: SystemIdentifier,
        md5: String?,
        title: String?
    ) -> Bool {
        // 1. User override takes absolute precedence.
        if let md5, let override = userOverride(forMD5: md5) {
            return override
        }

        lock.lock()
        let alwaysSystems = _alwaysSystems
        let conditionalSystems = _conditionalSystems
        let knownMD5s = _knownMD5s
        let patterns = _titlePatterns
        lock.unlock()

        // 2. Always-mouse systems never need a game-level check.
        if alwaysSystems.contains(systemIdentifier) { return true }

        // 3. Not a mouse-capable system at all.
        if !conditionalSystems.contains(systemIdentifier) { return false }

        // 4. Check known MD5 database.
        if let md5, knownMD5s.contains(md5.lowercased()) { return true }

        // 5. Check title keyword patterns for the system.
        if let title, let systemPatterns = patterns[systemIdentifier] {
            let lowTitle = title.lowercased()
            if systemPatterns.contains(where: { lowTitle.contains($0) }) { return true }
        }

        // 6. Unknown game on a conditional system — no mouse by default.
        return false
    }

    // MARK: - Testing

    /// Resets the registry to factory defaults.  **For unit tests only.**
    func _reset() {
        lock.lock(); defer { lock.unlock() }
        _alwaysSystems = Self.alwaysMouseSystems
        _conditionalSystems = Self.conditionalMouseSystems
        _knownMD5s = Set(Self.knownMouseGameMD5s.map { $0.lowercased() })
        var patterns: [SystemIdentifier: Set<String>] = [:]
        for (sys, list) in Self.knownMouseGameTitlePatterns {
            patterns[sys] = Set(list.map { $0.lowercased() })
        }
        _titlePatterns = patterns
    }
}
