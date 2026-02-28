//
//  SupportNagManager.swift
//  PVUIBase
//
//  Created by AI Assistant
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import Defaults
import PVSettings
#if canImport(FreemiumKit)
import FreemiumKit
#endif

/// Manages showing the support nag screen at appropriate intervals
public struct SupportNagManager {
    /// First nag at launch 10 to catch engaged users earlier
    private static let firstNagThreshold = 10

    /// Second nag at launch 25
    private static let secondNagThreshold = 25

    /// After launch 25, nag every 15 launches
    private static let recurringInterval = 15

    /// Minimum time between nag screens (to prevent spam)
    private static let minimumTimeBetweenNags: TimeInterval = 4 * 24 * 60 * 60 // 4 days

    /// Increment the game launch counter and check if we should show the nag screen
    /// - Returns: True if the nag screen should be shown
    @MainActor
    public static func incrementLaunchCount() -> Bool {
        // Don't show nag on self-built versions
        guard AppState.shared.isAppStore else {
            return false
        }

        var launchCount = Defaults[.gameLaunchCount]
        launchCount += 1
        Defaults[.gameLaunchCount] = launchCount

        // Don't show nag if user already has Provenance Plus
        #if canImport(FreemiumKit)
        if FreemiumKit.shared.purchasedTier != nil {
            return false
        }
        #endif

        // Determine if we should show based on adaptive schedule
        let shouldShow: Bool
        if launchCount == firstNagThreshold {
            shouldShow = true
        } else if launchCount == secondNagThreshold {
            shouldShow = true
        } else if launchCount > secondNagThreshold {
            shouldShow = (launchCount - secondNagThreshold) % recurringInterval == 0
        } else {
            shouldShow = false
        }

        if shouldShow {
            // Check if we've shown the nag recently
            if let lastShown = Defaults[.lastSupportNagShown] {
                let timeSinceLastNag = Date().timeIntervalSince(lastShown)
                if timeSinceLastNag < minimumTimeBetweenNags {
                    return false
                }
            }

            // Update the last shown time
            Defaults[.lastSupportNagShown] = Date()
            return true
        }

        return false
    }

    /// Record that the user dismissed the nag screen
    public static func recordDismissal() {
        Defaults[.nagDismissCount] = Defaults[.nagDismissCount] + 1
    }

    /// Get the current game launch count
    public static var currentLaunchCount: Int {
        Defaults[.gameLaunchCount]
    }

    /// Get the number of times the user has dismissed the nag
    public static var dismissCount: Int {
        Defaults[.nagDismissCount]
    }
}
