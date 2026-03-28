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

// MARK: - Legacy INIntent support (deprecated)
//
// The PVOpenIntent-based Siri shortcut path is superseded by LaunchGameIntent
// in PVAppIntents (#3308). The intent handler and donate calls below are kept
// only so that existing NSCoder-archived PVOpenIntent shortcuts can still be
// dispatched while users migrate. New shortcut donations use the AppIntents
// infrastructure via processPendingAppIntents().
//
// Planned removal: once telemetry confirms no PVOpenIntent activations, delete
// this file's legacy sections and the Intents/PV* companion files.

#if os(iOS)
@available(iOS 14.0, *)
extension PVAppDelegate {

    // MARK: - INPlayMediaIntent donation

    /// Donates an `INPlayMediaIntent` interaction for a specific game so Siri
    /// learns the pattern and can suggest "play <game> on Provenance".
    ///
    /// Call this whenever a game is launched by the user.
    /// - Parameter game: The game that was launched.
    public func donateMediaIntent(for game: PVGame) {
        // Capture value-type copies before the closure to avoid accessing the
        // thread-confined Realm object from the Intents framework callback thread.
        let md5 = game.md5Hash
        let title = game.title
        let mediaItem = INMediaItem(
            identifier: md5,
            title: title,
            type: .unknown,
            artwork: nil
        )
        let intent = INPlayMediaIntent(mediaItems: [mediaItem],
                                       mediaContainer: nil,
                                       playShuffled: nil,
                                       playbackRepeatMode: .unknown,
                                       resumePlayback: nil,
                                       playbackQueueLocation: .unknown,
                                       playbackSpeed: nil,
                                       mediaSearch: nil)
        intent.suggestedInvocationPhrase = "Play \(title)"
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                ELOG("PVAppDelegate: Failed to donate INPlayMediaIntent for '\(title)': \(error.localizedDescription)")
            } else {
                ILOG("PVAppDelegate: Donated INPlayMediaIntent for '\(title)'")
            }
        }
    }

    /// Handle an intent response from Siri.
    ///
    /// The `PVOpenIntent` branch is a legacy migration path for users whose
    /// archived Siri shortcuts predate `LaunchGameIntent`. New shortcuts use
    /// the AppIntents infrastructure and never reach this handler.
    /// - Parameters:
    ///   - application: The UIApplication instance
    ///   - intent: The intent to handle
    ///   - completion: Completion handler to call when the intent is handled
    public func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        ILOG("PVAppDelegate: Handling intent: \(intent)")

        // swiftlint:disable:next deprecated_declaration
        if let openIntent = intent as? PVOpenIntent {
            // Legacy migration path — PVOpenIntent shortcuts donated before LaunchGameIntent.
            let intentHandler = PVIntentHandler()
            intentHandler.handle(intent: openIntent) { response in
                completionHandler(response)
            }
        } else if let mediaIntent = intent as? INPlayMediaIntent {
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
                // Check if intent has parameters directly (legacy migration path)
                // swiftlint:disable:next deprecated_declaration
                if let intent = userActivity.interaction?.intent as? PVOpenIntent {
                    ILOG("PVAppDelegate: Found legacy PVOpenIntent in user activity — handling via migration path")
                    // swiftlint:disable:next deprecated_declaration
                    let intentHandler = PVIntentHandler()
                    intentHandler.handle(intent: intent) { response in
                        ILOG("PVAppDelegate: Legacy intent handled with response code: \(response.code)")
                    }
                    return true
                } else {
                    WLOG("PVAppDelegate: Intent activity found but no MD5 or intent in userInfo")
                }
            }
        }

        return false
    }

    /// Returns the appropriate intent handler for the given intent.
    ///
    /// The `PVOpenIntent` branch is a legacy migration path retained for
    /// archived Siri shortcuts. `LaunchGameIntent` in `PVAppIntents` handles
    /// all newly donated shortcuts.
    /// - Parameters:
    ///   - application: The UIApplication instance
    ///   - intent: The intent to handle
    /// - Returns: The intent handler for the given intent
    public func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // swiftlint:disable:next deprecated_declaration
        if intent is PVOpenIntent {
            ILOG("PVAppDelegate: Providing legacy handler for PVOpenIntent (migration path)")
            // swiftlint:disable:next deprecated_declaration
            return PVIntentHandler()
        }

        if intent is INPlayMediaIntent {
            ILOG("PVAppDelegate: Providing in-app handler for INPlayMediaIntent")
            return self
        }

        WLOG("PVAppDelegate: No handler available for intent type: \(type(of: intent))")
        return nil
    }
}
#endif
