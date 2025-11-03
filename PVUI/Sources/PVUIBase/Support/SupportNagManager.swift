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
    /// Number of game launches before showing the nag screen
    public static let nagInterval = 25

    /// Minimum time between nag screens (to prevent spam)
    private static let minimumTimeBetweenNags: TimeInterval = 7 * 24 * 60 * 60 // 7 days

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

        // Check if we've hit the interval (25, 50, 75, etc.)
        let shouldShow = launchCount % nagInterval == 0

        if shouldShow {
            // Check if we've shown the nag recently (within 7 days)
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

    /// Get the current game launch count
    public static var currentLaunchCount: Int {
        Defaults[.gameLaunchCount]
    }
}
