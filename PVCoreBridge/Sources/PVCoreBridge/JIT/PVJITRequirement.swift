//
//  PVJITRequirement.swift
//  PVCoreBridge
//
//  JIT Capability Matrix — classifies each core by its JIT requirement.
//  Part of issue #2793.
//

import Foundation

// MARK: - PVJITRequirement

/// Describes how much a given emulator core relies on Just-In-Time compilation.
///
/// Use `String.jitRequirement` on a core identifier string, or call
/// `jitRequirement(forCoreIdentifier:)` directly to look up the level for any core.
public enum PVJITRequirement: String, Sendable, Equatable, Hashable {
    /// The core does not use JIT at all (or the JIT path is unused on this platform).
    /// Examples: NES, SNES, GB, GBA, Genesis, …
    case notRequired

    /// JIT is an optional performance enhancement; the core runs correctly without it,
    /// but noticeably faster when JIT is available.
    /// Examples: Mupen64Plus, Mupen64Plus-NX, Flycast
    case optional

    /// The core will crash or refuse to boot without JIT.
    /// Examples: Citra / Azahar (3DS), emuThreeDS (3DS), Dolphin (GameCube/Wii), Play! (PS2)
    case required
}

// MARK: - Core identifier constants

/// Strongly-typed core-identifier strings used in the JIT matrix.
/// These match the `PVCoreIdentifier` keys in each core's `Core.plist`.
public enum PVCoreIdentifiers {
    // MARK: JIT-required cores
    public static let azahar          = "com.provenance.core.azahar"
    public static let emuThree        = "com.provenance.core.emuThree"
    public static let dolphin         = "com.provenance.core.dolphin"
    public static let play            = "com.provenance.core.play"   // Play! (PS2)

    // MARK: JIT-optional cores
    public static let mupen64Plus     = "com.provenance.core.mupen64plus"
    public static let mupen64PlusNX   = "com.provenance.core.mupen64plusnx"
    public static let flycast         = "com.provenance.core.flycast"
}

// MARK: - String extension

public extension String {
    /// Returns the `PVJITRequirement` for this core-identifier string.
    ///
    /// The lookup is case-insensitive and falls back to `.notRequired` for any
    /// identifier that is not explicitly listed in the matrix.
    var jitRequirement: PVJITRequirement {
        jitRequirement(forCoreIdentifier: self)
    }
}

// MARK: - Free function

/// Returns the `PVJITRequirement` for the given core identifier.
///
/// This is the canonical look-up function; the `String` extension delegates here.
public func jitRequirement(forCoreIdentifier coreIdentifier: String) -> PVJITRequirement {
    switch coreIdentifier.lowercased() {
    // MARK: required
    case PVCoreIdentifiers.azahar,
         PVCoreIdentifiers.emuThree,
         PVCoreIdentifiers.dolphin,
         PVCoreIdentifiers.play:
        return .required

    // MARK: optional (faster with JIT, not crash-required)
    case PVCoreIdentifiers.mupen64Plus,
         PVCoreIdentifiers.mupen64PlusNX,
         PVCoreIdentifiers.flycast:
        return .optional

    // MARK: default — everything else does not use JIT
    default:
        return .notRequired
    }
}
