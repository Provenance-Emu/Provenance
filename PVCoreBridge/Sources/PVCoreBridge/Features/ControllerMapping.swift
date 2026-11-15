//
//  ControllerMapping.swift
//  PVCoreBridge
//
//  Shared data model for hardware controller button remapping. Lives in
//  PVCoreBridge (Tier 4) so every input consumer — PVRemappableController
//  (PVUIBase, Tier 6), the thin libretro frontend (PVCoreBridgeRetro,
//  Tier 5), and any native-core bridge — can read from the same source
//  of truth.
//
//  Storage format is intentionally identical to the legacy format that
//  shipped with PVRemappableController so existing saved mappings carry
//  over without a migration step:
//
//      Key: "PVControllerMappings_<vendorName>"
//      Value: JSON-encoded `[ButtonIdentifier.rawValue: {sourceId, destinationId}]`
//

import Foundation
import os

// MARK: - ButtonIdentifier

/// Identifies a controller button — both standard MFi buttons and the
/// platform-specific buttons (DualSense Create, DS4 Share, Xbox Share,
/// Switch Capture/+/-). Raw values are stable and persisted to
/// UserDefaults; do not rename existing cases without a migration.
public enum ButtonIdentifier: String, Codable, CaseIterable, Sendable {
    // Standard buttons
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case menu
    case options
    case home

    // Extended inputs
    case leftThumbstickButton
    case rightThumbstickButton
    case share

    // DualSense specific
    case touchpad
    case touchpadButton
    case micButton
    case createButton

    // Xbox specific
    case paddleOne
    case paddleTwo
    case paddleThree
    case paddleFour
    case shareButton

    // Switch Pro specific
    case capture
    case plusButton
    case minusButton
    case leftSL
    case leftSR
    case rightSL
    case rightSR
}

// MARK: - ButtonMapping

/// A single source-to-destination button swap.
public struct ButtonMapping: Codable, Equatable, Sendable {
    public let sourceId: ButtonIdentifier
    public let destinationId: ButtonIdentifier

    public init(source: ButtonIdentifier, destination: ButtonIdentifier) {
        self.sourceId = source
        self.destinationId = destination
    }
}

// MARK: - ControllerMappingStore

/// Thread-safe UserDefaults-backed store for controller button remaps.
/// Read paths are cached and invalidated via `UserDefaults.didChangeNotification`
/// so per-frame lookups (per-frame libretro polls) stay cheap.
///
/// Vendor key is `GCController.vendorName ?? "unknown"`. The store does
/// not know about specific controllers — callers pass the vendor string.
public final class ControllerMappingStore: Sendable {

    public static let shared = ControllerMappingStore()

    /// Posted after a vendor's mappings are written or cleared through this store.
    /// `PVEmulatorViewController` re-hands controllers to the running core on it, so a
    /// remap made mid-session reaches native cores (see ``PVRemappedController``).
    public static let didChangeNotification = Notification.Name("PVControllerMappingStoreDidChange")

    // MARK: State

    /// `UserDefaults` is thread-safe but not declared `Sendable`.
    private nonisolated(unsafe) let defaults: UserDefaults

    /// Lives inside the lock that guards it.
    private struct State: Sendable {
        var cache: [String: [ButtonIdentifier: ButtonMapping]] = [:]
        var observerInstalled = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// `defaults` is injectable for tests; the app uses ``shared`` (standard defaults).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Key

    /// Compose the UserDefaults key for a given vendor.
    public static func storageKey(forVendor vendor: String) -> String {
        return "PVControllerMappings_\(vendor)"
    }

    // MARK: Read

    /// Load the saved mapping dictionary for `vendor`. Returns `[:]` when
    /// no mappings are stored. Result is cached until the next
    /// UserDefaults change.
    public func mappings(forVendor vendor: String) -> [ButtonIdentifier: ButtonMapping] {
        // The load stays inside the lock: a load that finished after a newer write was cached
        // would put the old table back.
        state.withLock { state in
            if !state.observerInstalled {
                state.observerInstalled = true
                installObserver()
            }
            if let cached = state.cache[vendor] { return cached }
            let result = loadFromDefaults(vendor: vendor)
            state.cache[vendor] = result
            return result
        }
    }

    /// Resolve a source identifier to its destination, applying the
    /// user's swap. Returns `source` unchanged when no mapping is stored
    /// (identity).
    public func destination(forSource source: ButtonIdentifier,
                            vendor: String) -> ButtonIdentifier {
        let map = mappings(forVendor: vendor)
        return map[source]?.destinationId ?? source
    }

    /// True when `vendor` has at least one mapping that sends a button somewhere else.
    public func hasActiveRemaps(forVendor vendor: String) -> Bool {
        mappings(forVendor: vendor).values.contains { $0.sourceId != $0.destinationId }
    }

    // MARK: Write

    /// Replace the entire mapping table for `vendor` and persist.
    public func setMappings(_ mappings: [ButtonIdentifier: ButtonMapping],
                            forVendor vendor: String) {
        state.withLock { $0.cache[vendor] = mappings }
        // Saved outside the lock: saving posts the defaults notification, whose observer takes it.
        saveToDefaults(mappings: mappings, vendor: vendor)
        postDidChange(vendor: vendor)
    }

    /// Add or replace a single source→destination mapping.
    public func setMapping(source: ButtonIdentifier,
                           destination: ButtonIdentifier,
                           forVendor vendor: String) {
        var current = mappings(forVendor: vendor)
        current[source] = ButtonMapping(source: source, destination: destination)
        setMappings(current, forVendor: vendor)
    }

    /// Remove a single mapping if present.
    public func clearMapping(source: ButtonIdentifier, forVendor vendor: String) {
        var current = mappings(forVendor: vendor)
        guard current.removeValue(forKey: source) != nil else { return }
        setMappings(current, forVendor: vendor)
    }

    /// Drop every mapping for `vendor`.
    public func clearAll(forVendor vendor: String) {
        state.withLock { $0.cache[vendor] = [:] }
        defaults.removeObject(forKey: Self.storageKey(forVendor: vendor))
        postDidChange(vendor: vendor)
    }

    // MARK: - Internal helpers

    private func loadFromDefaults(vendor: String) -> [ButtonIdentifier: ButtonMapping] {
        guard let data = defaults.data(forKey: Self.storageKey(forVendor: vendor)),
              let decoded = try? JSONDecoder().decode([ButtonIdentifier: ButtonMapping].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveToDefaults(mappings: [ButtonIdentifier: ButtonMapping],
                                vendor: String) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        defaults.set(data, forKey: Self.storageKey(forVendor: vendor))
    }

    private func postDidChange(vendor: String) {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self,
                                        userInfo: [Self.vendorUserInfoKey: vendor])
    }

    /// `userInfo` key of ``didChangeNotification``: the vendor whose mappings changed.
    public static let vendorUserInfoKey = "vendor"

    /// Called once, with the lock held, before the first value is cached.
    private func installObserver() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: nil
        ) { [weak self] _ in
            // Drop everything — cheap to refill on next read and saves us
            // from tracking which vendor changed.
            self?.state.withLock { $0.cache.removeAll() }
        }
    }
}
