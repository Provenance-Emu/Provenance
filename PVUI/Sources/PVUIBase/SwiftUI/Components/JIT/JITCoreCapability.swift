//
//  JITCoreCapability.swift
//  PVUIBase
//
//  Declares which cores require or benefit from JIT compilation.
//  Replaces the ad-hoc hardcoded keyword array that previously lived in
//  PVEmulatorViewController+JIT.swift.
//
//  ## Lookup priority
//  Static helpers (`isJITRelevant`, `coreIsJITRequired`) follow a two-stage lookup:
//
//  1. **Runtime registry (authoritative)** — `PVJITRequirementRegistry.shared` is
//     populated by `CoreLoader` at startup from each core's `Core.plist`.
//     Exact core-identifier strings (e.g. `"com.provenance.core.dolphin"`) are used here.
//
//  2. **Compile-time keyword fallback** — Substring matching via `coreIdentifierKeywords`
//     is used when the registry has no entry (e.g. tests or pre-CoreLoader contexts)
//     or when the caller passes a partial identifier like `"dolphin"`.
//
//  When you have access to the core object, prefer `PVEmulatorCore.jitRequirement`
//  (a `PVPrimitives.PVJITRequirement`) for the most granular, per-core answer.
//

import PVCoreBridge

/// Known core categories and their relationship to JIT.
///
/// Each case carries the keyword fragments that appear in a core's
/// `coreIdentifier` string, used as a compile-time fallback when the runtime
/// `PVJITRequirementRegistry` has no entry for the queried identifier.
///
/// > Note: The static helpers `isJITRelevant(_:)` and `coreIsJITRequired(_:)`
/// > consult `PVJITRequirementRegistry` first (registry is populated from Core.plist
/// > by CoreLoader at runtime) before falling back to keyword matching.
/// > When you have access to the core object, prefer `PVEmulatorCore.jitRequirement`
/// > (a `PVPrimitives.PVJITRequirement`) for an authoritative, per-core answer.
///
/// Helpers:
///  - `JITCoreCapability.isJITRelevant(_:)` — true for any core that uses JIT at all (show HUD)
///  - `JITCoreCapability.coreIsJITRequired(_:)` — true only for cores where JIT is mandatory
///    (plist `required` / Swift `.requiredOrCrash`)
public enum JITCoreCapability: CaseIterable {
    /// Dolphin — GameCube / Wii emulator (automatic with fallback; never crashes without JIT)
    case dolphin
    /// PPSSPP — Sony PSP emulator (optional; interpreter fallback available)
    case ppsspp
    /// Azahar / Citra / emuThree — Nintendo 3DS emulator (automatic with fallback; detects JIT at runtime)
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
    /// Used as a compile-time fallback when the runtime registry has no entry.
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

    /// Substrings that appear (lowercased) in a **system** identifier string.
    ///
    /// System identifiers follow the pattern `"com.provenance.<name>"` (e.g.
    /// `"com.provenance.psp"`), which differs from core identifiers like
    /// `"com.provenance.core.ppsspp"`.  Use this list in `systemHasJITCapability(_:)`
    /// rather than `coreIdentifierKeywords` to avoid false negatives like
    /// `"com.provenance.psp".contains("ppsspp") == false`.
    public var systemIdentifierKeywords: [String] {
        switch self {
        case .dolphin:  return ["gamecube", "wii"]
        case .ppsspp:   return ["psp"]
        case .azahar:   return ["3ds"]
        case .flycast:  return ["dreamcast"]
        case .mupen:    return ["n64"]
        case .pcsx2:    return ["ps2"]
        }
    }

