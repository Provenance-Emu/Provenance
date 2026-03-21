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
    public func stopBroadcast() {
        guard let controller = broadcastController else {
            handleBroadcastFinished()
            return
        }
        controller.finishBroadcast { [weak self] error in
            if let error {
                ELOG("[Broadcast] Error stopping broadcast: \(error.localizedDescription)")
            }
            Task { @MainActor [weak self] in
                self?.handleBroadcastFinished()
            }
        }
    }

    // MARK: - Internal

    fileprivate func handleBroadcastStarted(controller: RPBroadcastController) {
        broadcastController = controller
        isBroadcasting = true
        AppState.shared.emulationUIState.isBroadcasting = true
        ILOG("[Broadcast] Broadcast started: \(controller.serviceIdentifier ?? "unknown")")
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
            guard let self else { return }
            if let error {
                ELOG("[Broadcast] Failed to load RPBroadcastActivityViewController: \(error.localizedDescription)")
                return
            }
            guard let activityVC else {
                WLOG("[Broadcast] No RPBroadcastActivityViewController returned")
                return
            }
            activityVC.delegate = self
            Task { @MainActor in
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
        ILOG("[Broadcast] Broadcast URL updated: \(broadcastURL)")
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
            broadcastActivityViewController.dismiss(animated: true)
        }

        if let error {
            ELOG("[Broadcast] Activity VC finished with error: \(error.localizedDescription)")
            Task { @MainActor in self.handleBroadcastFinished() }
            return
        }
        guard let controller = broadcastController else {
            WLOG("[Broadcast] Activity VC finished without a controller (user cancelled)")
            return
        }
        controller.delegate = self
        controller.startBroadcast { [weak controller] error in
            if let error {
                ELOG("[Broadcast] Failed to start broadcast: \(error.localizedDescription)")
                Task { @MainActor in self.handleBroadcastFinished() }
            } else if let controller {
                Task { @MainActor in self.handleBroadcastStarted(controller: controller) }
            }
        }
    }
}
#endif // os(iOS) || os(tvOS)
