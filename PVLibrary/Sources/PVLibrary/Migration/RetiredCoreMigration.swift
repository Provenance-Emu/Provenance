//
//  RetiredCoreMigration.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Moves everything that points at a retired core (`PVCore.activeRetiredCoreReplacements`)
//  over to its replacement: save states, recently played entries, and per-game /
//  per-system core preferences. The retired core's row is kept but marked
//  disabled, so it only shows up with "unsupported cores" turned on.
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

    /// Repoints records from each retired core to its replacement. Must be called
    /// inside a write transaction. A pair is skipped while its replacement core
    /// isn't registered, so nothing is left pointing at a missing core.
    @discardableResult
    static func migrate(in realm: Realm,
                        replacements: [String: String] = PVCore.activeRetiredCoreReplacements) -> Result {
        var result = Result()
        for (retiredID, replacementID) in replacements {
            guard let replacement = realm.object(ofType: PVCore.self, forPrimaryKey: replacementID) else {
                WLOG("RetiredCoreMigration: \(replacementID) isn't registered; leaving \(retiredID) records for now")
                continue
            }
            let before = result

            for state in Array(realm.objects(PVSaveState.self).filter("core.identifier == %@", retiredID)) {
                state.core = replacement
                // The version was the retired core's; keeping it would warn about
                // a version mismatch on every load.
                state.createdWithCoreVersion = replacement.projectVersion
                result.saveStates += 1
            }
            for recent in Array(realm.objects(PVRecentGame.self).filter("core.identifier == %@", retiredID)) {
                recent.core = replacement
                result.recentGames += 1
            }
            for game in Array(realm.objects(PVGame.self).filter("userPreferredCoreID == %@", retiredID)) {
                game.userPreferredCoreID = replacementID
                result.gamePreferences += 1
            }
            for system in Array(realm.objects(PVSystem.self).filter("userPreferredCoreID == %@", retiredID)) {
                system.userPreferredCoreID = replacementID
                result.systemPreferences += 1
            }

            if let retired = realm.object(ofType: PVCore.self, forPrimaryKey: retiredID), !retired.disabled {
                retired.disabled = true
            }

            if result != before {
                ILOG("RetiredCoreMigration: \(retiredID) → \(replacementID): \(result)")
            }
        }
        return result
    }
}
