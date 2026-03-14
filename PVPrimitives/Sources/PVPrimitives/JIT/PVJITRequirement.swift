// PVJITRequirement.swift
// PVPrimitives
//
// Created by Provenance Emu on 2026-03-13.
// Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Classifies an emulator core by its JIT (Just-In-Time compilation) behaviour.
///
/// Use this enum to determine what JIT acquisition strategy is required before
/// launching a game.  The app layer queries `PVEmulatorCore.jitRequirement` and
/// then uses `PVJIT` to satisfy the requirement (or warns the user when it
/// cannot be satisfied).
///
/// ## Precedence
/// A core should be classified by its *worst-case* JIT dependency:
/// - `.requiredOrCrash` means the core will hard-crash or produce meaningless
///   output without JIT — do not launch without it.
/// - `.automaticWithFallback` means the core self-detects JIT availability and
///   switches execution paths; launch is always safe.
/// - `.optional(fallback:)` means JIT improves performance/accuracy but the
///   core runs (perhaps slowly) without it.
/// - `.notSupported` means the core has no JIT code path at all.
///
/// ## Adding a new core
/// Override `jitRequirement` in the core's `PVEmulatorCore` subclass:
/// ```swift
/// open override var jitRequirement: PVJITRequirement { .optional(fallback: "Interpreter") }
/// ```
public enum PVJITRequirement: Sendable {

    // MARK: Cases

    /// The core has no JIT implementation.  Safe to launch without JIT.
    ///
    /// Examples: NES (FCEU), SNES (snes9x/SNESticle), Game Boy (Gambatte).
    case notSupported

    /// JIT improves performance or accuracy but the core can fall back to a
    /// slower pure-interpreter path when JIT is unavailable.
    ///
    /// - Parameter fallback: Human-readable name of the fallback execution mode
    ///   shown in UI warnings (e.g. `"Interpreter"`, `"Cached Interpreter"`).
    ///
    /// Examples: Mupen64Plus, melonDS, pcsx_rearmed, DeSmuME 2015, PPSSPP.
    case optional(fallback: String)

    /// The core will crash, freeze, or produce garbage without JIT.
    ///
    /// Do **not** launch this core unless JIT has been successfully acquired.
    ///
    /// Examples: Citra (emuThree), Azahar — when `enableJIT` is `true`.
    case requiredOrCrash

    /// The core internally detects JIT availability at startup and selects an
    /// appropriate execution back-end automatically.  Launch is always safe.
    ///
    /// Example: Dolphin (GameCube / Wii).
    case automaticWithFallback

    // MARK: Computed Properties

    /// Whether the core can be launched safely without JIT entitlement.
    public var isSafeWithoutJIT: Bool {
        switch self {
        case .notSupported, .automaticWithFallback:
            return true
        case .optional:
            return true
        case .requiredOrCrash:
            return false
        }
    }

    /// Whether any JIT path exists for this core.
    public var hasJIT: Bool {
        switch self {
        case .notSupported:
            return false
        case .optional, .requiredOrCrash, .automaticWithFallback:
            return true
        }
    }

    /// A short human-readable description suitable for logging or debug UI.
    public var displayDescription: String {
        switch self {
        case .notSupported:
            return "Not supported"
        case .optional(let fallback):
            return "Optional (fallback: \(fallback))"
        case .requiredOrCrash:
            return "Required — crashes without JIT"
        case .automaticWithFallback:
            return "Automatic with fallback"
        }
    }
}

extension PVJITRequirement: Equatable {}
