//
//  PVAppDelegate+Intents.swift
//  Provenance
//
//  Created by Joseph Mattiello
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Intents
import PVLogging
import PVLibrary
import UIKit
import PVUIBase

#if os(iOS)
@available(iOS 14.0, *)
extension PVAppDelegate {

    /// Registers the intent handler for Siri shortcuts
    func registerIntentHandler() {
        ILOG("PVAppDelegate: Registering intent handler for Siri shortcuts")

        // The intent handler is registered through the Info.plist and
        // the application(_:handlerFor:) method
        // No need to call INExtension.shared.setIntentHandler here

        // Donate intents for opening games
        donateOpenIntents()
    }

    /// Donates intents for opening games to Siri
    private func donateOpenIntents() {
        ILOG("PVAppDelegate: Donating intents for opening games")

        // Create a basic intent for opening a game by MD5
        let openByMD5Intent = PVOpenIntent()
        openByMD5Intent.suggestedInvocationPhrase = "Open game by MD5"

        // Create an intent for opening a game by name
        let openByNameIntent = PVOpenIntent()
        openByNameIntent.suggestedInvocationPhrase = "Open game by name"

        // Create an intent for opening a game by name and system
        let openByNameAndSystemIntent = PVOpenIntent()
        openByNameAndSystemIntent.suggestedInvocationPhrase = "Open game on system"

        // Donate the intents to Siri
        donateIntent(openByMD5Intent)
        donateIntent(openByNameIntent)
        donateIntent(openByNameAndSystemIntent)
    }

    // MARK: - INPlayMediaIntent donation

    /// Donates an `INPlayMediaIntent` interaction for a specific game so Siri
    /// learns the pattern and can suggest "play <game> on Provenance".
    ///
    /// Call this whenever a game is launched by the user.
    /// - Parameter game: The game that was launched.
    public func donateMediaIntent(for game: PVGame) {
        let mediaItem = INMediaItem(
            identifier: game.md5Hash,
            title: game.title,
            type: .game,
            artwork: nil
        )
        let intent = INPlayMediaIntent(mediaItems: [mediaItem])
        intent.suggestedInvocationPhrase = "Play \(game.title)"
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                ELOG("PVAppDelegate: Failed to donate INPlayMediaIntent for '\(game.title)': \(error.localizedDescription)")
            } else {
                ILOG("PVAppDelegate: Donated INPlayMediaIntent for '\(game.title)'")
            }
        }
    }

    /// Donates an intent to Siri
    /// - Parameter intent: The intent to donate
    private func donateIntent(_ intent: INIntent) {
        let interaction = INInteraction(intent: intent, response: nil)

        interaction.donate { error in
            if let error = error {
                ELOG("PVAppDelegate: Failed to donate intent: \(error.localizedDescription)")
            } else {
                ILOG("PVAppDelegate: Successfully donated intent")
            }
        }
    }

    /// Handle an intent response from Siri
    /// - Parameters:
    ///   - application: The UIApplication instance
    ///   - intent: The intent to handle
    ///   - completion: Completion handler to call when the intent is handled
    public func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        ILOG("PVAppDelegate: Handling intent: \(intent)")

        if #available(iOS 14.0, *), let openIntent = intent as? PVOpenIntent {
            let intentHandler = PVIntentHandler()
            intentHandler.handle(intent: openIntent) { response in
                completionHandler(response)
            }
        } else if #available(iOS 14.0, *), let mediaIntent = intent as? INPlayMediaIntent {
            // In-app foreground handling: delegate to our INPlayMediaIntentHandling conformance.
            handle(intent: mediaIntent) { response in
                completionHandler(response)
            }
        } else {
            WLOG("PVAppDelegate: Received unsupported intent type: \(type(of: intent))")
            completionHandler(INIntentResponse())
        }
    }

    /// Update the application(_:continue:restorationHandler:) method to handle intents from user activities
    public func handleIntentUserActivity(_ userActivity: NSUserActivity) -> Bool {
        ILOG("PVAppDelegate: Handling user activity for intent: \(userActivity.activityType)")
        ILOG("PVAppDelegate: User activity userInfo: \(userActivity.userInfo ?? [:])")

        // Check if this is an intent-based user activity
        // Handle both activity types: the custom one and the intent definition one
        let isIntentActivity = userActivity.activityType == "com.provenance.open-game" ||
                               userActivity.activityType == "PVOpenIntent" ||
                               userActivity.activityType == "org.provenance-emu.game.play"

        if isIntentActivity {
            // Try to get MD5 from userInfo
            if let md5 = userActivity.userInfo?["md5"] as? String {
                ILOG("PVAppDelegate: Processing intent activity with MD5: \(md5)")

                if let matchedGame = fetchGame(byMD5: md5) {
                    ILOG("PVAppDelegate: Found game for MD5 \(md5), opening")
                    AppState.shared.appOpenAction = .openGame(matchedGame)
                    return true
                } else {
                    WLOG("PVAppDelegate: No game found for MD5 \(md5)")
                    // Still set the MD5 action in case the game is found later
                    AppState.shared.appOpenAction = .openMD5(md5)
                    return true
                }
            } else {
                // Check if intent has parameters directly
                if let intent = userActivity.interaction?.intent as? PVOpenIntent {
                    ILOG("PVAppDelegate: Found PVOpenIntent in user activity")
                    // Handle the intent through the handler
                    let intentHandler = PVIntentHandler()
                    intentHandler.handle(intent: intent) { response in
                        ILOG("PVAppDelegate: Intent handled with response code: \(response.code)")
                    }
                    return true
                } else {
                    WLOG("PVAppDelegate: Intent activity found but no MD5 or intent in userInfo")
                }
            }
        }

        return false
    }

    /// Returns the appropriate intent handler for the given intent
    /// - Parameters:
    ///   - application: The UIApplication instance
    ///   - intent: The intent to handle
    /// - Returns: The intent handler for the given intent
    public func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        if intent is PVOpenIntent {
            ILOG("PVAppDelegate: Providing handler for PVOpenIntent")
            return PVIntentHandler()
        }

        if #available(iOS 14.0, *), intent is INPlayMediaIntent {
            ILOG("PVAppDelegate: Providing in-app handler for INPlayMediaIntent")
            return self
        }

        WLOG("PVAppDelegate: No handler available for intent type: \(type(of: intent))")
        return nil
    }
}
#endif
