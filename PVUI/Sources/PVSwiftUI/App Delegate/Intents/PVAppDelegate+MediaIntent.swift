//
//  PVAppDelegate+MediaIntent.swift
//  Provenance
//
//  Created by Joseph Mattiello
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adds SiriKit `INPlayMediaIntent` in-app handling so users can say
//  "Hey Siri, play Donkey Kong Country on Provenance" without needing
//  a separate Intents Extension target.
//

import Foundation
import Intents
import PVLogging
import PVLibrary
import PVRealm
import RealmSwift
import PVUIBase

#if os(iOS)
@available(iOS 14.0, *)
extension PVAppDelegate: INPlayMediaIntentHandling {

    // MARK: - Handle

    /// Routes the Siri media request to the matching game in the library.
    ///
    /// Siri populates `intent.mediaItems` from prior `INInteraction` donations.
    /// Each `INMediaItem.identifier` contains the game's MD5 hash; if absent,
    /// Siri may supply only a `title` from the user's utterance.
    public func handle(intent: INPlayMediaIntent,
                       completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        ILOG("PVAppDelegate+MediaIntent: handle(intent:) called")

        guard let mediaItems = intent.mediaItems, !mediaItems.isEmpty else {
            WLOG("PVAppDelegate+MediaIntent: no mediaItems in intent")
            completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let first = mediaItems[0]
        ILOG("PVAppDelegate+MediaIntent: mediaItem identifier=\(first.identifier ?? "nil") title=\(first.title ?? "nil")")

        // 1. Prefer identifier (MD5 hash) for an exact match.
        if let md5 = first.identifier, !md5.isEmpty,
           let game = fetchMediaGame(byMD5: md5) {
            launchMediaGame(game, md5: md5, completion: completion)
            return
        }

        // 2. Fall back to title-based search.
        if let title = first.title, !title.isEmpty {
            searchAndLaunchMedia(title: title, completion: completion)
            return
        }

        WLOG("PVAppDelegate+MediaIntent: mediaItem has neither identifier nor title")
        completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
    }

    // MARK: - Resolve

    /// Lets Siri confirm / disambiguate media items before calling `handle`.
    public func resolveMediaItems(
        for intent: INPlayMediaIntent,
        with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void
    ) {
        guard let mediaItems = intent.mediaItems, !mediaItems.isEmpty else {
            completion([INPlayMediaMediaItemResolutionResult.needsValue()])
            return
        }

        var results: [INPlayMediaMediaItemResolutionResult] = []

        for item in mediaItems {
            // If we have an MD5 identifier, validate it exists.
            if let md5 = item.identifier, !md5.isEmpty {
                if let game = fetchMediaGame(byMD5: md5) {
                    // Return a resolved item with the game's title so Siri can display it.
                    let resolved = INMediaItem(
                        identifier: md5,
                        title: game.title,
                        type: .game,
                        artwork: nil
                    )
                    results.append(.success(with: resolved))
                } else {
                    results.append(.unsupported())
                }
                continue
            }

            // Otherwise search by title.
            if let title = item.title, !title.isEmpty {
                let candidates = searchMediaGames(matchingTitle: title)
                switch candidates.count {
                case 0:
                    results.append(.unsupported())
                case 1:
                    let resolved = INMediaItem(
                        identifier: candidates[0].md5Hash,
                        title: candidates[0].title,
                        type: .game,
                        artwork: nil
                    )
                    results.append(.success(with: resolved))
                default:
                    // Multiple matches — let Siri show disambiguation UI.
                    let resolved = candidates.map {
                        INMediaItem(identifier: $0.md5Hash, title: $0.title, type: .game, artwork: nil)
                    }
                    results.append(.disambiguation(with: resolved))
                }
                continue
            }

            results.append(.needsValue())
        }

        completion(results)
    }

    // MARK: - Private helpers

    /// Thread-safe Realm lookup by MD5.
    /// Uses a fresh Realm instance (not @MainActor) so it is safe to call from SiriKit's background queue.
    /// Returns a frozen snapshot so callers can safely access properties after this function returns.
    private func fetchMediaGame(byMD5 md5: String) -> PVGame? {
        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)
            return realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())?.freeze()
        } catch {
            ELOG("PVAppDelegate+MediaIntent: Realm error fetching by MD5: \(error)")
            return nil
        }
    }

    private func launchMediaGame(
        _ game: PVGame,
        md5: String,
        completion: @escaping (INPlayMediaIntentResponse) -> Void
    ) {
        ILOG("PVAppDelegate+MediaIntent: launching '\(game.title)'")
        // Pass the MD5 string (Sendable) rather than the Realm object so we don't
        // cross thread boundaries with a live, thread-confined PVGame instance.
        // prepareGameForEmulatorScene() will re-fetch the game on the main thread.
        Task { @MainActor in
            AppState.shared.appOpenAction = .openMD5(md5)
        }
        let activity = NSUserActivity(activityType: "com.provenance.open-game")
        activity.userInfo = ["md5": md5]
        completion(INPlayMediaIntentResponse(code: .success, userActivity: activity))
    }

    private func searchAndLaunchMedia(
        title: String,
        completion: @escaping (INPlayMediaIntentResponse) -> Void
    ) {
        let candidates = searchMediaGames(matchingTitle: title)
        guard let game = candidates.first else {
            WLOG("PVAppDelegate+MediaIntent: no game found for title '\(title)'")
            completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }
        launchMediaGame(game, md5: game.md5Hash, completion: completion)
    }

    /// Returns games whose title matches `query` (exact first, then fuzzy).
    /// Uses a fresh Realm instance so it is safe to call from any thread.
    /// Returns frozen snapshots so callers can safely access properties after this function returns.
    private func searchMediaGames(matchingTitle query: String) -> [PVGame] {
        do {
            let realm = try Realm(configuration: RealmConfiguration.realmConfig)

            // Exact match first.
            let exact = Array(realm.objects(PVGame.self).filter("title ==[c] %@", query).map { $0.freeze() })
            if !exact.isEmpty { return exact }

            // Fuzzy fallback.
            return Array(realm.objects(PVGame.self).filter("title CONTAINS[c] %@", query).map { $0.freeze() })
        } catch {
            ELOG("PVAppDelegate+MediaIntent: Realm error: \(error)")
            return []
        }
    }
}
#endif
