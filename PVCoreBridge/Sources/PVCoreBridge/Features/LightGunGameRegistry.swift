//
//  LightGunGameRegistry.swift
//  PVCoreBridge
//
//  Per-game registry that determines whether a specific ROM supports a
//  light-gun peripheral (Zapper / Super Scope / GunCon / Stunner / Light
//  Phaser / Menacer / Justifier / Sears Light Gun).
//
//  Built to mirror ``MouseGameRegistry``. The split exists because
//  ``LightGunResponder.gameSupportsLightGun`` was historically system-wide
//  on the libretro cores — NES would report `true` for *every* ROM because
//  the Zapper exists for the system, which made the touch-aim cursor
//  paint onto regular gamepad games (PROVENANCE-14W follow-up: NES
//  Bomberman II showing a PC cursor). Per-game gating lives here.
//

import Foundation

// MARK: - LightGunGamesProvider

/// Lets emulator cores publish their per-system light-gun mapping the same
/// way ``MouseGamesProvider`` works for mouse peripherals.
public protocol LightGunGamesProvider: AnyObject {
    /// Systems where every game supports a light gun. Rare — most systems
    /// only have a handful of gun titles, so this is usually empty.
    static var lightGunAlwaysSupportedSystems: Set<SystemIdentifier> { get }
    /// Systems where only specific games use a light gun.
    static var lightGunConditionalSystems: Set<SystemIdentifier> { get }
    /// MD5 hashes (lowercased) of known light-gun-using games.
    static var knownLightGunGameMD5s: Set<String> { get }
    /// Title keyword fragments (lowercased) per system for known gun games.
    static var knownLightGunGameTitlePatterns: [SystemIdentifier: [String]] { get }
}

// MARK: - LightGunGameRegistry

/// Thread-safe registry that determines at runtime whether the currently
/// loaded game supports a light-gun peripheral.
///
/// Consult via:
/// ```swift
/// let supportsGun = LightGunGameRegistry.shared.gameSupportsLightGun(
///     systemIdentifier: sysID, md5: romMD5, title: romTitle
/// )
/// ```
public final class LightGunGameRegistry: @unchecked Sendable {

    // MARK: Singleton

    public static let shared = LightGunGameRegistry()

    // MARK: State

    private let lock = NSLock()

    private var _alwaysSystems: Set<SystemIdentifier>
    private var _conditionalSystems: Set<SystemIdentifier>
    private var _knownMD5s: Set<String>
    private var _titlePatterns: [SystemIdentifier: Set<String>]

    // MARK: - Baseline data

    /// Systems where every loaded game has a gun. Reserved for hypothetical
    /// gun-only cores; empty for the real hardware we support.
    static let alwaysLightGunSystems: Set<SystemIdentifier> = []

    /// Systems where only specific titles use a light gun. Auto-detect
    /// consults the MD5 + title patterns below for these.
    static let conditionalLightGunSystems: Set<SystemIdentifier> = [
        .NES,           // Zapper
        .SNES,          // Super Scope + Justifier (Lethal Enforcers)
        .PSX,           // GunCon / G-Con + Justifier
        .Saturn,        // Stunner / Virtua Gun
        .SegaCD,        // Justifier (Lethal Enforcers I & II) + Menacer
        .Genesis,       // Menacer (T2 Arcade, Mary Shelley's Frankenstein, etc.)
        .MasterSystem,  // Light Phaser
        .FDS,           // Famicom Disk System Zapper titles
    ]

    /// MD5 hashes (lowercased) of games that are known to use a light gun.
    /// Seeded from No-Intro / Redump headers for popular titles. Extend at
    /// runtime via `registerKnownLightGunGameMD5(_:)`.
    static let knownLightGunGameMD5s: Set<String> = [
        // ── NES (Zapper) ─────────────────────────────────────────────────
        // Duck Hunt (USA)
        "fbc23a35a4ad8c1f10b9b9cea48f95a3",
        // Hogan's Alley (USA)
        "8b8dbb1f17ed09cbe25d5c3c8edfaf85",
        // Wild Gunman (USA)
        "4e7c4747a2c8c46a169ea66c12cf2d96",
    ]

