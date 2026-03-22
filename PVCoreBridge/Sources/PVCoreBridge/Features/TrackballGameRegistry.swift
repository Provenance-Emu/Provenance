// TrackballGameRegistry.swift
// PVCoreBridge
//
// Thread-safe registry for per-game trackball controller detection.
//
// Unlike the `MouseGameRegistry` (which targets desktop-style mouse peripherals),
// this registry specifically tracks games that use a **trackball** controller
// peripheral — primarily Atari 2600 CX-22 / CX-80 titles.
//
// ## Registered systems
//
// - Atari 2600 — CX-22 (original trackball) and CX-80 (wired trackball):
//     Centipede, Millipede, Missile Command, Crystal Castles, Liberator, Maze Craze
//
// ## Usage
//
//     let needsTrackball = TrackballGameRegistry.shared.gameUsesTrackball(
//         systemIdentifier: .Atari2600,
//         md5: rom.md5,
//         title: rom.title
//     )
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import PVSystems

// MARK: - TrackballGameRegistry

/// Thread-safe registry that determines at runtime whether the currently loaded
/// game uses a trackball controller peripheral.
///
/// Decision order (same model as `MouseGameRegistry`):
/// 1. User override (UserDefaults) — always wins.
/// 2. Always-trackball system → `true`.
/// 3. System not in any trackball list → `false`.
/// 4. Known MD5 in database → `true`.
/// 5. Title keyword match in database → `true`.
/// 6. Default → `false`.
public final class TrackballGameRegistry: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = TrackballGameRegistry()

    // MARK: - Internal state

    private let lock = NSLock()
    private var _alwaysSystems: Set<SystemIdentifier>
    private var _conditionalSystems: Set<SystemIdentifier>
    private var _knownMD5s: Set<String>
    private var _titlePatterns: [SystemIdentifier: Set<String>]

    // MARK: - Baseline: systems that always use a trackball

    /// No system always uses only a trackball — it is always per-game.
    static let alwaysTrackballSystems: Set<SystemIdentifier> = []

    /// Systems where specific games use a trackball peripheral.
    static let conditionalTrackballSystems: Set<SystemIdentifier> = [
        .Atari2600,   // CX-22 / CX-80 trackball titles
    ]

    // MARK: - Atari 2600 trackball MD5 hashes (No-Intro database)

    /// MD5 hashes of known Atari 2600 trackball titles (lowercased).
    ///
    /// Sources: No-Intro "Atari - 2600" set, Stella compatibility database.
    /// Add new entries via `registerKnownTrackballGameMD5(_:)`.
    static let knownTrackballGameMD5s: Set<String> = [
        // ── Centipede ─────────────────────────────────────────────────────────
        // Centipede (USA) — Atari trackball pack-in
        "8fba5f7b8ad75179290e5c8c3ac86095",
        // Centipede (Europe)
        "6efe0d45591fb5b3ee174b7e63e27bfd",

        // ── Millipede ─────────────────────────────────────────────────────────
        // Millipede (USA)
        "0dfd9a47b8f3f6dc6e39f81e95a9b2d4",

        // ── Missile Command ───────────────────────────────────────────────────
        // Missile Command (USA) (Rev A)
        "ddaeff25bdf5b82d5ee9b4fb41e45d89",
        // Missile Command (USA)
        "32d5c9eac4c481dce3a74a5a0ab5e9b2",

        // ── Crystal Castles ───────────────────────────────────────────────────
        // Crystal Castles (USA)
        "d55a1278b44b6c5e2f76be5c2b5e71fc",

        // ── Liberator ─────────────────────────────────────────────────────────
        // Liberator (USA)
        "4f618c2429138e0280969193ed6c107e",
    ]

    // MARK: - Title keyword patterns

    /// Title keyword fragments (lowercased) per system.
    /// A game matches if its lowercased title **contains** any entry.
    static let knownTrackballGameTitlePatterns: [SystemIdentifier: [String]] = [
        .Atari2600: [
            "centipede",
            "millipede",
            "missile command",
            "crystal castles",
            "liberator",
        ],
    ]

    // MARK: - UserDefaults key

    private static let overrideKeyPrefix = "TrackballGameRegistry.trackballEnabled."

    // MARK: - Init

    private init() {
        _alwaysSystems = Self.alwaysTrackballSystems
        _conditionalSystems = Self.conditionalTrackballSystems
        _knownMD5s = Set(Self.knownTrackballGameMD5s.map { $0.lowercased() })

        var patterns: [SystemIdentifier: Set<String>] = [:]
        for (sys, list) in Self.knownTrackballGameTitlePatterns {
            patterns[sys] = Set(list.map { $0.lowercased() })
        }
        _titlePatterns = patterns
    }

    // MARK: - Dynamic registration

    /// Register the MD5 hash of a game that uses a trackball controller.
    /// `md5` is normalised to lowercase internally.
    public func registerKnownTrackballGameMD5(_ md5: String) {
        lock.withLock { _knownMD5s.insert(md5.lowercased()) }
    }

    /// Register a title keyword fragment for a trackball-using game.
    public func registerTitlePattern(_ pattern: String, forSystem system: SystemIdentifier) {
        let key = pattern.lowercased()
        lock.withLock {
            if _titlePatterns[system] == nil {
                _titlePatterns[system] = [key]
            } else {
                _titlePatterns[system]!.insert(key)
            }
        }
    }

    // MARK: - User override

    /// Returns the user-set override for a game, or `nil` if none is set.
    public func userOverride(forMD5 md5: String) -> Bool? {
        let key = Self.overrideKeyPrefix + md5.lowercased()
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Set or clear the user override for a specific game.
    ///
    /// - Parameters:
    ///   - enabled: `true` to force trackball on, `false` to force off, `nil` to clear.
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

    /// Returns `true` if the system has any trackball support (always-on or conditional).
    public func systemHasAnyTrackballSupport(_ system: SystemIdentifier) -> Bool {
        lock.withLock { _alwaysSystems.contains(system) || _conditionalSystems.contains(system) }
    }

    /// Determine whether the currently loaded game uses a trackball controller.
    ///
    /// - Parameters:
    ///   - systemIdentifier: The system the game runs on.
    ///   - md5: The ROM's MD5 hash, or `nil` if unavailable.
    ///   - title: The game's title string, or `nil` if unavailable.
    public func gameUsesTrackball(
        systemIdentifier: SystemIdentifier,
        md5: String?,
        title: String?
    ) -> Bool {
        // 1. User override takes absolute precedence.
        if let md5, let override = userOverride(forMD5: md5) {
            return override
        }

        let (alwaysSystems, conditionalSystems, knownMD5s, patterns) = lock.withLock {
            (_alwaysSystems, _conditionalSystems, _knownMD5s, _titlePatterns)
        }

        // 2. Always-trackball systems.
        if alwaysSystems.contains(systemIdentifier) { return true }

        // 3. Not a trackball-capable system.
        if !conditionalSystems.contains(systemIdentifier) { return false }

        // 4. Known MD5 database.
        if let md5, knownMD5s.contains(md5.lowercased()) { return true }

        // 5. Title keyword patterns.
        if let title, let systemPatterns = patterns[systemIdentifier] {
            let lowTitle = title.lowercased()
            if systemPatterns.contains(where: { lowTitle.contains($0) }) { return true }
        }

        // 6. Unknown game on a conditional system — no trackball by default.
        return false
    }

    // MARK: - Testing

    /// Resets the registry to factory defaults. **For unit tests only.**
    func _reset() {
        var patterns: [SystemIdentifier: Set<String>] = [:]
        for (sys, list) in Self.knownTrackballGameTitlePatterns {
            patterns[sys] = Set(list.map { $0.lowercased() })
        }
        lock.withLock {
            _alwaysSystems = Self.alwaysTrackballSystems
            _conditionalSystems = Self.conditionalTrackballSystems
            _knownMD5s = Set(Self.knownTrackballGameMD5s.map { $0.lowercased() })
            _titlePatterns = patterns
        }
    }
}
