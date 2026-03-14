//
//  PVJITRequirement.swift
//  PVCoreBridge
//
//  JIT Capability Matrix — classifies each core by its JIT requirement.
//  Part of issue #2793.
//
//  The authoritative source of JIT requirements is each core's `Core.plist`
//  via the `PVJITRequirement` key. `PVJITRequirementRegistry` is populated
//  at app startup by `CoreLoader` after it reads those plists; no static
//  identifier list needs to be maintained here.
//
//  ## Type naming note
//  This module defines `PVJITPlistRequirement` — the simple 3-case plist-level
//  classification used for dynamic lookup. The richer 4-case `PVJITRequirement`
//  enum lives in `PVPrimitives` and is used as a per-core Swift property override
//  on `PVEmulatorCore` subclasses.  The different names prevent the ambiguity
//  that would arise if both modules were imported in the same translation unit
//  (which occurs via `PVEmulatorCore`'s `@_exported import` of both modules).
//

import Foundation
import os

// MARK: - PVJITPlistRequirement

/// Plist-level JIT classification for a core, parsed from `Core.plist`.
///
/// `CoreLoader` reads the `PVJITRequirement` plist key and registers the parsed
/// value in `PVJITRequirementRegistry`.  The richer per-core Swift property
/// (`PVEmulatorCore.jitRequirement`) uses the `PVPrimitives.PVJITRequirement`
/// enum and is the preferred API for runtime launch decisions.
///
/// ## Authoring new cores
/// Add a `PVJITRequirement` key to the core's `Core.plist`:
/// ```xml
/// <key>PVJITRequirement</key>
/// <string>required</string>   <!-- "required" | "optional" | "notRequired" -->
/// ```
/// No Swift code changes are needed. `CoreLoader` automatically registers the
/// value into `PVJITRequirementRegistry` when the plist is loaded.
public enum PVJITPlistRequirement: String, Sendable, Equatable, Hashable, CaseIterable {
    /// The core does not use JIT at all (or the JIT path is unused on this platform).
    /// Examples: NES, SNES, GB, GBA, Genesis, …
    case notRequired

    /// JIT is an optional performance enhancement; the core runs correctly without it,
    /// but noticeably faster when JIT is available.
    /// Examples: Mupen64Plus, Mupen64Plus-NX, Flycast
    case optional

    /// The core will crash or refuse to boot without JIT.
    /// Examples: Azahar (3DS), emuThreeDS (3DS), Play! (PS2)
    /// Note: Dolphin auto-detects JIT and uses a fallback — classify it as `.optional`
    /// in the plist (or rely on `PVDolphinCore.jitRequirement = .automaticWithFallback`).
    case required

    // MARK: Parsing

    /// Initialise from the raw string stored in `Core.plist`.
    /// Case-insensitive; unknown values return `nil`.
    public init?(plistValue: String) {
        switch plistValue.lowercased() {
        case "required":        self = .required
        case "optional":        self = .optional
        case "notrequired", "not_required", "not required", "none":
            self = .notRequired
        default:                return nil
        }
    }
}

// MARK: - PVJITRequirementRegistry

/// Thread-safe registry that maps core identifiers to their `PVJITPlistRequirement`.
///
/// `CoreLoader` populates this registry at startup by reading each core's
/// `Core.plist`. Queries fall back to `.notRequired` for any identifier that
/// was not explicitly registered.
///
/// ## Thread safety
/// Uses `OSAllocatedUnfairLock` (same pattern as `CoreLoader`'s plist cache).
public final class PVJITRequirementRegistry: Sendable {

    public static let shared = PVJITRequirementRegistry()
    private init() {}

    private let storage = OSAllocatedUnfairLock<[String: PVJITPlistRequirement]>(initialState: [:])

    // MARK: Registration

    /// Register a JIT requirement for the given core identifier.
    ///
    /// Called by `CoreLoader` for each loaded `Core.plist` that contains a
    /// `PVJITRequirement` key. Identifiers are stored lower-cased to make
    /// lookups case-insensitive.
    public func register(_ requirement: PVJITPlistRequirement, forCoreIdentifier identifier: String) {
        storage.withLock { $0[identifier.lowercased()] = requirement }
    }

    /// Convenience overload that parses a raw `Core.plist` string value.
    /// Does nothing if the string cannot be mapped to a known requirement.
    public func register(rawValue: String, forCoreIdentifier identifier: String) {
        guard let requirement = PVJITPlistRequirement(plistValue: rawValue) else { return }
        register(requirement, forCoreIdentifier: identifier)
    }

    // MARK: Lookup

    /// Returns the registered `PVJITPlistRequirement` for `identifier`, or `.notRequired`
    /// if no entry was registered (e.g. the core's plist omits the key).
    public func requirement(forCoreIdentifier identifier: String) -> PVJITPlistRequirement {
        storage.withLock { $0[identifier.lowercased()] ?? .notRequired }
    }

    // MARK: Testing support

    /// Removes all registered entries. Intended for use in unit tests only.
    public func _resetForTesting() {
        storage.withLock { $0.removeAll() }
    }
}

// MARK: - String extension

public extension String {
    /// Returns the `PVJITPlistRequirement` for this core-identifier string.
    ///
    /// Delegates to `PVJITRequirementRegistry.shared`, which is populated by
    /// `CoreLoader` at startup from each core's `Core.plist`.
    ///
    /// For runtime launch decisions, prefer querying `PVEmulatorCore.jitRequirement`
    /// (the richer `PVPrimitives.PVJITRequirement` 4-case enum).
    var jitPlistRequirement: PVJITPlistRequirement {
        jitPlistRequirement(forCoreIdentifier: self)
    }
}

// MARK: - Free function

/// Returns the `PVJITPlistRequirement` for the given core identifier.
///
/// This is the canonical plist-registry look-up; the `String` extension delegates here.
/// For runtime launch decisions prefer `PVEmulatorCore.jitRequirement` instead.
public func jitPlistRequirement(forCoreIdentifier coreIdentifier: String) -> PVJITPlistRequirement {
    PVJITRequirementRegistry.shared.requirement(forCoreIdentifier: coreIdentifier)
}
