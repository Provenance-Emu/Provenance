//
//  JITCoreCapability.swift
//  PVUIBase
//
//  Declares which cores require or benefit from JIT compilation.
//  Replaces the ad-hoc hardcoded keyword array that previously lived in
//  PVEmulatorViewController+JIT.swift.
//
//  The authoritative source is `PVEmulatorCore.jitRequirement` (PVPrimitives.PVJITRequirement,
//  introduced in #2793). Use this keyword-based enum only when a core object isn't available
//  (e.g. pre-launch checks or UI components that don't hold a core reference).
//

/// Known core categories and their relationship to JIT.
///
/// Each case carries the keyword fragments that appear in a core's
/// `coreIdentifier` string.
///
/// > Note: When you have access to the core object, prefer `PVEmulatorCore.jitRequirement`
/// > (a `PVPrimitives.PVJITRequirement`) for an authoritative, per-core answer.
/// > This enum is a keyword-based fallback for contexts where the core object isn't available.
///
/// Helpers:
///  - `JITCoreCapability.isJITRelevant(_:)` — true for any core that uses JIT at all (show HUD)
///  - `JITCoreCapability.coreIsJITRequired(_:)` — true only for cores where JIT is mandatory
///    (i.e. corresponds to `.requiredOrCrash` in `PVJITRequirement`)
public enum JITCoreCapability: CaseIterable {
    /// Dolphin — GameCube / Wii emulator (automatic with fallback; never crashes without JIT)
    case dolphin
    /// PPSSPP — Sony PSP emulator (optional; interpreter fallback available)
    case ppsspp
    /// Azahar / Citra / emuThree — Nintendo 3DS emulator (JIT required; crashes without it)
    case azahar
    /// Flycast — Sega Dreamcast / NAOMI emulator (optional; software renderer fallback)
    case flycast
    /// Mupen64Plus — Nintendo 64 emulator (optional; cached interpreter fallback)
    case mupen
    /// Play! / PCSX2-based cores — Sony PlayStation 2 (JIT required; crashes without it)
    case pcsx2

    // MARK: - Metadata

    /// Substrings that may appear (lowercased) in a core's `coreIdentifier`.
    /// A match on any keyword marks the core as JIT-relevant.
    public var coreIdentifierKeywords: [String] {
        switch self {
        case .dolphin:  return ["dolphin", "pvdolphin", "gamecube", "wii"]
        case .ppsspp:   return ["ppsspp"]
        case .azahar:   return ["azahar", "citra", "3ds", "emuthree"]
        case .flycast:  return ["flycast", "dreamcast"]
        case .mupen:    return ["mupen", "n64"]
        case .pcsx2:    return ["ps2", "pcsx2", "play"]
        }
    }

    /// Whether this core category **requires** JIT to run at all.
    ///
    /// `true` corresponds to `.requiredOrCrash` in `PVPrimitives.PVJITRequirement` —
    /// the core will crash, freeze, or produce garbage without JIT.
    /// `false` means JIT is beneficial (recommended) but the core has a working fallback.
    ///
    /// Matches the per-core `jitRequirement` overrides shipped in #2793:
    ///  - Azahar / emuThree → `.requiredOrCrash` → `true`
    ///  - Play (PCSX2) → `.requiredOrCrash` → `true`
    ///  - Dolphin → `.automaticWithFallback` → `false`
    ///  - PPSSPP → `.optional("Interpreter")` → `false`
    ///  - Flycast → `.optional(...)` → `false`
    ///  - Mupen64Plus → `.optional("Cached Interpreter")` → `false`
    public var isJITRequired: Bool {
        switch self {
        case .azahar, .pcsx2:
            return true
        case .dolphin, .ppsspp, .flycast, .mupen:
            return false
        }
    }

    // MARK: - Lookup

    /// Returns the matched `JITCoreCapability` for `coreIdentifier`, or `nil` if no match.
    /// - Parameter coreIdentifier: A core identifier string (case-insensitive).
    public static func capability(for coreIdentifier: String) -> JITCoreCapability? {
        let id = coreIdentifier.lowercased()
        return allCases.first { capability in
            capability.coreIdentifierKeywords.contains(where: { id.contains($0) })
        }
    }

    /// Returns `true` when `coreIdentifier` matches **any** known JIT-relevant core
    /// (i.e. the core uses JIT at all, whether required or merely beneficial).
    ///
    /// Use this to decide whether to show the JIT HUD indicator.
    /// To gate a "JIT unavailable" error, use `coreIsJITRequired(_:)` instead.
    public static func isJITRelevant(_ coreIdentifier: String) -> Bool {
        capability(for: coreIdentifier) != nil
    }

    /// Returns `true` when the core identified by `coreIdentifier` **requires** JIT
    /// for playable performance (as opposed to merely benefiting from it).
    ///
    /// Use this to set `.unavailable` status when JIT cannot be acquired.
    public static func coreIsJITRequired(_ coreIdentifier: String) -> Bool {
        capability(for: coreIdentifier)?.isJITRequired == true
    }

    // MARK: - Deprecated

    /// - Deprecated: Renamed to `isJITRelevant(_:)` to better reflect that it includes
    ///   cores where JIT is recommended but not strictly required (e.g. flycast, mupen).
    ///   Use `coreIsJITRequired(_:)` when you need to gate a hard failure on JIT absence.
    @available(*, deprecated, renamed: "isJITRelevant")
    public static func coreRequiresJIT(_ coreIdentifier: String) -> Bool {
        isJITRelevant(coreIdentifier)
    }
}
