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
import ObjectiveC
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

    /// Normalizes a version string by trimming whitespace and returning `nil` for empty
    /// strings or known sentinel values such as `"Unknown"` (case-insensitive) that
    /// indicate the version was never recorded (e.g. CloudKit-synced save states).
    /// Sentinel values that indicate the version is unreliable and should not trigger
    /// a mismatch warning. "nightly" builds change constantly but the string stays the
    /// same, and "Unknown" means the version was never recorded.
    private static let ignoredVersions: Set<String> = ["unknown", "nightly", "n/a", "dev", "git"]

    private static func normalizedVersion(_ version: String?) -> String? {
        guard let v = version?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else {
            return nil
        }
        if ignoredVersions.contains(v.lowercased()) { return nil }
        return extractSemanticVersion(v)
    }

    /// Extracts the semantic version portion from a version string, stripping
    /// git hashes, build numbers, and other metadata that change between builds
    /// but don't indicate an actual version difference.
    ///
    /// Examples:
    /// - `"v1.24.0 efd1797"` → `"1.24.0"`
    /// - `"1.24.0"` → `"1.24.0"`
    /// - `"2.8-Vulkan bc43bce"` → `"2.8-Vulkan"`
    /// - `"2024.10.29"` → `"2024.10.29"` (date-based version, kept as-is)
    /// - `"nightly-abc1234"` → `"nightly-abc1234"` (no semver found, returned as-is)
    private static func extractSemanticVersion(_ version: String) -> String {
        // Strip leading "v" or "V" prefix
        var v = version
        if v.hasPrefix("v") || v.hasPrefix("V") {
            v = String(v.dropFirst())
        }

        // Try to match a semver-like pattern at the start: digits.digits[.digits][-tag]
        // Stop at the first whitespace which usually precedes a git hash or build metadata
        let components = v.split(separator: " ", maxSplits: 1)
        let candidate = String(components[0])

        // If the candidate looks like a version (starts with digit or contains a dot), use it
        if candidate.first?.isNumber == true || candidate.contains(".") {
            return candidate
        }

        // Fallback: return the space-stripped version as-is
        return candidate
    }

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
            let savedVersion = normalizedVersion(saveState.createdWithCoreVersion),
            let currentVersion = normalizedVersion(core?.projectVersion),
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
        This save was created with \(mismatch.coreName) \(mismatch.savedVersion), \
        but the current version is \(mismatch.currentVersion).

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

        // hasResumed prevents double-resume if both an alert action fires and an
        // indirect dismissal path (e.g. the presenting VC is force-dismissed while
        // the alert is on screen) attempt to resume the continuation.
        var hasResumed = false
        var alertController: (any UIAlertControllerProtocol)?
        var resumeClosure: ((Bool) -> Void)?

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                func resume(_ value: Bool) {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                // Make resume available to cancellation / dismissal handlers.
                resumeClosure = resume

                let alert = UIAlertController(
                    title: "Save State Version Mismatch",
                    message: warningMessage(for: mismatch),
                    preferredStyle: .alert
                )
                alertController = alert

                alert.addAction(UIAlertAction(title: "Load Anyway", style: .default) { _ in
                    resume(true)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    resume(false)
                })

                // Ensure the continuation also resumes if the alert is dismissed
                // without an explicit action (e.g. presenting VC is dismissed).
                if let presentationController = alert.presentationController {
                    let delegate = SaveStateAlertPresentationDelegate {
                        resume(false)
                    }
                    presentationController.delegate = delegate
                    objc_setAssociatedObject(
                        alert,
                        &AssociatedKeys.presentationDelegate,
                        delegate,
                        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    )
                }

                // Guard against the continuation hanging if the VC cannot present.
                // Resolve a suitable presenter (the top-most presented VC attached to a window).
                var presenter: UIViewController? = viewController
                while let presented = presenter?.presentedViewController {
                    presenter = presented
                }

                guard let resolvedPresenter = presenter,
                      resolvedPresenter.view.window != nil else {
                    WLOG("SaveStateVersionChecker: cannot present alert (no presenter in window) — defaulting to cancel")
                    resume(false)
                    return
                }

                resolvedPresenter.present(alert, animated: true)
            }
        } onCancel: {
            // If the task is cancelled while the alert is visible, dismiss the alert
            // and resume the continuation with `false` to avoid hanging callers.
            Task { @MainActor in
                if let alert = alertController, alert.presentingViewController != nil {
                    alert.dismiss(animated: true)
                }

                if let resume = resumeClosure {
                    resume(false)
                }
            }
        }
    }

    // MARK: - Private helpers (UIKit)

    private final class SaveStateAlertPresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
            super.init()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onDismiss()
        }
    }

    private struct AssociatedKeys {
        static var presentationDelegate = "SaveStateVersionCheckerPresentationDelegateKey"
    }
#endif
}
