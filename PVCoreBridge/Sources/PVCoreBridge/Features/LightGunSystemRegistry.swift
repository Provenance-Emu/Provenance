//
//  LightGunSystemRegistry.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Thread-safe registry that tracks which SystemIdentifiers have at least one
//  core advertising light-gun support.
//
//  There are two complementary levels of light-gun awareness:
//
//  1. **System level** (`SystemIdentifier.supportsLightGun`): answers "does
//     this system have *any* titles/cores that use a light gun?"  Used for
//     pre-load UI decisions (show/hide lightgun settings, filter system list).
//     Backed by this registry.
//
//  2. **Core level** (`LightGunResponder.gameSupportsLightGun`): answers "does
//     the *currently loaded core* support a light gun right now?"  Queried on
//     a running core instance.  A core may dynamically update this (e.g. after
//     `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO` is received) and call
//     `LightGunSystemRegistry.shared.register(system:)` to persist the
//     discovery across future launches.
//
//  Usage from a core:
//  ```swift
//  // At core-load time, after controller info is populated:
//  if gameSupportsLightGun {
//      LightGunSystemRegistry.shared.register(system: detectedSystemID)
//  }
//  ```
//
//  Usage from the UI:
//  ```swift
//  if systemIdentifier.supportsLightGun { showLightGunOptions() }
//  ```

import Foundation
import PVPrimitives

// MARK: - LightGunSystemsProvider

/// Implement this protocol on a **core class** (not an instance) to declare at
/// compile time which system identifiers the core can drive with a light gun.
/// The app calls `LightGunSystemRegistry.shared.registerProvider(MyCore.self)`
/// during startup so that `SystemIdentifier.supportsLightGun` is accurate even
/// before a game is loaded.
///
/// Example:
/// ```swift
/// extension PVMyNESCore: LightGunSystemsProvider {
///     static var lightGunSupportedSystemIdentifiers: Set<SystemIdentifier> {
///         [.NES, .FDS]
///     }
/// }
/// ```
public protocol LightGunSystemsProvider: AnyObject {
    /// The set of system identifiers for which this core class supports a
    /// light-gun peripheral.
    static var lightGunSupportedSystemIdentifiers: Set<SystemIdentifier> { get }
}

// MARK: - LightGunSystemRegistry

/// Thread-safe, append-only registry of `SystemIdentifier`s that have at least
/// one core supporting a light-gun peripheral.
///
/// The registry is seeded with a built-in baseline (systems historically known
/// to have light-gun titles) and is extended at runtime either by:
/// - core classes that conform to `LightGunSystemsProvider` calling
///   `registerProvider(_:)`, or
/// - running cores that detect lightgun support via
///   `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO` calling `register(system:)`.
public final class LightGunSystemRegistry {

    // MARK: Singleton

    public static let shared = LightGunSystemRegistry()

    // MARK: State

    private let lock = NSLock()

    /// The current set of known lightgun-capable systems.
    private var _systems: Set<SystemIdentifier>

    // MARK: Init

    private init() {
        // Built-in baseline — systems historically known to have lightgun
        // peripherals.  Cores that register themselves at runtime will extend
        // this set; they will NOT shrink it (registry is append-only so that
        // discovery persists for the session even after a core is unloaded).
        _systems = [
            .NES,       // Zapper
            .SNES,      // Super Scope, Justifier
            .Genesis,   // Menacer, Justifier
            .PSX,       // Guncon, Konami Justifier
            .Saturn,    // Stunner
            .MAME,      // Arcade lightgun games
            .Atari2600, // Crossbow, other gun games
        ]
    }

    // MARK: Registration

    /// Register a single system identifier as lightgun-capable.
    /// Safe to call from any thread; safe to call multiple times with the same value.
    public func register(system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        _systems.insert(system)
    }

    /// Register a set of system identifiers as lightgun-capable.
    /// Safe to call from any thread.
    public func register(systems: Set<SystemIdentifier>) {
        lock.lock(); defer { lock.unlock() }
        _systems.formUnion(systems)
    }

    /// Convenience: pull supported systems from a `LightGunSystemsProvider`
    /// core class and register them all.
    ///
    /// Call once per core class during app startup or core initialisation:
    /// ```swift
    /// LightGunSystemRegistry.shared.registerProvider(PVMyCore.self)
    /// ```
    public func registerProvider(_ provider: LightGunSystemsProvider.Type) {
        register(systems: provider.lightGunSupportedSystemIdentifiers)
    }

    // MARK: Query

    /// Returns `true` if *any* registered core or the built-in baseline
    /// indicates lightgun support for `system`.
    public func supportsLightGun(_ system: SystemIdentifier) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _systems.contains(system)
    }

    /// A snapshot of all currently registered lightgun-capable system identifiers.
    public var registeredSystems: Set<SystemIdentifier> {
        lock.lock(); defer { lock.unlock() }
        return _systems
    }

    // MARK: Testing

    /// Replaces the entire registry with the given set.  **For unit tests only.**
    public func _reset(to systems: Set<SystemIdentifier> = []) {
        lock.lock(); defer { lock.unlock() }
        _systems = systems
    }
}
