//
//  PVBroadcastManager.swift
//  PVUI
//
//  Created by Claude on 3/21/26.
//

#if os(iOS) || os(tvOS)
import ReplayKit
import UIKit
import PVLogging

/// Manages ReplayKit live-broadcast sessions for Provenance.
///
/// Uses `RPBroadcastActivityViewController` on both iOS and tvOS so that the
/// app receives an `RPBroadcastController` and can reliably track and stop the
/// broadcast in-app.  (The simpler `RPBroadcastPickerView` available on iOS
/// never returns a controller, so in-app state management is not possible.)
///
/// `@MainActor`-isolated — all properties and methods are safe to access from
/// SwiftUI views and `UIViewController` call sites without additional dispatching.
@MainActor public final class PVBroadcastManager: NSObject {

    public static let shared = PVBroadcastManager()

    /// Whether a broadcast session is currently active.
    ///
    /// Updated via `RPBroadcastControllerDelegate` callbacks.  Access is
    /// race-free because this class is `@MainActor`-isolated.
    public private(set) var isBroadcasting: Bool = false

    /// Whether the broadcast API is available on this device/OS version.
    public var isAvailable: Bool {
        RPScreenRecorder.shared().isAvailable
    }

    /// Optional callback invoked on the main actor when the broadcast activity
    /// VC fails to load (e.g. no broadcast extensions installed, permission
    /// denied, or system error).  Set this from the presenting view controller
    /// to show an alert or toast so the user knows why "GO LIVE" did nothing.
    ///
    /// The handler is treated as a one-shot callback: after it is invoked once,
    /// it is automatically cleared to avoid stale handlers lingering on the
    /// singleton and accidentally handling future errors for a different UI.
    public var onBroadcastLoadError: ((Error?) -> Void)? {
        get { _onBroadcastLoadError }
        set {
            guard let newValue = newValue else {
                _onBroadcastLoadError = nil
                return
            }
            _onBroadcastLoadError = { [weak self] error in
                newValue(error)
                self?._onBroadcastLoadError = nil
            }
        }
    }

    private var _onBroadcastLoadError: ((Error?) -> Void)?
    private var broadcastController: RPBroadcastController?

    private override init() {}

    // MARK: - Public API

    /// Presents `RPBroadcastActivityViewController` from `presenter` so the user
    /// can choose a broadcast provider.
    ///
    /// If a broadcast is already active, calling this method stops it instead
    /// of presenting the picker again.
    ///
    /// - Parameter presenter: The `UIViewController` from which to present the activity VC.
    public func presentBroadcastActivity(from presenter: UIViewController) {
        if isBroadcasting {
            stopBroadcast()
            return
        }
        showActivityViewController(from: presenter)
    }

    /// Stops any currently active broadcast session.
    ///
    /// This is a no-op when no broadcast is active.
    ///
    /// State cleanup (`isBroadcasting = false`, etc.) is deferred to the
    /// `RPBroadcastControllerDelegate.broadcastController(_:didFinishWithError:)`
    /// callback, which fires regardless of whether `finishBroadcast` succeeds or
    /// fails.  This avoids prematurely clearing the controller on a transient
    /// error — if the stop request fails the broadcast may still be active and
    /// the user can retry.
    public func stopBroadcast() {
        guard let controller = broadcastController else {
            // No active controller — ensure UI state is consistent.
            if isBroadcasting { handleBroadcastFinished() }
            return
        }
        controller.finishBroadcast { error in
            if let error {
                // Log only — broadcastController(_:didFinishWithError:) will
                // call handleBroadcastFinished() if/when the broadcast actually
                // stops, preserving the ability to retry on transient failures.
                Task { @MainActor in
                    ELOG("[Broadcast] Error stopping broadcast: \(error.localizedDescription)")
                }
            }
            // Do NOT call handleBroadcastFinished() here.
            // The RPBroadcastControllerDelegate callback is the single source
            // of truth for broadcast-stopped transitions.
        }
    }

