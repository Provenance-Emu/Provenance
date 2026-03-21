//
//  JITOnboardingManager.swift
//
//
//  Created by Provenance EMU on 2026-03-15.
//

import Foundation
import PVLogging

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Manages JIT onboarding presentation at core launch time.
///
/// Call `presentOnboardingIfNeeded(for:from:)` before starting emulation
/// to inform the user when JIT has not been acquired. The alert is presented
/// at most once per app session and does not block emulation — it is purely
/// informational with optional actions to retry JIT acquisition.
@MainActor
public final class JITOnboardingManager {

    public static let shared = JITOnboardingManager()

    /// Whether the onboarding alert has already been shown this session.
    private var hasShownThisSession = false

    private init() {}

    /// Present JIT onboarding if JIT is required but not yet acquired.
    ///
    /// - Parameters:
    ///   - jitManager: The JIT manager to query for JIT status. Defaults to `DOLJitManager.shared`.
    ///   - viewController: The view controller to present the alert from.
    /// - Returns: `true` if the onboarding was presented, `false` otherwise.
    @discardableResult
    public func presentOnboardingIfNeeded(
        for jitManager: DOLJitManager = .shared,
        from viewController: UIViewController
    ) -> Bool {
        // Only show once per session
        guard !hasShownThisSession else {
            DLOG("JITOnboarding: Already shown this session, skipping")
            return false
        }

        // If JIT is already acquired, no need to show anything
        guard !jitManager.appHasAcquiredJit() else {
            DLOG("JITOnboarding: JIT already acquired, skipping")
            return false
        }

        // If the JIT type is unrestricted or not applicable, skip
        let jitType = jitManager.getJitType()
        guard jitType != .notRestricted else {
            DLOG("JITOnboarding: JIT not restricted on this device, skipping")
            return false
        }

        ILOG("JITOnboarding: Preparing JIT onboarding alert")

        let alert = UIAlertController(
            title: "Performance Mode Unavailable",
            message: "This core performs best with Performance Mode (JIT) enabled. "
                + "Performance Mode has not been acquired for this session — you can continue playing, "
                + "but emulation speed may be reduced.\n\n"
                + "To enable Performance Mode, use AltStore, SideStore, StikDebug, JITStreamer, or a "
                + "developer certificate before launching.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))

        // Offer StikDebug as the first retry option (VPN-based, no macOS required).
        if jitType == .debugger || jitType == .stikDebug {
            alert.addAction(UIAlertAction(title: "Try StikDebug", style: .default) { _ in
                ILOG("JITOnboarding: User chose to retry via StikDebug")
                jitManager.attemptToAcquireJitByStikDebug()
            })
        }

        // JITStreamer as an alternative for desktop-based attach.
        if jitType == .debugger {
            alert.addAction(UIAlertAction(title: "Try JITStreamer", style: .default) { _ in
                ILOG("JITOnboarding: User chose to retry via JITStreamer")
                jitManager.attemptToAcquireJitByJitStreamer()
            })
        }

        alert.addAction(UIAlertAction(title: "Learn More", style: .default) { _ in
            if let url = URL(string: "https://wiki.provenance-emu.com/jit-help") {
                UIApplication.shared.open(url)
            }
        })

        // Ensure we can actually present before marking the onboarding as shown
        guard viewController.viewIfLoaded?.window != nil,
            viewController.presentedViewController == nil else {
            WLOG("JITOnboarding: Unable to present onboarding alert (VC not in window or already presenting); will allow retry later")
            return false
        }

        ILOG("JITOnboarding: Presenting JIT onboarding alert")

        viewController.present(alert, animated: true) { [weak self] in
            self?.hasShownThisSession = true
        }

        return true
    }

    /// Reset session tracking (useful for testing).
    public func resetSession() {
        hasShownThisSession = false
    }
}
#endif
