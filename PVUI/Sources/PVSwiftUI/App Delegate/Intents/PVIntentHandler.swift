//
//  PVIntentHandler.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/1/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//
#if false
import Foundation
import Intents
import PVLogging
import PVLibrary
import PVRealm
import RealmSwift
import PVUIBase

/// Handler for Siri intents related to Provenance
#if os(iOS)
@available(iOS 14.0, *)
class PVIntentHandler: NSObject, PVOpenIntentHandling {

    /// Handles the intent to open a game by MD5 hash, name, or name+system combination
    /// - Parameter intent: The Open intent with parameters
    /// - Parameter completion: Completion handler to call when the intent is handled
    func handle(intent: PVOpenIntent, completion: @escaping (PVOpenIntentResponse) -> Void) {
        ILOG("PVIntentHandler: Handling open intent")

        // Check for MD5 parameter first (most specific)
        if let md5 = intent.md5, !md5.isEmpty {
            ILOG("PVIntentHandler: Processing intent with MD5: \(md5)")

            if let matchedGame = fetchGame(byMD5: md5) {
                ILOG("PVIntentHandler: Found game for MD5 \(md5), opening")

                // Use Task to handle the main actor-isolated property
                Task { @MainActor in
                    AppState.shared.appOpenAction = .openGame(matchedGame)
                }

                let userActivity = NSUserActivity(activityType: "com.provenance.open-game")
                userActivity.userInfo = ["md5": md5]

                completion(PVOpenIntentResponse(code: .success, userActivity: userActivity))
            } else {
                WLOG("PVIntentHandler: No game found for MD5 \(md5)")
                completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
            }
            return
        }

        // Check for game name and system combination
        if let gameName = intent.gameName, !gameName.isEmpty {
            if let systemName = intent.systemName, !systemName.isEmpty {
                ILOG("PVIntentHandler: Processing intent with game name: \(gameName) and system: \(systemName)")
                handleOpenByGameAndSystem(gameName: gameName, systemName: systemName, completion: completion)
            } else {
                ILOG("PVIntentHandler: Processing intent with game name only: \(gameName)")
                handleOpenByGameName(gameName, completion: completion)
            }
            return
        }

        // If we don't have any valid parameters, return failure
        WLOG("PVIntentHandler: No valid parameters provided in intent")
        completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
    }

