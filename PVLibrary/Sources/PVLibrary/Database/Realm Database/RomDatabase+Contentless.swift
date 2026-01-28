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
    /// Guard flag to prevent concurrent execution of addContentlessCores
    @MainActor
    private static var isAddingContentlessCores = false

    /// Clears all contentless PVGame entries from the database
    @MainActor
    static func clearContentlessCores() async throws {
        let realm = try await Realm()

        let existingContentlessGames = realm.objects(PVGame.self).filter("contentless == true")
        ILOG("Removing \(existingContentlessGames.count) existing contentless PVGames")

        try await realm.asyncWrite {
            realm.delete(existingContentlessGames)
        }
    }

    /// Adds contentless PVGame entries for cores that support running without ROM files
    /// Uses atomic transactions and upsert to prevent race condition crashes
    @MainActor
    static func addContentlessCores(overwrite: Bool = false) async throws {
        /// Prevent concurrent execution to avoid race conditions
        guard !isAddingContentlessCores else {
            WLOG("addContentlessCores already in progress, skipping duplicate call")
            return
        }
        isAddingContentlessCores = true
        defer { isAddingContentlessCores = false }

        let realm = try await Realm()

        /// Get all contentless cores
        let contentlessCores = realm.objects(PVCore.self).filter("contentless == true")
        ILOG("Found \(contentlessCores.count) contentless cores: \(contentlessCores.map(\.identifier).joined(separator: ", "))")

        /// Create array to hold new games that need to be added
        var gamesToAdd: [PVGame] = []

        /// For each contentless core, check if we need to create a game
        for core in contentlessCores {
            /// Skip if game already exists and we're not overwriting
            if !overwrite {
                if let _ = realm.object(ofType: PVGame.self, forPrimaryKey: core.identifier) {
                    ILOG("Found existing contentless PVGame for identifier \(core.identifier), skipping")
                    continue
                }
            }

            /// Generate a new contentless game for this core
            let game = PVGame.contentlessGenerate(core: core)
            gamesToAdd.append(game)
            ILOG("Game to add: \(game.title)")
        }

        /// Perform clear and add in a single atomic transaction to prevent race conditions
        if !gamesToAdd.isEmpty || overwrite {
            WLOG("Processing \(gamesToAdd.count) contentless PVGame(s) (overwrite: \(overwrite))...")

            try await realm.asyncWrite {
                /// Delete existing contentless games if overwriting (within same transaction)
                if overwrite {
                    let existingContentlessGames = realm.objects(PVGame.self).filter("contentless == true")
                    ILOG("Deleting \(existingContentlessGames.count) existing contentless games in atomic transaction")
                    realm.delete(existingContentlessGames)
                }

                /// Add games with .modified policy to upsert on primary key collision
                for game in gamesToAdd {
                    realm.add(game, update: .modified)
                }
            }
            ILOG("Successfully processed contentless PVGames")
        } else {
            WLOG("No contentless cores found to add PVGame's for.")
        }
    }
}
