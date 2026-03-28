//
//  JITContextualPromptManager.swift
//  PVUIBase
//
//  Context-sensitive pre-launch JIT prompting.
//  Reads the per-game preference and the core's JIT capability, then
//  decides what — if anything — to show the user before the emulator starts.
//
//  Part of: [EPIC] JIT UX & Intelligent JIT Management (#2792)
//  Sub-task: Smart JIT Acquisition — context-sensitive prompting (#2275)
//

import UIKit
import PVSettings
import Defaults

#if canImport(JITManager)
import JITManager
#endif

// MARK: - Launch Recommendation

/// The action the JIT prompt manager recommends before launching a game.
public enum JITLaunchRecommendation: Equatable {
    /// Proceed with normal launch — no prompt needed.
    case proceed

    /// Show a blocking alert: JIT is required but unavailable.
    /// Provide an option to cancel or continue at risk.
    case showRequiredWarning(coreName: String)

    /// Show a non-blocking informational prompt: JIT is recommended but not required.
    /// The user can choose to try to enable JIT or continue without it.
    case showRecommendedPrompt(coreName: String)

    /// Show a one-time performance notice: JIT is not acquirable on this device, but
    /// the core (e.g. Dolphin, 3DS, Flycast) runs significantly worse without it.
    /// No suggestion to enable via AltStore — just sets performance expectations.
    case showPerformanceNotice(coreName: String)

    /// The per-game preference is `.skipJIT` — suppress the pre-launch JIT prompt
    /// and launch immediately. JIT acquisition at the core level is unaffected;
    /// the core uses its default fallback if JIT is unavailable.
    case skipJIT
}

// MARK: - Manager

/// Determines the appropriate JIT prompt to show — if any — before launching a game.
///
/// Call `recommendation(forGameMD5:coreIdentifier:coreName:)` after the emulator
/// core has been selected but before `presentEMU` is called.
///
/// Uses `JITCoreCapability` for compile-time capability lookup and
/// `Defaults[.jitGamePreferences]` for per-game overrides.
@MainActor
public final class JITContextualPromptManager {

    public static let shared = JITContextualPromptManager()
    private init() {}

    /// Per-session set of core identifiers for which a recommended (non-required)
    /// prompt has already been shown. Prevents repeated prompts within one app session.
    private var sessionShownCoreIDs: Set<String> = []

    // MARK: - Decision

    /// Returns the recommended JIT action for the given game + core combination.
    ///
    /// - Parameters:
    ///   - gameMD5: The game's MD5 hash (key for the per-game preference lookup).
    ///   - coreIdentifier: The selected core's identifier string.
    ///   - coreName: Human-readable core/system name shown in alert text.
    /// - Returns: A `JITLaunchRecommendation` describing what (if anything) to display.
    public func recommendation(
        forGameMD5 gameMD5: String,
        coreIdentifier: String,
        coreName: String
    ) -> JITLaunchRecommendation {

        // 1. Cores that don't use JIT at all — never prompt.
        guard JITCoreCapability.isJITRelevant(coreIdentifier) else {
            return .proceed
        }

        // 2. If JIT is already acquired, no action needed.
        #if canImport(JITManager)
        guard !DOLJitManager.acquired else { return .proceed }

        // Determine whether JIT can be acquired on this device/build.
        //
        // • Non-App Store builds and sideloaded App Store builds: JIT is acquirable on
        //   iOS < 26 where sideloading tools (AltStore, StikDebug, JITStreamer) can enable
        //   the debugger JIT path.  On iOS 26+ without the native entitlement, W×X
        //   enforcement makes it unavailable.
        //
        // • Genuine App Store installs: We should never prompt users to use sideloading
        //   tools — that may violate App Store guidelines. JIT is only "acquirable" if it
        //   is already active (e.g. StikDebug running in the background attached the
        //   debugger before the app started). In this case `DOLJitManager.acquired` is
        //   already `true` and we would have returned `.proceed` above.
        //
        // GitHub CI produces APP_STORE–compiled builds that users sideload by resigning
        // the IPA. `isGenuinelyAppStoreDistributed()` detects at runtime whether the
        // build is still a genuine App Store install or has been modified.
        let isGenuineAppStore = DOLJitManager.isGenuinelyAppStoreDistributed()
        // Genuine App Store installs cannot acquire JIT through any UI-visible path:
        // DOLJitManager.acquired is always false here (guard above returned .proceed if true),
        // and sideloading tools are off the table per App Store guidelines.
        // For non-App Store / sideloaded builds, JIT is acquirable on iOS < 26 via sideloading
        // tools; W×X enforcement on iOS 26+ makes it structurally unavailable.
        let jitAcquirable = isGenuineAppStore ? false : !DOLJitManager.isWXEnforced

        // 3. JIT cannot be acquired on this device/OS (e.g. iOS 26 App Store build).
        //    Prompting to "enable via AltStore" would be useless noise.
        if !jitAcquirable {
            // Required cores still need a blocking warning — they may crash.
            if JITCoreCapability.coreIsJITRequired(coreIdentifier) {
                return .showRequiredWarning(coreName: coreName)
            }
            // Performance-critical optional cores (Dolphin, 3DS, Flycast): show a
            // one-time notice to set expectations. N64, PPSSPP: proceed silently.
            if JITCoreCapability.isJITPerformanceCritical(coreIdentifier),
               !sessionShownCoreIDs.contains(coreIdentifier) {
                sessionShownCoreIDs.insert(coreIdentifier)
                return .showPerformanceNotice(coreName: coreName)
            }
            return .proceed
        }
        #endif

        // 4. JIT is acquirable but not yet acquired.
        //    Required-or-crash cores always show a blocking warning.
        if JITCoreCapability.coreIsJITRequired(coreIdentifier) {
            return .showRequiredWarning(coreName: coreName)
        }

        // 5. Check per-game preference (only for optional-JIT cores).
        let gamePreference = Defaults.jitPreference(forGameMD5: gameMD5)
        if gamePreference == .skipJIT {
            return .skipJIT
        }

        // 6. Optional JIT: show informational prompt based on preference.
        //    - preferJIT: always show (user explicitly wants JIT).
        //    - automatic: show once per core per session.
        if gamePreference == .preferJIT {
            return .showRecommendedPrompt(coreName: coreName)
        }

        // automatic: once per session per core
        if !sessionShownCoreIDs.contains(coreIdentifier) {
            sessionShownCoreIDs.insert(coreIdentifier)
            return .showRecommendedPrompt(coreName: coreName)
        }

        return .proceed
    }

