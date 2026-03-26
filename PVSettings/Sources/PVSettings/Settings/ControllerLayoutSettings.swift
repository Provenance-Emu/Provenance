//
//  ControllerLayoutSettings.swift
//  PVSettings
//
//  Per-system controller layout variant preference.
//  Persists the user's chosen layout (e.g. "6-Button Pad" for Genesis)
//  keyed by SystemIdentifier.rawValue.
//

import Foundation
@_exported import Defaults

// MARK: - Defaults Keys

public extension Defaults.Keys {

    /// Per-system controller layout variant selection.
    ///
    /// - Key: `SystemIdentifier.rawValue` string (e.g. `"com.provenance.genesis"`)
    /// - Value: `ControllerLayoutVariant.id` string (e.g. `"genesis-6btn"`)
    ///
    /// Only systems where the user has explicitly chosen a non-default variant
    /// are stored here; if a system is absent, the default (first) variant applies.
    static let controllerLayoutVariantsBySystem =
        Key<[String: String]>("controllerLayoutVariantsBySystem", default: [:])
}

// MARK: - Helpers

public extension Defaults {

    /// Returns the selected controller layout variant ID for the given system identifier.
    ///
    /// - Parameter systemID: The system's raw identifier string (e.g. `"com.provenance.genesis"`).
    /// - Returns: The stored variant ID, or `nil` if no override has been set (use system default).
    static func controllerLayoutVariant(forSystemID systemID: String) -> String? {
        guard !systemID.isEmpty else { return nil }
        return Defaults[.controllerLayoutVariantsBySystem][systemID]
    }

    /// Sets the selected controller layout variant for the given system identifier.
    ///
    /// Pass `nil` to remove the override and revert to the system default.
    ///
    /// - Parameters:
    ///   - variantID: The `ControllerLayoutVariant.id` to store, or `nil` to clear.
    ///   - systemID: The system's raw identifier string.
    static func setControllerLayoutVariant(_ variantID: String?, forSystemID systemID: String) {
        guard !systemID.isEmpty else { return }
        if let variantID {
            Defaults[.controllerLayoutVariantsBySystem][systemID] = variantID
        } else {
            Defaults[.controllerLayoutVariantsBySystem].removeValue(forKey: systemID)
        }
    }
}
