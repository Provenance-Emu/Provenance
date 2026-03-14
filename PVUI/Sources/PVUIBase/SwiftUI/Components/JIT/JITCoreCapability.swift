//
//  JITCoreCapability.swift
//  PVUIBase
//
//  Declares which cores require or benefit from JIT compilation.
//  Replaces the ad-hoc hardcoded keyword array that previously lived in
//  PVEmulatorViewController+JIT.swift.
//
//  When the full JIT Capability Matrix (#2793) lands, this file should be
//  replaced by a protocol-based lookup against the core's manifest.
//

/// Known core categories and their relationship to JIT.
///
/// Each case carries the keyword fragments that appear in a core's
/// `coreIdentifier` string.
///
/// Use these helpers as the single source of truth for JIT gating in `PVUIBase`:
///  - `JITCoreCapability.isJITRelevant(_:)` — true for any core that uses JIT at all (show HUD)
///  - `JITCoreCapability.coreIsJITRequired(_:)` — true only for cores where JIT is mandatory
public enum JITCoreCapability: CaseIterable {
    /// Dolphin — GameCube / Wii emulator (JIT strongly required for playable speed)
    case dolphin
    /// PPSSPP — Sony PSP emulator (JIT strongly recommended)
    case ppsspp
    /// Azahar / Citra — Nintendo 3DS emulator (JIT strongly recommended)
    case azahar
    /// Flycast — Sega Dreamcast / NAOMI emulator (JIT recommended, not required)
    case flycast
    /// Mupen64Plus — Nintendo 64 emulator (JIT recommended, not required)
    case mupen
    /// PCSX2-based cores — Sony PlayStation 2 (JIT required)
    case pcsx2

    // MARK: - Metadata

    /// Substrings that may appear (lowercased) in a core's `coreIdentifier`.
    /// A match on any keyword marks the core as JIT-relevant.
    public var coreIdentifierKeywords: [String] {
        switch self {
        case .dolphin:  return ["dolphin", "pvdolphin", "gamecube", "wii"]
        case .ppsspp:   return ["ppsspp"]
        case .azahar:   return ["azahar", "citra", "3ds"]
        case .flycast:  return ["flycast", "dreamcast"]
        case .mupen:    return ["mupen", "n64"]
        case .pcsx2:    return ["ps2", "pcsx2"]
        }
    }

    /// Whether this core category generally **requires** JIT for good performance.
    /// `false` means JIT is merely recommended / beneficial, not essential.
    public var isJITRequired: Bool {
        switch self {
        case .dolphin, .ppsspp, .azahar, .pcsx2:
            return true
        case .flycast, .mupen:
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
