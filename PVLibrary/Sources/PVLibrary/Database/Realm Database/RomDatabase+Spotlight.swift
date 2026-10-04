//
//  RomDatabase+Spotlight.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//


// MARK: - Spotlight

#if canImport(CoreSpotlight) && !os(tvOS)
import PVRealm
import PVLogging
import CoreSpotlight

extension RomDatabase {
    internal func deleteFromSpotlight(game: PVGame) {
        deleteFromSpotlight(spotlightIdentifier: game.spotlightUniqueIdentifier)
    }

    /// For a game already deleted from Realm, whose properties can no longer be read.
    internal func deleteFromSpotlight(spotlightIdentifier: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [spotlightIdentifier], completionHandler: { error in
            if let error = error {
                ELOG("Error deleting game spotlight item: \(error)")
            } else {
                ILOG("Game indexing deleted.")
            }
        })
    }

    internal func deleteAllGamesFromSpotlight() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                ELOG("Error deleting all games spotlight index: \(error)")
            } else {
                ILOG("Game indexing deleted.")
            }
        }
    }
}
#endif
