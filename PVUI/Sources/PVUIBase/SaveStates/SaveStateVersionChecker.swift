//
//  SaveStateVersionChecker.swift
//  PVUI
//
//  Created by Agent on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVRealm
import PVLogging
#if canImport(UIKit)
import UIKit
#endif

/// Result of a save state version mismatch check.
public struct SaveStateVersionMismatch {
    /// The version stored on the save state
    public let savedVersion: String
    /// The current running core version
    public let currentVersion: String
    /// The human-readable core name
    public let coreName: String
}

/// Utility for checking whether a save state's core version matches the current core.
///
/// The check is intentionally lenient:
/// - If either version string is nil or empty, no mismatch is reported (version unknown).
/// - Only a definitive version string difference triggers a mismatch.
public enum SaveStateVersionChecker {

    /// Returns a `SaveStateVersionMismatch` if the save state was created with a different
    /// core version than the currently installed one, or `nil` if they match (or if either
    /// version is unknown).
    ///
    /// - Parameters:
    ///   - saveState: The `PVSaveState` to inspect.
    ///   - overrideCore: Optional core to use instead of `saveState.core` (e.g. for in-emulator loads).
    /// - Returns: A `SaveStateVersionMismatch` describing the discrepancy, or `nil` if none.
    public static func mismatch(for saveState: PVSaveState, overrideCore: PVCore? = nil) -> SaveStateVersionMismatch? {
        let core = overrideCore ?? saveState.core

        guard
            let savedVersion = saveState.createdWithCoreVersion, !savedVersion.isEmpty,
            let currentVersion = core?.projectVersion, !currentVersion.isEmpty,
            savedVersion != currentVersion
        else {
            return nil
        }

        let coreName = core?.projectName ?? "the emulator"
        return SaveStateVersionMismatch(
            savedVersion: savedVersion,
            currentVersion: currentVersion,
            coreName: coreName
        )
    }

    /// Human-readable warning message for a version mismatch.
    public static func warningMessage(for mismatch: SaveStateVersionMismatch) -> String {
        return """
        This save was created with \(mismatch.coreName) v\(mismatch.savedVersion), \
        but the current version is v\(mismatch.currentVersion).

        Loading may fail or behave unexpectedly. Create a new save state after \
        loading to avoid this warning in the future.
        """
    }

    // MARK: - SceneCoordinator (RetroAlertState) integration

    /// Asynchronously presents a version-mismatch confirmation using a `RetroAlertState`
    /// and returns `true` if the user chooses "Load Anyway", `false` if they cancel.
    ///
    /// If there is no mismatch, returns `true` immediately without showing any UI.
    ///
    /// - Parameters:
    ///   - saveState: The save state being loaded.
    ///   - overrideCore: Optional core override.
    ///   - alertState: The `RetroAlertState` to present the alert on.
    /// - Returns: `true` to proceed with loading, `false` to abort.
    @MainActor
    public static func confirmLoad(
        saveState: PVSaveState,
        overrideCore: PVCore? = nil,
        alertState: RetroAlertState
    ) async -> Bool {
        guard let mismatch = mismatch(for: saveState, overrideCore: overrideCore) else {
            return true
        }

        WLOG("SaveStateVersionChecker: version mismatch — saved=\(mismatch.savedVersion) current=\(mismatch.currentVersion) core=\(mismatch.coreName)")

        var hasResumed = false
        return await withCheckedContinuation { continuation in
            alertState.show(
                title: "Save State Version Mismatch",
                message: warningMessage(for: mismatch),
                type: .warning,
                primaryButtonTitle: "Load Anyway",
                primaryAction: {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: true)
                },
                secondaryButtonTitle: "Cancel",
                secondaryAction: {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: false)
                },
                onDismiss: {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: false)
                }
            )
        }
    }

#if canImport(UIKit)
    // MARK: - UIViewController integration

    /// Asynchronously presents a version-mismatch confirmation using a `UIAlertController`
    /// and returns `true` if the user chooses "Load Anyway".
    ///
    /// If there is no mismatch, returns `true` immediately without showing any UI.
    ///
    /// - Parameters:
    ///   - saveState: The save state being loaded.
    ///   - overrideCore: Optional core override.
    ///   - viewController: The `UIViewController` to present the alert from.
    /// - Returns: `true` to proceed with loading, `false` to abort.
    @MainActor
    public static func confirmLoad(
        saveState: PVSaveState,
        overrideCore: PVCore? = nil,
        on viewController: UIViewController
    ) async -> Bool {
        guard let mismatch = mismatch(for: saveState, overrideCore: overrideCore) else {
            return true
        }

        WLOG("SaveStateVersionChecker: version mismatch — saved=\(mismatch.savedVersion) current=\(mismatch.currentVersion) core=\(mismatch.coreName)")

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Save State Version Mismatch",
                message: warningMessage(for: mismatch),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Load Anyway", style: .default) { _ in
                continuation.resume(returning: true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            })

            // Guard against the continuation hanging if the VC cannot present
            // (e.g. it's not in a window or is already presenting another controller).
            guard viewController.view.window != nil,
                  viewController.presentedViewController == nil else {
                WLOG("SaveStateVersionChecker: cannot present alert (VC not in window or already presenting) — defaulting to cancel")
                continuation.resume(returning: false)
                return
            }

            viewController.present(alert, animated: true)
        }
    }
#endif
}