    /// Title keyword fragments (lowercased) per system. A game matches if
    /// its lowercased title **contains** any entry in the list for its
    /// system. Patterns should be specific enough to avoid false positives
    /// (e.g. "wolf" alone would catch Wolfenstein too — use "operation wolf").
    static let knownLightGunGameTitlePatterns: [SystemIdentifier: [String]] = [
        .NES: [
            "duck hunt",
            "hogan's alley",
            "hogans alley",
            "wild gunman",
            "gotcha",
            "operation wolf",
            "mechanized attack",
            "adventures of bayou billy",
            "baby boomer",
            "barker bill",
            "chiller",
            "dirty harry",
            "freedom force",
            "gumshoe",
            "lone ranger",
            "shooting range",
            "to the earth",
            "track & field ii",
        ],
        .FDS: [
            "duck hunt",
            "wild gunman",
            "hogan's alley",
            "hogans alley",
        ],
        .SNES: [
            "yoshi's safari",
            "yoshis safari",
            "battle clash",
            "super scope 6",
            "bazooka blitzkrieg",
            "tin star",
            "metal combat",
            "metal combat: falcon's revenge",
            "lethal enforcers",       // Justifier
            "operation thunderbolt",
            "t2: the arcade game",
            "terminator 2: the arcade",
            "x-zone",
        ],
        .PSX: [
            "time crisis",            // Time Crisis 1 + Project Titan
            "time crisis 2",
            "point blank",            // Point Blank 1/2/3 (Gun Bullet JP)
            "die hard trilogy 2",
            "crypt killer",
            "elemental gearbolt",
            "g.i. joe",
            "judge dredd",
            "lethal enforcers",       // Justifier on PSX
            "moorhuhn",               // Moorhuhn Wanted
            "police 911",
            "rescue shot",
            "resident evil: survivor",
            "resident evil survivor",
            "snipes",
            "vampire night",
        ],
        .Saturn: [
            "virtua cop",             // Virtua Cop 1 + 2
            "house of the dead",
            "area 51",
            "crypt killer",
            "death crimson",
            "die hard arcade",
            "maximum force",
            "mighty hits",
            "policenauts",
        ],
        .SegaCD: [
            "lethal enforcers",
            "menacer",
            "ground zero, texas",
            "snatcher",               // partial — uses Menacer in some scenes
        ],
        .Genesis: [
            "menacer",                // Menacer 6-game cart
            "t2: the arcade game",
            "terminator 2: the arcade",
            "mary shelley's frankenstein",
            "body count",
        ],
        .MasterSystem: [
            "operation wolf",
            "shooting gallery",
            "space gun",
            "wanted",
            "assault city",
            "bank panic",
            "gangster town",
            "laser ghost",
            "marksman shooting",
            "missile defense 3-d",
            "missile defense 3d",
            "rambo iii",              // uses Light Phaser
            "rescue mission",
            "safari hunt",
            "trap shooting",
        ],
    ]

    // MARK: UserDefaults key for user overrides

    private static let overrideKeyPrefix = "LightGunGameRegistry.lightGunEnabled."

    // MARK: Init

    private init() {
        _alwaysSystems = Self.alwaysLightGunSystems
        _conditionalSystems = Self.conditionalLightGunSystems
        _knownMD5s = Set(Self.knownLightGunGameMD5s.map { $0.lowercased() })

        var patterns: [SystemIdentifier: Set<String>] = [:]
        for (sys, list) in Self.knownLightGunGameTitlePatterns {
            patterns[sys] = Set(list.map { $0.lowercased() })
        }
        _titlePatterns = patterns
    }

    // MARK: - Dynamic Registration

    /// Register a system where every game supports a light gun.
    /// Safe to call from any thread.
    public func registerAlwaysLightGunSystem(_ system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        _alwaysSystems.insert(system)
        _conditionalSystems.remove(system)
    }