    // MARK: - Internal

    fileprivate func handleBroadcastStarted(controller: RPBroadcastController) {
        broadcastController = controller
        isBroadcasting = true
        AppState.shared.emulationUIState.isBroadcasting = true
        ILOG("[Broadcast] Broadcast started: \(controller.broadcastURL.absoluteString ?? "unknown")")
    }

    fileprivate func handleBroadcastFinished() {
        broadcastController = nil
        isBroadcasting = false
        AppState.shared.emulationUIState.isBroadcasting = false
        ILOG("[Broadcast] Broadcast stopped")
    }

    // MARK: - Private helpers

    /// Presents `RPBroadcastActivityViewController` on both iOS and tvOS so that
    /// the app can obtain an `RPBroadcastController` and reliably track/stop
    /// the broadcast session.
    private func showActivityViewController(from presenter: UIViewController) {
        RPBroadcastActivityViewController.load { [weak self] activityVC, error in
            // The load completion can fire on any thread; hop to the main actor
            // before touching any @MainActor-isolated state (self, activityVC.delegate, present).
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    ELOG("[Broadcast] Failed to load RPBroadcastActivityViewController: \(error.localizedDescription)")
                    self.onBroadcastLoadError?(error)
                    return
                }
                guard let activityVC else {
                    WLOG("[Broadcast] No RPBroadcastActivityViewController returned")
                    self.onBroadcastLoadError?(nil)
                    return
                }
                activityVC.delegate = self
                presenter.present(activityVC, animated: true) {
                    ILOG("[Broadcast] RPBroadcastActivityViewController presented")
                }
            }
        }
    }
}

// MARK: - RPBroadcastControllerDelegate

extension PVBroadcastManager: RPBroadcastControllerDelegate {
    public nonisolated func broadcastController(
        _ broadcastController: RPBroadcastController,
        didFinishWithError error: Error?
    ) {
        if let error {
            ELOG("[Broadcast] Broadcast finished with error: \(error.localizedDescription)")
        }
        Task { @MainActor in
            self.handleBroadcastFinished()
        }
    }

    public nonisolated func broadcastController(
        _ broadcastController: RPBroadcastController,
        didUpdateBroadcast broadcastURL: URL
    ) {
        // Log only scheme+host to avoid leaking provider-specific tokens or
        // private stream keys that some services embed in the broadcast URL.
        let scheme = broadcastURL.scheme ?? "unknown"
        let host = broadcastURL.host ?? "unknown"
        ILOG("[Broadcast] Broadcast URL updated (redacted): \(scheme)://\(host)")
    }
}

// MARK: - RPBroadcastActivityViewControllerDelegate (iOS + tvOS)

extension PVBroadcastManager: RPBroadcastActivityViewControllerDelegate {
    public nonisolated func broadcastActivityViewController(
        _ broadcastActivityViewController: RPBroadcastActivityViewController,
        didFinishWith broadcastController: RPBroadcastController?,
        error: Error?
    ) {
        // Always dismiss the activity VC first, regardless of success/failure/cancel.
        Task { @MainActor in
            broadcastActivityViewController.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }

                if let error {
                    ELOG("[Broadcast] Activity VC finished with error: \(error.localizedDescription)")
                    self.handleBroadcastFinished()
                    return
                }

                guard let controller = broadcastController else {
                    WLOG("[Broadcast] Activity VC finished without a controller (user cancelled)")
                    return
                }

                controller.delegate = self
                controller.startBroadcast { [weak controller] startError in
                    if let startError {
                        ELOG("[Broadcast] Failed to start broadcast: \(startError.localizedDescription)")
                        Task { @MainActor in self.handleBroadcastFinished() }
                    } else if let controller {
                        Task { @MainActor in self.handleBroadcastStarted(controller: controller) }
                    }
                }
            }
        }
    }
}
#endif // os(iOS) || os(tvOS)
