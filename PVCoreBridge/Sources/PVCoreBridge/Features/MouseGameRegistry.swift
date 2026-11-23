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
//  The baseline data (`alwaysMouseSystems`, `conditionalMouseSystems`,
//  `knownMouseGameMD5s`, `knownMouseGameTitlePatterns`) is internal;
//  use `systemHasAnyMouseSupport(_:)` and `gameSupportsMouse(...)` as
//  the stable public API.
//

import Foundation
import os
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
public final class MouseGameRegistry: Sendable {

    // MARK: Singleton

    public static let shared = MouseGameRegistry()

    // MARK: State

    /// The lists, with what cores have registered on top of the baseline below.
    private let state = OSAllocatedUnfairLock(initialState: MouseGameRegistry.baselineState)

    /// The registry as shipped, before any core registers more.
    private static var baselineState: PeripheralGameRegistryState {
        PeripheralGameRegistryState(alwaysSystems: alwaysMouseSystems,
                                    conditionalSystems: conditionalMouseSystems,
                                    knownMD5s: knownMouseGameMD5s,
                                    titlePatterns: knownMouseGameTitlePatterns)
    }

    // MARK: - Baseline data

    /// Systems where **every** game supports mouse input.
    /// Cores that are primarily mouse-driven (desktop emulators, FPS) live here.
    static let alwaysMouseSystems: Set<SystemIdentifier> = [
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
    static let conditionalMouseSystems: Set<SystemIdentifier> = [
        .SNES,      // Mario Paint, Mario & Wario, Undead Line, Dezaemon, Battle Cross
        .Saturn,    // Virtua Fighter Kids, ManX TT Super Bike, Typing of the Dead
        .Dreamcast, // Typing of the Dead, Planet Ring
        .PSX,       // Point Blank series and a handful of others
        .N64,       // 64DD titles (very rare)
    ]

    private static let marioPaintTitlePattern = "mario paint"

    private static let marioPaintMD5s: Set<String> = [
        // Mario Paint (USA)
        "d6f64fd0642a514a5fba4707fca4f1ed",
        // Mario Paint (Japan)
        "c28bf66ac5d2d7d436a1c06e35ce2b6c",
        // Mario Paint (Europe)
        "1f3f05b1c5e0e42e25a60fe07b5c88f1",
        // Mario Paint (Japan, USA)
        "881d3772a3eb37a8a0fb254e940c6767"
    ]

    /// MD5 hashes (lowercased) of games that are known to use a mouse.
    ///
    /// Source: No-Intro / Redump databases.  Add new entries by calling
    /// `registerKnownMouseGameMD5(_:)` at runtime.
    static let knownMouseGameMD5s: Set<String> = marioPaintMD5s.union([
        // Mario & Wario (Japan) — requires SNES Mouse
        "f38d7df7e27c7b08a3c40be30049d74d",
        // Undead Line (Japan)
        "a8f95e8e0c47acef4aad5d855f785e6e"
    ])

    /// Title keyword fragments (lowercased) per system.  A game matches if its
    /// lowercased title **contains** any entry in the list for its system.
    ///
    /// Keep patterns specific enough to avoid false positives.
    static let knownMouseGameTitlePatterns: [SystemIdentifier: [String]] = [
        .SNES: [
            marioPaintTitlePattern,
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
            "typing of the dead",    // Typing of the Dead — keyboard + mouse required
            "planet ring",           // Planet Ring — party game with mouse mini-games
            "floigan brothers",      // Floigan Brothers Episode One — mouse pointer interactions
            "industrial spy",        // Industrial Spy: Operation Espionage
            "dreamcast browser",     // Various Dreamcast web browser discs
            "web browser",           // Sega's Web Browser for Dreamcast
            "dream passport",        // Dream Passport internet browser series
        ],
        .PSX: [
            "point blank",     // Point Blank / Gun Bullet series
        ],
    ]

    // MARK: UserDefaults key for user overrides

    private static let overrideKeyPrefix = "MouseGameRegistry.mouseEnabled."

    // MARK: Init

    private init() {}

    // MARK: - Dynamic Registration

    /// Register a system where every game supports mouse.
    /// Safe to call from any thread.
    public func registerAlwaysMouseSystem(_ system: SystemIdentifier) {
        state.withLock { $0.addAlwaysSystem(system) }
    }

    /// Register a system where only specific games use a mouse.
    /// Has no effect if the system is already an always-mouse system.
    /// Safe to call from any thread.
    public func registerConditionalMouseSystem(_ system: SystemIdentifier) {
        state.withLock { $0.addConditionalSystem(system) }
    }

    /// Register the MD5 hash of a mouse-supporting game.
    /// `md5` may be any case — it is normalised to lowercase internally.
    /// Safe to call from any thread.
    public func registerKnownMouseGameMD5(_ md5: String) {
        state.withLock { $0.addMD5(md5) }
    }

    /// Register a title keyword fragment for a mouse-supporting game.
    /// `pattern` may be any case — it is normalised to lowercase internally.
    /// Safe to call from any thread.
    public func registerTitlePattern(_ pattern: String, forSystem system: SystemIdentifier) {
        state.withLock { $0.addTitlePattern(pattern, forSystem: system) }
    }

    /// Convenience: pull all mouse game data from a `MouseGamesProvider` core class.
    ///
    /// The provider's lists are read before the lock is taken (they are the core's code), then
    /// added in one step, so a query never sees a provider half registered.
    public func registerProvider(_ provider: MouseGamesProvider.Type) {
        let alwaysSystems = provider.mouseAlwaysSupportedSystems
        let conditionalSystems = provider.mouseConditionalSystems
        let md5s = provider.knownMouseGameMD5s
        let titlePatterns = provider.knownMouseGameTitlePatterns

        state.withLock {
            $0.add(alwaysSystems: alwaysSystems, conditionalSystems: conditionalSystems,
                   md5s: md5s, titlePatterns: titlePatterns)
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

    /// Returns `true` if the system has any mouse support (always-on or conditional),
    /// consulting the registry's live state so dynamically registered systems are included.
    ///
    /// - Parameter system: The system to check.
    public func systemHasAnyMouseSupport(_ system: SystemIdentifier) -> Bool {
        state.withLock { $0.hasAnySupport(system) }
    }

    /// Whether every game on `system` takes a mouse (DOS, Atari ST, Macintosh and the like).
    /// A per-game override is not consulted for these.
    public func systemAlwaysHasMouse(_ system: SystemIdentifier) -> Bool {
        state.withLock { $0.alwaysSystems.contains(system) }
    }

    /// Determine whether the currently loaded game supports a mouse peripheral.
    ///
    /// Decision order:
    /// 1. Always-mouse system → `true`.
    /// 2. User override (UserDefaults) — wins on every other system.
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
        // The lock is held only for the copy; the title search runs on the snapshot.
        let snapshot = state.withLock { $0 }

        // A machine built around the mouse keeps it whatever was saved for the game: an "off"
        // there only ever meant "hide the touch trackpad", and it also cut off a hardware
        // mouse and the pause menu's Mouse switch on every later launch.
        if snapshot.alwaysSystems.contains(systemIdentifier) { return true }

        // 1. On every other system the user override takes precedence.
        if let md5, let override = userOverride(forMD5: md5) {
            return override
        }

        return snapshot.supports(systemIdentifier: systemIdentifier, md5: md5, title: title)
    }

    /// The zero-based SNES mouse port to configure automatically, if the game uses a mouse.
    public func snesMousePortIndex(md5: String?, title: String?) -> Int? {
        guard gameSupportsMouse(systemIdentifier: .SNES, md5: md5, title: title) else { return nil }

        // Mario Paint reads the mouse on controller port 1.
        if let md5, Self.marioPaintMD5s.contains(md5.lowercased()) { return 0 }
        if title?.lowercased().contains(Self.marioPaintTitlePattern) == true { return 0 }
        return 1
    }

    // MARK: - Testing

    /// Resets the registry to factory defaults.  **For unit tests only.**
    func _reset() {
        let baseline = Self.baselineState
        state.withLock { $0 = baseline }
    }
}

#if canImport(ObjectiveC)
/// Lets native Objective-C cores apply the per-game setting over their own automatic detection.
@objc(PVMouseGameRegistry)
public final class MouseGameRegistryObjC: NSObject {
    @objc(shouldEnableMouseForROMMD5:autoDetected:)
    public static func shouldEnableMouse(forROMMD5 md5: String?, autoDetected: Bool) -> Bool {
        guard let md5, !md5.isEmpty else { return autoDetected }
        return MouseGameRegistry.shared.userOverride(forMD5: md5) ?? autoDetected
    }
}
#endif
