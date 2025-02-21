//
//  RomDatabase+Contentless.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 2/20/25.
//

import PVRealm
import Foundation
import PVLogging
import PVLookup
import PVSystems
import AsyncAlgorithms
import RealmSwift

public extension RomDatabase {
    @MainActor
    static func addContentlessCores(overwrite: Bool = false) async throws {
        /// Get the realm instance
        let realm = try await Realm()

        /// Get all contentless cores
        let contentlessCores = realm.objects(PVCore.self).filter("contentless == true")
        ILOG("Found \(contentlessCores.count) contentless cores: \(contentlessCores.map(\.identifier).joined(separator: ", "))")

        /// If overwriting, first delete all existing contentless games
        if overwrite {
            let existingContentlessGames = realm.objects(PVGame.self).filter("contentless == true")
            ILOG("Overwrite request: removing \(existingContentlessGames.count) existing contentless PVGames")
            try await realm.asyncWrite {
                realm.delete(existingContentlessGames)
            }
        }

        /// Create array to hold new games that need to be added
        var gamesToAdd: [PVGame] = []

        /// For each contentless core, check if we need to create a game
        for core in contentlessCores {
            /// Skip if game already exists and we're not overwriting
            if !overwrite {
                if let _ = realm.object(ofType: PVGame.self, forPrimaryKey: core.identifier) {
                    ILOG("Found exiting contentless PVGame for identifier \(core.identifier), skipping")
                    continue
                }
            }

            /// Generate a new contentless game for this core
            let game = PVGame.contentlessGenerate(core: core)
            gamesToAdd.append(game)
            ILOG("Game to add: \(game.title)")
        }

        /// Add all new games in a single transaction if we have any
        if !gamesToAdd.isEmpty {
            WLOG("Adding \(gamesToAdd.count) new contentless PVGame's...")

            try await realm.asyncWrite {
                realm.add(gamesToAdd)
            }
        } else {
            WLOG("No contentless cores found to add PVGame's for.")
        }
    }
}
