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

    /// Active profile for a given controller, optionally scoped to a system, core, and game.
    /// Resolution order:
    ///   1. Game + Core-specific (gameID + coreIdentifier)
    ///   2. Game-specific (gameID only)
    ///   3. System + Core-specific (systemIdentifier + coreIdentifier)
    ///   4. System-specific (systemIdentifier only)
    ///   5. Global controller default.
    func activeControllerProfile(
        forVendor vendorName: String,
        systemIdentifier: String? = nil,
        coreIdentifier: String? = nil,
        gameID: String? = nil
    ) -> PVControllerProfile? {
        let allProfiles = realm.objects(PVControllerProfile.self)
            .filter("controllerVendorName == %@ AND isActive == true", vendorName)

        // 1. Game + Core-specific match
        if let gameID, let coreIdentifier {
            let predicate: String
            var args: [Any] = [gameID, coreIdentifier]
            if let systemIdentifier {
                predicate = "gameID == %@ AND coreIdentifier == %@ AND (systemIdentifier == nil OR systemIdentifier == %@)"
                args.append(systemIdentifier)
            } else {
                predicate = "gameID == %@ AND coreIdentifier == %@ AND systemIdentifier == nil"
            }
            if let profile = allProfiles.filter(predicate, argumentArray: args).first {
                return profile
            }
        }

        // 2. Game-specific match (any core)
        if let gameID {
            let predicate: String
            var args: [Any] = [gameID]
            if let systemIdentifier {
                predicate = "gameID == %@ AND coreIdentifier == nil AND (systemIdentifier == nil OR systemIdentifier == %@)"
                args.append(systemIdentifier)
            } else {
                predicate = "gameID == %@ AND coreIdentifier == nil AND systemIdentifier == nil"
            }
            if let profile = allProfiles.filter(predicate, argumentArray: args).first {
                return profile
            }
        }

        // 3. System + Core-specific match
        if let systemIdentifier, let coreIdentifier {
            if let profile = allProfiles
                .filter("systemIdentifier == %@ AND coreIdentifier == %@ AND gameID == nil", systemIdentifier, coreIdentifier)
                .first {
                return profile
            }
        }

        // 4. System-specific match (any core)
        if let systemIdentifier {
            if let profile = allProfiles
                .filter("systemIdentifier == %@ AND coreIdentifier == nil AND gameID == nil", systemIdentifier)
                .first {
                return profile
            }
        }

        // 5. Global controller default
        return allProfiles
            .filter("systemIdentifier == nil AND coreIdentifier == nil AND gameID == nil")
            .first
    }

    // MARK: - Create

    /// Create and persist a new controller profile.
    @discardableResult
    func addControllerProfile(
        name: String,
        controllerVendorName: String,
        systemIdentifier: String? = nil,
        coreIdentifier: String? = nil,
        gameID: String? = nil,
        mappings: [(source: String, destination: String)] = []
    ) throws -> PVControllerProfile {
        let profile = PVControllerProfile(
            name: name,
            controllerVendorName: controllerVendorName,
            systemIdentifier: systemIdentifier,
            coreIdentifier: coreIdentifier,
            gameID: gameID
        )
        try realm.write {
            realm.add(profile)
            let realmMappings = mappings.map { PVControllerMapping(source: $0.source, destination: $0.destination) }
            profile.mappings.append(objectsIn: realmMappings)
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
    /// (vendor, system, core, game) combination first.
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

        if let coreID = profile.coreIdentifier {
            format += " AND coreIdentifier == %@"
            args.append(coreID)
        } else {
            format += " AND coreIdentifier == nil"
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
