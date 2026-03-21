//
//  MIDISystemRegistry.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Thread-safe registry that tracks which SystemIdentifiers have at least one
//  core advertising MIDI support.
//
//  There are two complementary levels of MIDI awareness:
//
//  1. **System level** (`SystemIdentifier.supportsMIDI`): answers "does this
//     system have any titles/cores that use MIDI?"  Used for pre-load UI
//     decisions (show/hide MIDI device picker, filter system list).
//     Backed by this registry.
//
//  2. **Core level** (`MIDIResponder.gamesSupportsMIDI`): answers "does the
//     *currently loaded core* support MIDI right now?"  Queried on a running
//     core instance.  A core may dynamically update this (e.g. after reading
//     a game-specific config) and call `MIDISystemRegistry.shared.register(system:)`
//     to record the discovery for the current session.
//
//  Usage from a core:
//  ```swift
//  if gamesSupportsMIDI {
//      MIDISystemRegistry.shared.register(system: detectedSystemID)
//  }
//  ```
//
//  Usage from the UI:
//  ```swift
//  if systemIdentifier.supportsMIDI { showMIDIDevicePicker() }
//  ```
//

import Foundation
import PVSystems

// MARK: - MIDISystemsProvider

/// Implement this protocol on a **core class** (not an instance) to declare at
/// compile time which system identifiers the core can route through MIDI.
/// Optionally, the app may call
/// `MIDISystemRegistry.shared.registerProvider(MyCore.self)` early in its
/// lifecycle so that `SystemIdentifier.supportsMIDI` returns accurate results
/// before any game is loaded.
///
/// Example:
/// ```swift
/// extension PVAtariSTCore: MIDISystemsProvider {
///     static var midiSupportedSystemIdentifiers: Set<SystemIdentifier> {
///         [.AtariST]
///     }
/// }
/// ```
public protocol MIDISystemsProvider: AnyObject {
    /// The set of system identifiers for which this core class supports MIDI.
    static var midiSupportedSystemIdentifiers: Set<SystemIdentifier> { get }
}

// MARK: - MIDISystemRegistry

/// Thread-safe, append-only registry of `SystemIdentifier`s that have at least
/// one core supporting MIDI peripherals.
///
/// The registry is seeded with a built-in baseline (systems historically known
/// to have MIDI capabilities) and is extended at runtime either by:
/// - core classes that conform to `MIDISystemsProvider` calling
///   `registerProvider(_:)`, or
/// - running cores that detect MIDI support dynamically calling
///   `register(system:)`.
public final class MIDISystemRegistry: @unchecked Sendable {

    // MARK: Singleton

    public static let shared = MIDISystemRegistry()

    // MARK: State

    private let lock = NSLock()
    private var _systems: Set<SystemIdentifier>

    // MARK: Init

    /// Built-in baseline — systems historically known to have MIDI peripherals
    /// or MIDI output support.
    ///
    /// Sources:
    /// - Atari ST: first consumer computer with built-in MIDI In/Out/Thru (1985)
    /// - MSX/MSX2: Music Module (Yamaha), MIDI Pak, Moonsound
    /// - DOS: General MIDI (MPU-401), Roland MT-32 / CM-64 via games like Monkey Island
    /// - PC-98: Roland MPU-98 and similar expansion boards
    /// - Commodore 64: Sequential Circuits, Passport MIDI interfaces
    ///
    /// Note: Amiga and Sharp X68000 are not currently in SystemIdentifier; add
    /// them here if/when those system identifiers are introduced.
    static let baseline: Set<SystemIdentifier> = [
        .AtariST,       // Built-in MIDI In/Out — the canonical MIDI computer
        .DOS,           // General MIDI, MT-32 — huge catalogue of MIDI games
        .MSX,           // Music Module, MIDI Pak
        .MSX2,          // Same ecosystem as MSX
        .PC98,          // Roland MPU-98 expansion
        .C64,           // MIDI cartridges (Sequential Circuits, Passport)
    ]

    private init() {
        _systems = MIDISystemRegistry.baseline
    }

    // MARK: Registration

    /// Register a single system identifier as MIDI-capable.
    /// Safe to call from any thread; idempotent.
    public func register(system: SystemIdentifier) {
        lock.lock(); defer { lock.unlock() }
        _systems.insert(system)
    }

    /// Register a set of system identifiers as MIDI-capable.
    /// Safe to call from any thread; idempotent.
    public func register(systems: Set<SystemIdentifier>) {
        lock.lock(); defer { lock.unlock() }
        _systems.formUnion(systems)
    }

    /// Convenience: pull supported systems from a `MIDISystemsProvider`
    /// core class and register them all.
    ///
    /// Call once per core class during app startup or core initialisation:
    /// ```swift
    /// MIDISystemRegistry.shared.registerProvider(PVAtariSTCore.self)
    /// ```
    public func registerProvider(_ provider: MIDISystemsProvider.Type) {
        register(systems: provider.midiSupportedSystemIdentifiers)
    }

    // MARK: Query

    /// Returns `true` if *any* registered core or the built-in baseline
    /// indicates MIDI support for `system`.
    public func supportsMIDI(_ system: SystemIdentifier) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _systems.contains(system)
    }

    /// A snapshot of all currently registered MIDI-capable system identifiers.
    public var registeredSystems: Set<SystemIdentifier> {
        lock.lock(); defer { lock.unlock() }
        return _systems
    }

    // MARK: Testing

    /// Replaces the entire registry with the given set.  **For unit tests only.**
    func _reset(to systems: Set<SystemIdentifier> = []) {
        lock.lock(); defer { lock.unlock() }
        _systems = systems
    }
}

// MARK: - SystemIdentifier extension

public extension SystemIdentifier {
    /// Returns `true` when the `MIDISystemRegistry` baseline or any registered
    /// core indicates this system supports MIDI peripherals.
    var supportsMIDI: Bool {
        MIDISystemRegistry.shared.supportsMIDI(self)
    }
}