    /// Register a system where only specific games use a light gun.
    /// Has no effect if the system is already in `_alwaysSystems`.
    /// Safe to call from any thread.
    public func registerConditionalLightGunSystem(_ system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        guard !_alwaysSystems.contains(system) else { return }
        _conditionalSystems.insert(system)
    }

    /// Register the MD5 hash of a light-gun-supporting game.
    /// `md5` may be any case — it is normalised to lowercase internally.
    /// Safe to call from any thread.
    public func registerKnownLightGunGameMD5(_ md5: String) {
        lock.lock(); defer { lock.unlock() }
        _knownMD5s.insert(md5.lowercased())
    }

    /// Register a title keyword fragment for a light-gun-supporting game.
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

    /// Convenience: pull all light-gun game data from a `LightGunGamesProvider` class.
    public func registerProvider(_ provider: LightGunGamesProvider.Type) {
        for sys in provider.lightGunAlwaysSupportedSystems {
            registerAlwaysLightGunSystem(sys)
        }
        for sys in provider.lightGunConditionalSystems {
            registerConditionalLightGunSystem(sys)
        }
        for md5 in provider.knownLightGunGameMD5s {
            registerKnownLightGunGameMD5(md5)
        }
        for (sys, list) in provider.knownLightGunGameTitlePatterns {
            for pattern in list {
                registerTitlePattern(pattern, forSystem: sys)
            }
        }
    }

    // MARK: - User Override

    /// Returns the user-set override for a game, or `nil` if none is set.
    public func userOverride(forMD5 md5: String) -> Bool? {
        let key = Self.overrideKeyPrefix + md5.lowercased()
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Set or clear the user override for a specific game.
    public func setUserOverride(_ enabled: Bool?, forMD5 md5: String) {
        let key = Self.overrideKeyPrefix + md5.lowercased()
        if let enabled {
            UserDefaults.standard.set(enabled, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Query

    /// Returns `true` if the system has any light-gun support (always-on or
    /// conditional).
    public func systemHasAnyLightGunSupport(_ system: SystemIdentifier) -> Bool {
        lock.lock()
        let result = _alwaysSystems.contains(system) || _conditionalSystems.contains(system)
        lock.unlock()
        return result
    }

    /// Determine whether the currently loaded game supports a light gun.
    ///
    /// Decision order:
    /// 1. User override (UserDefaults) — always wins.
    /// 2. Always-gun system → `true`.
    /// 3. System not in any gun list → `false`.
    /// 4. Known MD5 in database → `true`.
    /// 5. Title keyword match in database → `true`.
    /// 6. Default → `false` (prevents stray cursors on unlisted titles).
    public func gameSupportsLightGun(
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

        // 2. Always-gun systems never need a game-level check.
        if alwaysSystems.contains(systemIdentifier) { return true }

        // 3. Not a gun-capable system at all.
        if !conditionalSystems.contains(systemIdentifier) { return false }

        // 4. Check known MD5 database.
        if let md5, knownMD5s.contains(md5.lowercased()) { return true }

        // 5. Check title keyword patterns for the system.
        if let title, let systemPatterns = patterns[systemIdentifier] {
            let lowTitle = title.lowercased()
            if systemPatterns.contains(where: { lowTitle.contains($0) }) { return true }
        }

        // 6. Unknown game on a conditional system — no gun by default.
        return false
    }

    // MARK: - Testing

    /// Resets the registry to factory defaults. **For unit tests only.**
    func _reset() {
        lock.lock(); defer { lock.unlock() }
        _alwaysSystems = Self.alwaysLightGunSystems
        _conditionalSystems = Self.conditionalLightGunSystems
        _knownMD5s = Set(Self.knownLightGunGameMD5s.map { $0.lowercased() })
        var patterns: [SystemIdentifier: Set<String>] = [:]
        for (sys, list) in Self.knownLightGunGameTitlePatterns {
            patterns[sys] = Set(list.map { $0.lowercased() })
        }
        _titlePatterns = patterns
    }
}