    /// Helper method to safely fetch a game from Realm by its MD5 hash
    /// - Parameter md5: The MD5 hash of the game
    /// - Returns: The game if found, nil otherwise
    private func fetchGame(byMD5 md5: String) -> PVGame? {
        return RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: md5)
    }

    /// Handle opening a game by name using fuzzy search
    /// - Parameters:
    ///   - gameName: The name of the game to search for
    ///   - completion: Completion handler to call when the intent is handled
    private func handleOpenByGameName(_ gameName: String, completion: @escaping (PVOpenIntentResponse) -> Void) {
        do {
            let realm = try Realm()

            // First try an exact match
            if let exactMatch = realm.objects(PVGame.self).filter("title == %@", gameName).first {
                ILOG("PVIntentHandler: Found exact match for game name: \(gameName)")

                // Use Task to handle the main actor-isolated property
                Task { @MainActor in
                    AppState.shared.appOpenAction = .openGame(exactMatch)
                }

                let userActivity = NSUserActivity(activityType: "com.provenance.open-game")
                userActivity.userInfo = ["md5": exactMatch.md5Hash]

                completion(PVOpenIntentResponse(code: .success, userActivity: userActivity))
                return
            }

            // If no exact match, try a case-insensitive contains search
            let fuzzyMatches = realm.objects(PVGame.self).filter("title CONTAINS[c] %@", gameName)

            if let bestMatch = fuzzyMatches.first {
                ILOG("PVIntentHandler: Found fuzzy match for game name: \(gameName) -> \(bestMatch.title)")

                // Use Task to handle the main actor-isolated property
                Task { @MainActor in
                    AppState.shared.appOpenAction = .openGame(bestMatch)
                }

                let userActivity = NSUserActivity(activityType: "com.provenance.open-game")
                userActivity.userInfo = ["md5": bestMatch.md5Hash]

                completion(PVOpenIntentResponse(code: .success, userActivity: userActivity))
            } else {
                WLOG("PVIntentHandler: No games found matching name: \(gameName)")
                completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
            }
        } catch {
            ELOG("PVIntentHandler: Error searching for game by name: \(error.localizedDescription)")
            completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
        }
    }

    /// Handle opening a game by name and system using fuzzy search
    /// - Parameters:
    ///   - gameName: The name of the game to search for
    ///   - systemName: The name of the system to search for
    ///   - completion: Completion handler to call when the intent is handled
    private func handleOpenByGameAndSystem(gameName: String, systemName: String, completion: @escaping (PVOpenIntentResponse) -> Void) {
        do {
            let realm = try Realm()

            // First find matching systems
            let systemMatches = realm.objects(PVSystem.self).filter("name CONTAINS[c] %@ OR shortName CONTAINS[c] %@", systemName, systemName)

            if systemMatches.isEmpty {
                WLOG("PVIntentHandler: No systems found matching: \(systemName)")
                // Fall back to just game name search
                handleOpenByGameName(gameName, completion: completion)
                return
            }

            // Get system identifiers
            let systemIdentifiers = systemMatches.map { $0.identifier }

            // Try to find a game that matches both the name and one of the systems
            var bestMatch: PVGame? = nil

            // First try exact match on title with any matching system
            for systemId in systemIdentifiers {
                if let match = realm.objects(PVGame.self)
                    .filter("title == %@ AND systemIdentifier == %@", gameName, systemId)
                    .first {
                    bestMatch = match
                    break
                }
            }

            // If no exact match, try contains match
            if bestMatch == nil {
                for systemId in systemIdentifiers {
                    if let match = realm.objects(PVGame.self)
                        .filter("title CONTAINS[c] %@ AND systemIdentifier == %@", gameName, systemId)
                        .first {
                        bestMatch = match
                        break
                    }
                }
            }

            if let game = bestMatch {
                ILOG("PVIntentHandler: Found game '\(game.title)' on system '\(game.systemIdentifier)'")

                // Use Task to handle the main actor-isolated property
                Task { @MainActor in
                    AppState.shared.appOpenAction = .openGame(game)
                }

                let userActivity = NSUserActivity(activityType: "com.provenance.open-game")
                userActivity.userInfo = ["md5": game.md5Hash]

                completion(PVOpenIntentResponse(code: .success, userActivity: userActivity))
                return
            }

            // No matches found with system, fall back to just game name
            WLOG("PVIntentHandler: No games found matching name: \(gameName) on system: \(systemName)")
            handleOpenByGameName(gameName, completion: completion)

        } catch {
            ELOG("PVIntentHandler: Error searching for game by name and system: \(error.localizedDescription)")
            completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
        }
    }

    /// Resolves the MD5 parameter for the Open intent
    /// - Parameter intent: The Open intent
    /// - Parameter completion: Completion handler to call when the parameter is resolved
    func resolveMd5(for intent: PVOpenIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let md5 = intent.md5, !md5.isEmpty else {
            completion(INStringResolutionResult.needsValue())
            return
        }

        if let _ = fetchGame(byMD5: md5) {
            ILOG("PVIntentHandler: Resolved MD5: \(md5)")
            completion(INStringResolutionResult.success(with: md5))
        } else {
            WLOG("PVIntentHandler: No game found for MD5: \(md5)")
            completion(INStringResolutionResult.unsupported())
        }
    }

    /// Resolves the game name parameter for the Open intent
    /// - Parameter intent: The Open intent
    /// - Parameter completion: Completion handler to call when the parameter is resolved
    func resolveGameName(for intent: PVOpenIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let gameName = intent.gameName, !gameName.isEmpty else {
            completion(INStringResolutionResult.needsValue())
            return
        }

        do {
            let realm = try Realm()
            if realm.objects(PVGame.self).filter("title CONTAINS[c] %@", gameName).first != nil {
                ILOG("PVIntentHandler: Resolved game name: \(gameName)")
                completion(INStringResolutionResult.success(with: gameName))
            } else {
                WLOG("PVIntentHandler: No games found matching name: \(gameName)")
                completion(INStringResolutionResult.unsupported())
            }
        } catch {
            ELOG("PVIntentHandler: Error resolving game name: \(error.localizedDescription)")
            completion(INStringResolutionResult.unsupported())
        }
    }

    /// Resolves the system name parameter for the Open intent
    /// - Parameter intent: The Open intent
    /// - Parameter completion: Completion handler to call when the parameter is resolved
    func resolveSystemName(for intent: PVOpenIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let systemName = intent.systemName, !systemName.isEmpty else {
            completion(INStringResolutionResult.needsValue())
            return
        }

        do {
            let realm = try Realm()
            let matches = realm.objects(PVSystem.self).filter("name CONTAINS[c] %@ OR shortName CONTAINS[c] %@", systemName, systemName)

            if matches.isEmpty {
                WLOG("PVIntentHandler: No systems found matching name: \(systemName)")
                completion(INStringResolutionResult.unsupported())
            } else {
                ILOG("PVIntentHandler: Found \(matches.count) systems matching name: \(systemName)")
                completion(INStringResolutionResult.success(with: systemName))
            }
        } catch {
            ELOG("PVIntentHandler: Error resolving system name: \(error.localizedDescription)")
            completion(INStringResolutionResult.unsupported())
        }
    }

    /// Confirms the intent before handling
    /// - Parameter intent: The Open intent
    /// - Parameter completion: Completion handler to call when the intent is confirmed
    func confirm(intent: PVOpenIntent, completion: @escaping (PVOpenIntentResponse) -> Void) {
        ILOG("PVIntentHandler: Confirming intent")

        // Check for MD5 parameter first (most specific)
        if let md5 = intent.md5, !md5.isEmpty {
            if let _ = fetchGame(byMD5: md5) {
                ILOG("PVIntentHandler: Confirmed intent to open game with MD5: \(md5)")
                completion(PVOpenIntentResponse(code: .success, userActivity: nil))
            } else {
                WLOG("PVIntentHandler: Cannot confirm intent - no game found for MD5: \(md5)")
                completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
            }
            return
        }

        // Check for game name
        if let gameName = intent.gameName, !gameName.isEmpty {
            do {
                let realm = try Realm()
                if realm.objects(PVGame.self).filter("title CONTAINS[c] %@", gameName).first != nil {
                    ILOG("PVIntentHandler: Confirmed intent to open game '\(gameName)'")
                    completion(PVOpenIntentResponse(code: .success, userActivity: nil))
                    return
                }

                WLOG("PVIntentHandler: Cannot confirm intent - no game found matching name: \(gameName)")
                completion(PVOpenIntentResponse(code: .failure, userActivity: nil))

            } catch {
                ELOG("PVIntentHandler: Error confirming intent: \(error.localizedDescription)")
                completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
            }
            return
        }

        // If we don't have any valid parameters, return failure
        ELOG("PVIntentHandler: Cannot confirm intent - no valid parameters provided")
        completion(PVOpenIntentResponse(code: .failure, userActivity: nil))
    }
}
#endif
#endif
