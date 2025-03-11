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
    func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        ILOG("PVAppDelegate: Handling intent: \(intent)")

        // Handle the Open intent
        if #available(iOS 14.0, *), let openIntent = intent as? PVOpenIntent {
            let intentHandler = PVIntentHandler()
            intentHandler.handle(intent: openIntent) { response in
                completionHandler(response)
            }
        } else {
            WLOG("PVAppDelegate: Received unsupported intent type: \(type(of: intent))")
            completionHandler(INIntentResponse())
        }
    }

    /// Update the application(_:continue:restorationHandler:) method to handle intents from user activities
    func handleIntentUserActivity(_ userActivity: NSUserActivity) -> Bool {
        ILOG("PVAppDelegate: Handling user activity for intent: \(userActivity.activityType)")

        // Check if this is an intent-based user activity
        if userActivity.activityType == "com.provenance.open-game",
           let md5 = userActivity.userInfo?["md5"] as? String {
            ILOG("PVAppDelegate: Processing open-game activity with MD5: \(md5)")

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
        }

        return false
    }

    /// Returns the appropriate intent handler for the given intent
    /// - Parameters:
    ///   - application: The UIApplication instance
    ///   - intent: The intent to handle
    /// - Returns: The intent handler for the given intent
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // Create and return a new instance of our intent handler
        if intent is PVOpenIntent {
            ILOG("PVAppDelegate: Providing handler for PVOpenIntent")
            return PVIntentHandler()
        }

        WLOG("PVAppDelegate: No handler available for intent type: \(type(of: intent))")
        return nil
    }
}
#endif