    /// Whether this core category **requires** JIT to run at all.
    ///
    /// `true` corresponds to `PVJITPlistRequirement.required` / `.requiredOrCrash` in
    /// `PVPrimitives.PVJITRequirement` — the core will crash, freeze, or produce garbage
    /// without JIT.
    /// `false` means JIT is beneficial (recommended / automatic) but the core has a
    /// working fallback.
    ///
    /// This value reflects the plist-level classification:
    ///  - Play (PS2/PCSX2) → `PVJITRequirement = required` → `true`
    ///  - Azahar / emuThree → `PVJITRequirement = optional` (auto-detects JIT) → `false`
    ///  - Dolphin → `PVJITRequirement = optional` (self-detects JIT) → `false`
    ///  - PPSSPP → `PVJITRequirement = optional` (interpreter fallback) → `false`
    ///  - Flycast → `PVJITRequirement = optional` (software renderer fallback) → `false`
    ///  - Mupen64Plus → `PVJITRequirement = optional` (cached interpreter fallback) → `false`
    ///
    /// > Important: Prefer the runtime registry or `PVEmulatorCore.jitRequirement` over
    /// > this compile-time value. Use `coreIsJITRequired(_:)` for a registry-aware query.
    public var isJITRequired: Bool {
        switch self {
        case .pcsx2:
            return true
        case .dolphin, .ppsspp, .azahar, .flycast, .mupen:
            return false
        }
    }

    /// Whether this core runs significantly worse without JIT and should show a
    /// one-time performance notice even when JIT cannot be acquired on the device.
    ///
    /// - `true`: Dolphin (GameCube/Wii), Azahar (3DS), Flycast (Dreamcast) —
    ///   JIT makes the difference between "barely playable" and a good experience.
    ///   Users should be warned to set expectations, even if JIT is structurally
    ///   unavailable (e.g. iOS 26 App Store build without the JIT entitlement).
    /// - `false`: PPSSPP (interpreter fallback is acceptable), Mupen64Plus (cached
    ///   interpreter is tolerable for many games). No notice shown when JIT unavailable.
    ///   PS2 is excluded here because it is handled by `isJITRequired`.
    public var isPerformanceCritical: Bool {
        switch self {
        case .dolphin, .azahar, .flycast:
            return true
        case .ppsspp, .mupen, .pcsx2:
            return false
        }
    }

    // MARK: - Lookup

    /// Returns the matched `JITCoreCapability` for `coreIdentifier` via keyword matching,
    /// or `nil` if no keyword matches.
    ///
    /// This is the **compile-time keyword fallback**. For registry-aware queries use
    /// `isJITRelevant(_:)` and `coreIsJITRequired(_:)` which consult
    /// `PVJITRequirementRegistry` first.
    ///
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
    /// Uses `PVJITRequirementRegistry` (populated from Core.plist by CoreLoader) as the
    /// primary source, falling back to compile-time keyword matching for partial identifiers
    /// or pre-CoreLoader contexts.
    ///
    /// Use this to decide whether to show the JIT HUD indicator.
    /// To gate a "JIT unavailable" error, use `coreIsJITRequired(_:)` instead.
    public static func isJITRelevant(_ coreIdentifier: String) -> Bool {
        // Stage 1: runtime registry (exact identifier match, case-insensitive)
        let plistReq = PVJITRequirementRegistry.shared.requirement(forCoreIdentifier: coreIdentifier)
        if plistReq != .notRequired {
            return true
        }
        // Stage 2: compile-time keyword fallback (substring match)
        return capability(for: coreIdentifier) != nil
    }

    /// Returns `true` when the core identified by `coreIdentifier` **requires** JIT
    /// for playable performance (as opposed to merely benefiting from it).
    ///
    /// Uses `PVJITRequirementRegistry` (populated from Core.plist by CoreLoader) as the
    /// primary source, falling back to compile-time keyword matching for partial identifiers
    /// or pre-CoreLoader contexts.
    ///
    /// Use this to set `.unavailable` status when JIT cannot be acquired.
    public static func coreIsJITRequired(_ coreIdentifier: String) -> Bool {
        // Stage 1: runtime registry (exact identifier match, case-insensitive)
        let plistReq = PVJITRequirementRegistry.shared.requirement(forCoreIdentifier: coreIdentifier)
        switch plistReq {
        case .required:
            return true
        case .optional:
            // Registry explicitly says optional — no need for keyword fallback
            return false
        case .notRequired:
            break // fall through to keyword lookup (may be "not found" rather than explicit)
        }
        // Stage 2: compile-time keyword fallback
        return capability(for: coreIdentifier)?.isJITRequired == true
    }