    /// Resets the per-session suppression state (call e.g. on foreground resume).
    public func resetSessionState() {
        sessionShownCoreIDs.removeAll()
    }

    // MARK: - Alert Presentation

    /// Presents the appropriate JIT alert for `recommendation`.
    ///
    /// - Parameters:
    ///   - recommendation: Result of `recommendation(forGameMD5:coreIdentifier:coreName:)`.
    ///   - gameMD5: Game MD5 hash — used to persist a "Skip JIT" preference if the user
    ///     chooses that option in the recommended prompt.
    ///   - viewController: The view controller to present the alert from.
    ///   - completion: Called with `true` to proceed with launch, `false` to cancel launch.
    @MainActor
    public func presentPrompt(
        for recommendation: JITLaunchRecommendation,
        gameMD5: String,
        from viewController: UIViewController,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        switch recommendation {
        case .proceed:
            completion(true)
        case .skipJIT:
            completion(true) // launch without JIT — core handles fallback
        case .showRequiredWarning(let coreName):
            presentRequiredWarning(coreName: coreName, from: viewController, completion: completion)
        case .showRecommendedPrompt(let coreName):
            presentRecommendedPrompt(
                coreName: coreName,
                gameMD5: gameMD5,
                from: viewController,
                completion: completion
            )
        case .showPerformanceNotice(let coreName):
            presentPerformanceNotice(coreName: coreName, from: viewController, completion: completion)
        }
    }

    // MARK: - Private Alert Builders

    @MainActor
    private func presentRequiredWarning(
        coreName: String,
        from viewController: UIViewController,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        var message = "\(coreName) requires JIT (Performance Mode) to run correctly."
            + " Without it the game may crash or produce incorrect output."
        #if canImport(JITManager)
        let isGenuineAS = DOLJitManager.isGenuinelyAppStoreDistributed()
        if isGenuineAS {
            // Genuine App Store: avoid suggesting sideloading tools per App Store guidelines.
            message += "\n\nJIT is not currently enabled. Performance may be significantly reduced or the game may not work correctly."
        } else if DOLJitManager.acquired || !DOLJitManager.isWXEnforced {
            message += "\n\nEnable via AltStore, SideStore, or StikDebug before launching."
        } else {
            message += "\n\nJIT is not available on this device."
        }
        #else
        message += "\n\nEnable via AltStore, SideStore, or StikDebug before launching."
        #endif
        let alert = UIAlertController(
            title: "Performance Mode Required",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Launch Anyway", style: .destructive) { _ in
            completion(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        viewController.present(alert, animated: true)
    }

    @MainActor
    private func presentPerformanceNotice(
        coreName: String,
        from viewController: UIViewController,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        let message = "\(coreName) runs best with JIT (Performance Mode), which isn't available on this device. Expect reduced performance."
        let alert = UIAlertController(
            title: "Reduced Performance Expected",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Launch", style: .default) { _ in
            completion(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        viewController.present(alert, animated: true)
    }

    @MainActor
    private func presentRecommendedPrompt(
        coreName: String,
        gameMD5: String,
        from viewController: UIViewController,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        #if canImport(JITManager)
        let message: String
        if DOLJitManager.isGenuinelyAppStoreDistributed() {
            // Genuine App Store installs: avoid mentioning sideloading tools per App Store guidelines.
            message = "\(coreName) runs faster with JIT (Performance Mode)."
                + "\n\nJIT is not currently enabled — emulation speed may be reduced."
                + " You can set a per-game preference in Game Info."
        } else {
            message = "\(coreName) runs faster with JIT (Performance Mode)."
                + "\n\nEnable via AltStore, SideStore, or StikDebug for the best experience."
                + " You can also set a per-game preference in Game Info."
        }
        #else
        let message = "\(coreName) runs faster with JIT (Performance Mode)."
            + "\n\nEnable via AltStore, SideStore, or StikDebug for the best experience."
            + " You can also set a per-game preference in Game Info."
        #endif
        let alert = UIAlertController(
            title: "Performance Mode Available",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Launch", style: .default) { _ in
            completion(true)
        })
        alert.addAction(UIAlertAction(title: "Skip JIT for This Game", style: .default) { _ in
            Defaults.setJITPreference(.skipJIT, forGameMD5: gameMD5)
            completion(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        viewController.present(alert, animated: true)
    }
}
