//
//  ControllerMapping.swift
//  PVCoreBridge
//
//  Shared data model for hardware controller button remapping. Lives in
//  PVCoreBridge (Tier 4) so every input consumer — PVRemappableController
//  (PVUIBase, Tier 6), the thin libretro frontend (PVCoreBridgeRetro,
//  Tier 5), the thick RetroArch wrapper, and any future native-core
//  bridge — can read from the same source of truth.
//
//  Storage format is intentionally identical to the legacy format that
//  shipped with PVRemappableController so existing saved mappings carry
//  over without a migration step:
//
//      Key: "PVControllerMappings_<vendorName>"
//      Value: JSON-encoded `[ButtonIdentifier.rawValue: {sourceId, destinationId}]`
//
//  ObjC consumers (the thick wrapper bindControls block) call
//  ``ControllerMappingStore.objcDestinationButton(forSource:vendor:)`` to
//  resolve a source identifier to its destination raw value without
//  having to parse the JSON themselves.
//

import Foundation
#if canImport(GameController)
import GameController
#endif

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
/// so per-frame lookups (thin/thick libretro polls) stay cheap.
///
/// Vendor key is `GCController.vendorName ?? "unknown"`. The store does
/// not know about specific controllers — callers pass the vendor string.
public final class ControllerMappingStore: @unchecked Sendable {

    public static let shared = ControllerMappingStore()

    // MARK: State

    private let lock = NSLock()
    private var cache: [String: [ButtonIdentifier: ButtonMapping]] = [:]
    private var observerInstalled = false

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
        lock.lock(); defer { lock.unlock() }
        installObserverIfNeeded_locked()
        if let cached = cache[vendor] { return cached }
        let result = loadFromDefaults(vendor: vendor)
        cache[vendor] = result
        return result
    }

    /// Resolve a source identifier to its destination, applying the
    /// user's swap. Returns `source` unchanged when no mapping is stored
    /// (identity).
    public func destination(forSource source: ButtonIdentifier,
                            vendor: String) -> ButtonIdentifier {
        let map = mappings(forVendor: vendor)
        return map[source]?.destinationId ?? source
    }

    // MARK: Write

    /// Replace the entire mapping table for `vendor` and persist.
    public func setMappings(_ mappings: [ButtonIdentifier: ButtonMapping],
                            forVendor vendor: String) {
        lock.lock()
        cache[vendor] = mappings
        lock.unlock()
        saveToDefaults(mappings: mappings, vendor: vendor)
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
        lock.lock()
        cache[vendor] = [:]
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: Self.storageKey(forVendor: vendor))
    }

    // MARK: - Internal helpers

    private func loadFromDefaults(vendor: String) -> [ButtonIdentifier: ButtonMapping] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey(forVendor: vendor)),
              let decoded = try? JSONDecoder().decode([ButtonIdentifier: ButtonMapping].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveToDefaults(mappings: [ButtonIdentifier: ButtonMapping],
                                vendor: String) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey(forVendor: vendor))
    }

    private func installObserverIfNeeded_locked() {
        guard !observerInstalled else { return }
        observerInstalled = true
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            // Drop everything — cheap to refill on next read and saves us
            // from tracking which vendor changed.
            self.cache.removeAll()
            self.lock.unlock()
        }
    }
}

// MARK: - Objective-C Bridge

/// ObjC-callable shim for thick-wrapper `bindControls` (ObjC++ block
/// captures don't tolerate Swift dictionary types). Returns the raw
/// string identifier of the destination button for a given source on a
/// given vendor; ObjC switches on the string to grab the right
/// `GCControllerButtonInput` on its virtual target.
@objc(PVControllerMappingStore)
public final class ControllerMappingStoreObjC: NSObject {

    @objc(destinationIdentifierForSource:vendor:)
    public static func destinationIdentifier(forSource source: String,
                                             vendor: String) -> String {
        guard let id = ButtonIdentifier(rawValue: source) else { return source }
        return ControllerMappingStore.shared
            .destination(forSource: id, vendor: vendor)
            .rawValue
    }

    /// Convenience for ObjC callers that already have a `GCController` in
    /// hand — extracts `vendorName ?? "unknown"` so the call site doesn't
    /// have to repeat the fallback string.
    #if canImport(GameController)
    @objc(destinationIdentifierForSource:controller:)
    public static func destinationIdentifier(forSource source: String,
                                             controller: GCController) -> String {
        return destinationIdentifier(forSource: source,
                                     vendor: controller.vendorName ?? "unknown")
    }
    #endif
}
