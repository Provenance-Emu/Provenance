//
//  PVAppDelegate+AppIntents.swift
//  Provenance
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Processes pending work queued by PVAppIntents extension processes
//  (Siri, Shortcuts, Widgets) via the shared App Group UserDefaults.
//
//  Called from `ProvenanceApp.onChange(of: scenePhase)` when `.active`,
//  keeping the logic out of the UIApplicationDelegate lifecycle.
//

import Foundation
import PVLibrary
import PVLogging
import PVUIBase

#if canImport(PVAppIntents)
import PVAppIntents
#endif

// MARK: - Scene-phase handler

/// Drains any intent side-effects queued in the App Group UserDefaults by
/// `LaunchGameIntent` and `ToggleFavoriteIntent` while the app was inactive,
/// then refreshes widget timelines.
///
/// Call this from the SwiftUI scene `onChange(of: scenePhase)` `.active` branch.
@MainActor
public func processPendingAppIntents() {
    guard let defaults = UserDefaults(suiteName: PVAppGroupId) else { return }
    processPendingLaunch(from: defaults)
    processPendingFavorites(from: defaults)
#if canImport(PVAppIntents)
    WidgetDataWriter.shared.writeFromRealm()
#endif
}

// MARK: - Private helpers

/// Routes `pendingLaunchGameID` → `AppState.appOpenAction`, then clears the key.
@MainActor
private func processPendingLaunch(from defaults: UserDefaults) {
    guard let md5 = defaults.string(forKey: "pendingLaunchGameID") else { return }
    defaults.removeObject(forKey: "pendingLaunchGameID")
    ILOG("processPendingAppIntents: routing to game MD5 \(md5)")
    let realm = RomDatabase.sharedInstance.realm
    if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) {
        AppState.shared.appOpenAction = .openGame(game)
    } else {
        AppState.shared.appOpenAction = .openMD5(md5)
    }
}

/// Applies `pendingFavorite_<md5>` keys to Realm, then removes them.
@MainActor
private func processPendingFavorites(from defaults: UserDefaults) {
    let prefix = "pendingFavorite_"
    let pendingKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
    guard !pendingKeys.isEmpty else { return }

    let database = RomDatabase.sharedInstance
    for key in pendingKeys {
        let md5 = String(key.dropFirst(prefix.count))
        let isFavorite = defaults.bool(forKey: key)
        defaults.removeObject(forKey: key)

        let realm = database.realm
        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
            WLOG("processPendingAppIntents: no game found for favourite key \(key)")
            continue
        }
        do {
            try database.writeTransaction {
                game.isFavorite = isFavorite
            }
            ILOG("processPendingAppIntents: set isFavorite=\(isFavorite) for \(game.title)")
        } catch {
            ELOG("processPendingAppIntents: failed to write favourite for \(key): \(error)")
        }
    }
}
