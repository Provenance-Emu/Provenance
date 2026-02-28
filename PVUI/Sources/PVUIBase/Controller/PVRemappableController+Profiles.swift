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
    func apply(profile: PVControllerProfile) {
        clearAllMappings()
        for mapping in profile.mappings {
            guard
                let source = ButtonIdentifier(rawValue: mapping.sourceButton),
                let destination = ButtonIdentifier(rawValue: mapping.destinationButton)
            else {
                WLOG("Skipping unknown button mapping: \(mapping.sourceButton) → \(mapping.destinationButton)")
                continue
            }
            remap(button: source, to: destination)
        }
        // Persist via UserDefaults for the remapping system
        saveMappings()
        ILOG("Applied controller profile '\(profile.name)' (\(profile.mappings.count) mappings)")
    }

    // MARK: Save current mappings as a profile

    /// Save the controller's current in-memory button mappings to Realm as a new named profile.
    ///
    /// - Parameters:
    ///   - name: Human-readable profile name.
    ///   - systemIdentifier: Optional system scope (nil = applies to all systems).
    ///   - gameID: Optional game MD5 scope (nil = applies to all games).
    ///   - makeActive: If `true`, immediately activates the new profile.
    /// - Returns: The persisted `PVControllerProfile`, or `nil` if persistence failed.
    @discardableResult
    func saveCurrentMappingsAsProfile(
        name: String,
        systemIdentifier: String? = nil,
        gameID: String? = nil,
        makeActive: Bool = false
    ) -> PVControllerProfile? {
        guard let vendorName = self.vendorName else {
            ELOG("Cannot save profile: controller has no vendor name")
            return nil
        }

        let currentMappings = exportMappings()
        guard !currentMappings.isEmpty else {
            WLOG("No mappings to save for profile '\(name)'")
            return nil
        }

        let db = RomDatabase.sharedInstance
        do {
            let profile = try db.addControllerProfile(
                name: name,
                controllerVendorName: vendorName,
                systemIdentifier: systemIdentifier,
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
    /// Looks up the best matching active profile (game > system > global).
    /// Falls back to UserDefaults-based mappings if no profile is found.
    ///
    /// - Parameters:
    ///   - systemIdentifier: Current system identifier (optional).
    ///   - gameID: Current game MD5 hash (optional).
    func loadActiveProfile(systemIdentifier: String? = nil, gameID: String? = nil) {
        guard let vendorName = self.vendorName else { return }

        let db = RomDatabase.sharedInstance
        guard let profile = db.activeControllerProfile(
            forVendor: vendorName,
            systemIdentifier: systemIdentifier,
            gameID: gameID
        ) else {
            // No Realm profile — keep UserDefaults-loaded mappings
            DLOG("No active Realm profile for '\(vendorName)'; using UserDefaults mappings")
            return
        }

        apply(profile: profile)
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

// ButtonIdentifier must conform to CaseIterable so we can enumerate all cases.
extension ButtonIdentifier: CaseIterable {
    public static var allCases: [ButtonIdentifier] {
        [
            .buttonA, .buttonB, .buttonX, .buttonY,
            .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .menu, .options, .home,
            .leftThumbstickButton, .rightThumbstickButton, .share,
            .touchpad, .touchpadButton, .micButton, .createButton,
            .paddleOne, .paddleTwo, .paddleThree, .paddleFour, .shareButton,
            .capture, .plusButton, .minusButton, .leftSL, .leftSR, .rightSL, .rightSR
        ]
    }
}
