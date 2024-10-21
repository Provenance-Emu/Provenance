//
//  PVAppDelegate+AppRating.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/19/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import SiriusRating

extension PVAppDelegate {
    func _initAppRating() {
#if DEBUG
    let debug = true
    let release = false
#else
    let debug = false
    let release = true
#endif
        SiriusRating.setup(
            requestPromptPresenter: StyleTwoRequestPromptPresenter(),
            debugEnabled: debug,
            ratingConditions: [
//                EnoughDaysUsedRatingCondition(totalDaysRequired = 0),
//                EnoughAppSessionsRatingCondition(totalAppSessionsRequired = 0),
                EnoughSignificantEventsRatingCondition(significantEventsRequired: 3)
                // Essential rating conditions below: Ensure these are included to prevent the prompt from appearing continuously.
//                NotPostponedDueToReminderRatingCondition(totalDaysBeforeReminding: 14),
//                NotDeclinedToRateAnyVersionRatingCondition(daysAfterDecliningToPromptUserAgain: 30, backOffFactor: 2.0, maxRecurringPromptsAfterDeclining: 2),
//                NotRatedCurrentVersionRatingCondition(),
//                NotRatedAnyVersionRatingCondition(daysAfterRatingToPromptUserAgain: 240, maxRecurringPromptsAfterRating: UInt.max)
            ],
            canPromptUserToRateOnLaunch: true
//            didOptInForReminderHandler: {
//                //...
//            },
//            didDeclineToRateHandler: {
//                //...
//            },
//            didRateHandler: {
//                //...
//            }
        )
    }
    
    func appRatingSignifigantEvent() {
//        SiriusRating.shared.userDidSignificantEvent()
    }
    
    func testAppRatingPrompt() {
        // For test purposes only.
        SiriusRating.shared.showRequestPrompt()
    }
}
