//
//  RealmProvider.swift
//  Provenance
//
//  Created by ChatGPT on 12/2/25.
//

import Foundation
import RealmSwift
import PVLogging

public enum RealmProvider {
    /// Ensures the shared Realm configuration is initialized before use
    @discardableResult
    public static func ensureInitialized() async throws -> Realm.Configuration {
        if !RomDatabase.databaseInitialized {
            ILOG("RealmProvider: Initializing default database before Realm access.")
            try await RomDatabase.initDefaultDatabase()
        }
        return Realm.Configuration.defaultConfiguration
    }

}
