//
//  PVRemappableController+Profiles.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2/28/2026.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
import PVLogging
import PVRealm

// MARK: - Realm-backed profile persistence

public extension PVRemappableController {

    // MARK: Apply profile

    /// Apply all button remappings from a persisted `PVControllerProfile`.
    ///
    /// Clears any previously-active mappings first, then applies the profile's
    /// mappings and re-saves via UserDefaults so the remapping system picks them up.
    ///
    /// **Must be called on the main actor** — this method mutates in-memory controller
    /// state and reads Realm objects, both of which require a consistent thread.
    ///
    /// - Important: `profile` must be a *frozen* `PVControllerProfile` instance. Call
    ///   `profile.freeze()` on the creating thread/actor before passing it here.
    @MainActor public func apply(profile: PVControllerProfile) {
        precondition(profile.isFrozen, "PVRemappableController.apply(profile:) requires a frozen PVControllerProfile")

        let profileName = profile.name
        // Snapshot the raw mapping values before clearing so we don't lose them.
        let rawMappings: [(source: String, destination: String)] = profile.mappings.map {
            (source: $0.sourceButton, destination: $0.destinationButton)
        }

        clearAllMappings()
        for raw in rawMappings {
            guard
                let source = ButtonIdentifier(rawValue: raw.source),
                let destination = ButtonIdentifier(rawValue: raw.destination)
            else {
                WLOG("Skipping unknown button mapping: \(raw.source) → \(raw.destination)")
                continue
            }
            // Self-mappings are effectively no-ops but can cause handlers to be invoked twice.
            if source == destination {
                VLOG("Skipping self-mapping for button \(source)")
                continue
            }
            remap(button: source, to: destination)
        }
        // Persist via UserDefaults for the remapping system
        saveMappings()
        ILOG("Applied controller profile '\(profileName)' (\(rawMappings.count) mappings)")
    }

    // MARK: Save current mappings as a profile

    /// Save the controller's current in-memory button mappings to Realm as a new named profile.
    ///
    /// - Parameters:
    ///   - name: Human-readable profile name.
    ///   - systemIdentifier: Optional system scope (nil = applies to all systems).
    ///   - coreIdentifier: Optional core scope (nil = applies to all cores in scope).
    ///   - gameID: Optional game MD5 scope (nil = applies to all games).
    ///   - makeActive: If `true`, immediately activates the new profile.
    /// - Returns: The persisted `PVControllerProfile`, or `nil` if persistence failed.
    @discardableResult @MainActor public func saveCurrentMappingsAsProfile(
        name: String,
        systemIdentifier: String? = nil,
        coreIdentifier: String? = nil,
        gameID: String? = nil,
        makeActive: Bool = false
    ) -> PVControllerProfile? {
        guard let vendorName = self.vendorName else {
            ELOG("Cannot save profile: controller has no vendor name")
            return nil
        }

        let currentMappings = exportMappings()
        if currentMappings.isEmpty {
            WLOG("Saving empty controller profile '\(name)' (no custom mappings; acts as a defaults override for this scope)")
        }

        let db = RomDatabase.sharedInstance
        do {
            let profile = try db.addControllerProfile(
                name: name,
                controllerVendorName: vendorName,
                systemIdentifier: systemIdentifier,
                coreIdentifier: coreIdentifier,
                gameID: gameID,
                mappings: currentMappings
            )
            if makeActive {
                try db.activateControllerProfile(profile)
            }
            ILOG("Saved \(currentMappings.count) mappings as profile '\(name)'")
            return profile
        } catch {
            ELOG("Failed to save controller profile '\(name)': \(error)")
            return nil
        }
    }

    // MARK: Load active profile from Realm

    /// Load and apply the active Realm profile for this controller.
    ///
    /// Looks up the best matching active profile using the resolution order:
    /// game+core > game > system+core > system > global.
    /// Falls back to UserDefaults-based mappings if no profile is found.
    ///
    /// **Must be called on the main actor** — reads Realm objects and mutates
    /// in-memory controller state.
    ///
    /// - Parameters:
    ///   - systemIdentifier: Current system identifier (optional).
    ///   - coreIdentifier: Current emulator core identifier (optional).
    ///   - gameID: Current game MD5 hash (optional).
    @MainActor public func loadActiveProfile(systemIdentifier: String? = nil, coreIdentifier: String? = nil, gameID: String? = nil) {
        guard let vendorName = self.vendorName else { return }

        let db = RomDatabase.sharedInstance
        guard let profile = db.activeControllerProfile(
            forVendor: vendorName,
            systemIdentifier: systemIdentifier,
            coreIdentifier: coreIdentifier,
            gameID: gameID
        ) else {
            // No Realm profile — keep UserDefaults-loaded mappings
            DLOG("No active Realm profile for '\(vendorName)'; using UserDefaults mappings")
            return
        }

        apply(profile: profile.freeze())
    }

    // MARK: - Private helpers

    /// Export current in-memory mappings as (source, destination) string tuples.
    private func exportMappings() -> [(source: String, destination: String)] {
        var result: [(source: String, destination: String)] = []
        for id in ButtonIdentifier.allCases {
            if let destination = mappedButton(for: id) {
                result.append((source: id.rawValue, destination: destination.rawValue))
            }
        }
        return result
    }
}
