//
//  RetiredCoreMigration.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Moves what points at a retired core (`PVCore.activeRetiredCores`) over to its
//  replacement for that game's system: recently played entries, per-game and per-system
//  core preferences, and save states when the formats are compatible. The retired
//  core's row is kept but marked disabled, so it only shows up with "unsupported cores"
//  turned on and unmigrated save states still name a core. Battery files are moved
//  separately (RetiredBatterySaveMigration), outside the Realm write.
//
//  Runs on every core registration; once nothing points at a retired core it is
//  a handful of empty queries.
//

import Foundation
import RealmSwift
import PVLogging
import PVRealm

enum RetiredCoreMigration {

    struct Result: Equatable {
        var saveStates = 0
        var recentGames = 0
        var gamePreferences = 0
        var systemPreferences = 0
    }

    /// Repoints records from each retired core to its replacements. Must be called
    /// inside a write transaction. A retired core is skipped while any of its
    /// replacements isn't registered, so nothing is left pointing at a missing core.
    @discardableResult
    static func migrate(in realm: Realm,
                        retiredCores: [String: RetiredCore] = PVCore.activeRetiredCores) -> Result {
        var result = Result()
        for (retiredID, retired) in retiredCores.sorted(by: { $0.key < $1.key }) {
            let missing = retired.allReplacements.filter { realm.object(ofType: PVCore.self, forPrimaryKey: $0) == nil }
            guard missing.isEmpty else {
                WLOG("RetiredCoreMigration: \(missing.joined(separator: ", ")) not registered; leaving \(retiredID) records for now")
                continue
            }
            func replacementCore(forSystem systemIdentifier: String?) -> PVCore? {
                realm.object(ofType: PVCore.self, forPrimaryKey: retired.replacement(forSystem: systemIdentifier))
            }
            let before = result

            if retired.migratesSaveStates {
                for state in Array(realm.objects(PVSaveState.self).filter("core.identifier == %@", retiredID)) {
                    guard let replacement = replacementCore(forSystem: state.game?.systemIdentifier) else { continue }
                    state.core = replacement
                    // The version was the retired core's; keeping it would warn about
                    // a version mismatch on every load.
                    state.createdWithCoreVersion = replacement.projectVersion
                    result.saveStates += 1
                }
            }
            for recent in Array(realm.objects(PVRecentGame.self).filter("core.identifier == %@", retiredID)) {
                recent.core = replacementCore(forSystem: recent.game?.systemIdentifier)
                result.recentGames += 1
            }
            for game in Array(realm.objects(PVGame.self).filter("userPreferredCoreID == %@", retiredID)) {
                game.userPreferredCoreID = retired.replacement(forSystem: game.systemIdentifier)
                result.gamePreferences += 1
            }
            for system in Array(realm.objects(PVSystem.self).filter("userPreferredCoreID == %@", retiredID)) {
                system.userPreferredCoreID = retired.replacement(forSystem: system.identifier)
                result.systemPreferences += 1
            }

            if let core = realm.object(ofType: PVCore.self, forPrimaryKey: retiredID), !core.disabled {
                core.disabled = true
            }

            if result != before {
                ILOG("RetiredCoreMigration: \(retiredID) → \(retired.allReplacements.joined(separator: "/")): \(result)")
            }
        }
        return result
    }
}