    /// Returns `true` when the core runs significantly worse without JIT and should
    /// always show a one-time performance notice — even when JIT cannot be acquired.
    ///
    /// Uses `PVJITRequirementRegistry` as the primary source; falls back to keyword
    /// matching. Required cores (`coreIsJITRequired`) are excluded — they have a
    /// separate blocking warning.
    public static func isJITPerformanceCritical(_ coreIdentifier: String) -> Bool {
        // Required cores are handled separately.
        if coreIsJITRequired(coreIdentifier) { return false }
        // Stage 1: if registry says optional, use keyword tier to determine criticality.
        // Stage 2: compile-time keyword fallback.
        return capability(for: coreIdentifier)?.isPerformanceCritical == true
    }

    // MARK: - System Lookup

    /// Returns `true` when any JIT-relevant keyword matches the given system identifier.
    ///
    /// System identifiers follow the pattern `"com.provenance.<name>"` (e.g.
    /// `"com.provenance.psp"`, `"com.provenance.n64"`, `"com.provenance.dreamcast"`).
    /// This method uses `systemIdentifierKeywords` (not `coreIdentifierKeywords`) to
    /// avoid false negatives such as `"com.provenance.psp".contains("ppsspp") == false`.
    ///
    /// - Parameter systemIdentifier: A system identifier string (case-insensitive).
    /// - Returns: `true` if the system is known to have JIT-capable cores.
    public static func systemHasJITCapability(_ systemIdentifier: String) -> Bool {
        #if DEBUG
        assertKnownSystemMappingsOnce()
        #endif
        let id = systemIdentifier.lowercased()
        return allCases.contains { capability in
            capability.systemIdentifierKeywords.contains { id.contains($0) }
        }
    }

    #if DEBUG
    /// Nonisolated flag so the once-check is safe to read from any context
    /// without requiring actor hops on the hot SwiftUI render path.
    private static let _assertOnceFlag: Bool = {
        func matchesJITSystem(_ systemIdentifier: String) -> Bool {
            let id = systemIdentifier.lowercased()
            return allCases.contains { capability in
                capability.systemIdentifierKeywords.contains { id.contains($0) }
            }
        }
        // Expected JIT-capable systems
        assert(matchesJITSystem("com.provenance.psp"), "Expected PSP system to be JIT-capable.")
        assert(matchesJITSystem("com.provenance.n64"), "Expected N64 system to be JIT-capable.")
        assert(matchesJITSystem("com.provenance.gamecube"), "Expected GameCube system to be JIT-capable.")
        // Expected non-JIT system (acts as a control)
        assert(!matchesJITSystem("com.provenance.snes"), "Expected SNES system to NOT be JIT-capable.")
        return true
    }()

    /// Triggers `_assertOnceFlag` initialisation on the first call only.
    private static func assertKnownSystemMappingsOnce() {
        _ = _assertOnceFlag
    }
    #endif

    // MARK: - Deprecated

    /// - Deprecated: Renamed to `isJITRelevant(_:)` to better reflect that it includes
    ///   cores where JIT is recommended but not strictly required (e.g. flycast, mupen).
    ///   Use `coreIsJITRequired(_:)` when you need to gate a hard failure on JIT absence.
    @available(*, deprecated, renamed: "isJITRelevant")
    public static func coreRequiresJIT(_ coreIdentifier: String) -> Bool {
        isJITRelevant(coreIdentifier)
    }
}
