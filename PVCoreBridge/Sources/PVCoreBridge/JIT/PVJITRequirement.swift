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

import Foundation
import os

// MARK: - PVJITRequirement

/// Describes how much a given emulator core relies on Just-In-Time compilation.
///
/// Use `String.jitRequirement` on a core identifier string, or call
/// `jitRequirement(forCoreIdentifier:)` directly to look up the level for any core.
///
/// ## Authoring new cores
/// Add a `PVJITRequirement` key to the core's `Core.plist`:
/// ```xml
/// <key>PVJITRequirement</key>
/// <string>required</string>   <!-- "required" | "optional" | "notRequired" -->
/// ```
/// No Swift code changes are needed. `CoreLoader` automatically registers the
/// value into `PVJITRequirementRegistry` when the plist is loaded.
public enum PVJITRequirement: String, Sendable, Equatable, Hashable, CaseIterable {
    /// The core does not use JIT at all (or the JIT path is unused on this platform).
    /// Examples: NES, SNES, GB, GBA, Genesis, …
    case notRequired

    /// JIT is an optional performance enhancement; the core runs correctly without it,
    /// but noticeably faster when JIT is available.
    /// Examples: Mupen64Plus, Mupen64Plus-NX, Flycast
    case optional

    /// The core will crash or refuse to boot without JIT.
    /// Examples: Azahar (3DS), emuThreeDS (3DS), Dolphin (GameCube/Wii), Play! (PS2)
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

/// Thread-safe registry that maps core identifiers to their `PVJITRequirement`.
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

    private let storage = OSAllocatedUnfairLock<[String: PVJITRequirement]>(initialState: [:])

    // MARK: Registration

    /// Register a JIT requirement for the given core identifier.
    ///
    /// Called by `CoreLoader` for each loaded `Core.plist` that contains a
    /// `PVJITRequirement` key. Identifiers are stored lower-cased to make
    /// lookups case-insensitive.
    public func register(_ requirement: PVJITRequirement, forCoreIdentifier identifier: String) {
        storage.withLock { $0[identifier.lowercased()] = requirement }
    }

    /// Convenience overload that parses a raw `Core.plist` string value.
    /// Does nothing if the string cannot be mapped to a known requirement.
    public func register(rawValue: String, forCoreIdentifier identifier: String) {
        guard let requirement = PVJITRequirement(plistValue: rawValue) else { return }
        register(requirement, forCoreIdentifier: identifier)
    }

    // MARK: Lookup

    /// Returns the registered `PVJITRequirement` for `identifier`, or `.notRequired`
    /// if no entry was registered (e.g. the core's plist omits the key).
    public func requirement(forCoreIdentifier identifier: String) -> PVJITRequirement {
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
    /// Returns the `PVJITRequirement` for this core-identifier string.
    ///
    /// Delegates to `PVJITRequirementRegistry.shared`, which is populated by
    /// `CoreLoader` at startup from each core's `Core.plist`.
    var jitRequirement: PVJITRequirement {
        jitRequirement(forCoreIdentifier: self)
    }
}

// MARK: - Free function

/// Returns the `PVJITRequirement` for the given core identifier.
///
/// This is the canonical look-up function; the `String` extension delegates here.
public func jitRequirement(forCoreIdentifier coreIdentifier: String) -> PVJITRequirement {
    PVJITRequirementRegistry.shared.requirement(forCoreIdentifier: coreIdentifier)
}
