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

/// Manages showing the support nag screen at appropriate intervals
public struct SupportNagManager {
    private static let neverAskAgainKey = "org.provenance.supportNag.neverAskAgain"

    /// Increment the game launch counter and check if we should show the nag screen
    /// - Returns: True if the nag screen should be shown
    @MainActor
    public static func incrementLaunchCount() -> Bool {
        // Don't show nag on self-built versions
        guard AppState.shared.isAppStore else {
            return false
        }

        guard !UserDefaults.standard.bool(forKey: neverAskAgainKey) else { return false }
        #if canImport(FreemiumKit)
        guard PlusEntitlement.isSettled else { return false }
        #endif

        var launchCount = Defaults[.gameLaunchCount]
        launchCount += 1
        Defaults[.gameLaunchCount] = launchCount

        // Don't show nag if user already has Provenance Plus (incl. via iFly Pro)
        #if canImport(FreemiumKit)
        if PlusEntitlement.isUnlocked {
            return false
        }
        #endif

        guard SupportNagSchedule.isEligible(completedSessions: launchCount,
                                             lastShown: Defaults[.lastSupportNagShown], now: Date()) else { return false }
        Defaults[.lastSupportNagShown] = Date()
        return true
    }

    /// Permanently suppress optional support prompts on this installation.
    public static func neverAskAgain() {
        UserDefaults.standard.set(true, forKey: neverAskAgainKey)
    }

    /// Record that the user dismissed the nag screen
    public static func recordDismissal() {
        Defaults[.nagDismissCount] += 1
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

/// Preserves the existing frequency while moving the counter to successful completed sessions.
enum SupportNagSchedule {
    static func isEligible(completedSessions: Int, lastShown: Date?, now: Date) -> Bool {
        let firstThreshold = 10
        let secondThreshold = 25
        let recurringInterval = 15
        let minimumInterval: TimeInterval = 4 * 24 * 60 * 60
        let scheduled = completedSessions == firstThreshold || completedSessions == secondThreshold ||
            (completedSessions > secondThreshold && (completedSessions - secondThreshold) % recurringInterval == 0)
        guard scheduled else { return false }
        return lastShown.map { now.timeIntervalSince($0) >= minimumInterval } ?? true
    }
}
