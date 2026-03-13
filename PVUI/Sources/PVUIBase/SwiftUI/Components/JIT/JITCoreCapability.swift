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
/// `coreIdentifier` string.  Use `JITCoreCapability.coreRequiresJIT(_:)` as the
/// single source of truth for JIT gating decisions in `PVUIBase`.
public enum JITCoreCapability: CaseIterable {
    /// Dolphin — GameCube / Wii emulator (JIT strongly required for playable speed)
    case dolphin
    /// PPSSPP — Sony PSP emulator (JIT strongly recommended)
    case ppsspp
    /// Azahar / Citra — Nintendo 3DS emulator (JIT strongly recommended)
    case azahar
    /// Flycast — Sega Dreamcast / NAOMI emulator (JIT recommended)
    case flycast
    /// Mupen64Plus — Nintendo 64 emulator (JIT recommended)
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

    /// Whether this core category generally requires JIT for good performance.
    public var isJITRequired: Bool {
        switch self {
        case .dolphin, .ppsspp, .azahar, .pcsx2:
            return true
        case .flycast, .mupen:
            return false
        }
    }

    // MARK: - Lookup

    /// Returns `true` when `coreIdentifier` matches any known JIT-relevant core.
    /// - Parameter coreIdentifier: The lowercased `coreIdentifier` string from `PVEmulatorCore`.
    public static func coreRequiresJIT(_ coreIdentifier: String) -> Bool {
        let id = coreIdentifier.lowercased()
        return allCases.contains { capability in
            capability.coreIdentifierKeywords.contains(where: { id.contains($0) })
        }
    }
}
