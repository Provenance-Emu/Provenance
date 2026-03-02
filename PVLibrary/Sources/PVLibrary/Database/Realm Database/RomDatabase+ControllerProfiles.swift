//
//  RomDatabase+ControllerProfiles.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 2/28/2026.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVRealm
import RealmSwift

public extension RomDatabase {

    // MARK: - Fetch

    /// All profiles for a given controller vendor name, ordered by name.
    func controllerProfiles(forVendor vendorName: String) -> Results<PVControllerProfile> {
        realm.objects(PVControllerProfile.self)
            .filter("controllerVendorName == %@", vendorName)
            .sorted(byKeyPath: "name", ascending: true)
    }

    /// Active profile for a given controller, optionally scoped to a system and game.
    /// Resolution order: game-specific → system-specific → global controller default.
    func activeControllerProfile(
        forVendor vendorName: String,
        systemIdentifier: String? = nil,
        gameID: String? = nil
    ) -> PVControllerProfile? {
        let allProfiles = realm.objects(PVControllerProfile.self)
            .filter("controllerVendorName == %@ AND isActive == true", vendorName)

        // 1. Game-specific match
        if let gameID {
            if let profile = allProfiles
                .filter("gameID == %@", gameID)
                .first {
                return profile
            }
        }

        // 2. System-specific match
        if let systemIdentifier {
            if let profile = allProfiles
                .filter("systemIdentifier == %@ AND gameID == nil", systemIdentifier)
                .first {
                return profile
            }
        }

        // 3. Global controller default
        return allProfiles
            .filter("systemIdentifier == nil AND gameID == nil")
            .first
    }

    // MARK: - Create

    /// Create and persist a new controller profile.
    @discardableResult
    func addControllerProfile(
        name: String,
        controllerVendorName: String,
        systemIdentifier: String? = nil,
        gameID: String? = nil,
        mappings: [(source: String, destination: String)] = []
    ) throws -> PVControllerProfile {
        let profile = PVControllerProfile(
            name: name,
            controllerVendorName: controllerVendorName,
            systemIdentifier: systemIdentifier,
            gameID: gameID
        )
        let realmMappings = mappings.map { PVControllerMapping(source: $0.source, destination: $0.destination) }
        profile.mappings.append(objectsIn: realmMappings)

        try realm.write {
            realm.add(profile)
        }
        return profile
    }

    // MARK: - Update

    /// Replace all mappings in a profile with the given list.
    func updateControllerProfile(_ profile: PVControllerProfile, mappings: [(source: String, destination: String)]) throws {
        try realm.write {
            profile.mappings.removeAll()
            let realmMappings = mappings.map { PVControllerMapping(source: $0.source, destination: $0.destination) }
            profile.mappings.append(objectsIn: realmMappings)
            profile.lastModifiedDate = Date()
        }
    }

    /// Rename an existing profile.
    func renameControllerProfile(_ profile: PVControllerProfile, to newName: String) throws {
        try realm.write {
            profile.name = newName
            profile.lastModifiedDate = Date()
        }
    }

    // MARK: - Activation

    /// Activate a profile, deactivating any other active profile for the same
    /// (vendor, system, game) combination first.
    func activateControllerProfile(_ profile: PVControllerProfile) throws {
        // Build a nil-safe predicate for scope matching.
        // Passing `nil as Any` through `%@` in NSPredicate does not reliably produce
        // a `== nil` (NULL) comparison in Realm — build the predicate string dynamically instead.
        var format = "controllerVendorName == %@ AND isActive == true"
        var args: [Any] = [profile.controllerVendorName]

        if let systemID = profile.systemIdentifier {
            format += " AND systemIdentifier == %@"
            args.append(systemID)
        } else {
            format += " AND systemIdentifier == nil"
        }

        if let gameID = profile.gameID {
            format += " AND gameID == %@"
            args.append(gameID)
        } else {
            format += " AND gameID == nil"
        }

        let existing = realm.objects(PVControllerProfile.self)
            .filter(NSPredicate(format: format, argumentArray: args))

        try realm.write {
            for p in existing { p.isActive = false }
            profile.isActive = true
            profile.lastModifiedDate = Date()
        }
    }

    /// Deactivate a profile.
    func deactivateControllerProfile(_ profile: PVControllerProfile) throws {
        try realm.write {
            profile.isActive = false
            profile.lastModifiedDate = Date()
        }
    }

    // MARK: - Delete

    func deleteControllerProfile(_ profile: PVControllerProfile) throws {
        try realm.write {
            realm.delete(profile)
        }
    }
}
