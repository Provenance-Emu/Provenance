//
//  PVEmulatorViewController+Recording.swift
//  PVUI
//
//  Created by Claude on 3/7/26.
//

import UIKit
import PVLogging

// MARK: - Live Broadcast (iOS + tvOS)

#if os(iOS) || os(tvOS)
extension PVEmulatorViewController {

    /// Whether the device/session supports ReplayKit broadcasting.
    public var isBroadcastAvailable: Bool {
        PVBroadcastManager.shared.isAvailable
    }

    /// Whether a live broadcast session is currently active.
    /// Single source of truth: reads from `AppState.shared.emulationUIState.isBroadcasting`.
    public var isBroadcasting: Bool {
        AppState.shared.emulationUIState.isBroadcasting
    }

    /// Presents the system broadcast-service picker so the user can start (or stop)
    /// a live broadcast.  Updates `AppState.shared.emulationUIState.isBroadcasting`
    /// to reflect the current broadcast state.
    ///
    /// - Parameter presenter: The view controller from which to present the picker.
    ///   Defaults to `self`.
    public func startBroadcast(from presenter: UIViewController? = nil) {
        let presentingVC = presenter ?? self
        PVBroadcastManager.shared.showBroadcastPicker(from: presentingVC)
        // isBroadcasting state is updated asynchronously via RPBroadcastControllerDelegate
        ILOG("[Broadcast] Broadcast picker requested from VC")
    }

    /// Convenience wrapper: stops any active broadcast and clears the UI state flag.
    /// When no broadcast is active, this is a no-op.
    public func stopBroadcast() {
        guard isBroadcasting else { return }
        // Use the dedicated stop API; state will be cleared via delegate callback
        PVBroadcastManager.shared.stopBroadcast()
        ILOG("[Broadcast] Stop broadcast requested from VC")
    }
}
#endif

// MARK: - Screen Recording (iOS only)

#if os(iOS)
extension PVEmulatorViewController {

    /// Whether the device/session supports ReplayKit recording.
    public var isRecordingAvailable: Bool {
        PVRecordingManager.shared.isAvailable
    }

    /// Whether a recording session is currently active.
    /// Single source of truth: reads from `AppState.shared.emulationUIState.isRecording`.
    public var isRecording: Bool {
        AppState.shared.emulationUIState.isRecording
    }

    /// Starts a ReplayKit screen recording session.
    /// Updates `AppState.shared.emulationUIState.isRecording` on success.
    public func startScreenRecording() {
        Task { @MainActor in
            do {
                try await PVRecordingManager.shared.startRecording()
                AppState.shared.emulationUIState.isRecording = true
                ILOG("[Recording] Recording started")
            } catch {
                ELOG("[Recording] Could not start recording: \(error.localizedDescription)")
                showRecordingError(error)
            }
        }
    }

    /// Stops the current ReplayKit recording and presents the share sheet.
    /// Updates `AppState.shared.emulationUIState.isRecording` on completion.
    ///
    /// The game **remains paused** while the preview sheet is visible.  Emulation
    /// resumes automatically once the user dismisses the preview (save / discard).
    public func stopScreenRecording() {
        // Register a callback so emulation resumes after the preview is dismissed.
        PVRecordingManager.shared.onPreviewDismissed = { [weak self] in
            guard let self, self.core.isOn else { return }
            self.core.setPauseEmulation(false)
            ILOG("[Recording] Resumed emulation after preview dismissed")
        }

        Task { @MainActor in
            do {
                try await PVRecordingManager.shared.stopRecording(presenter: self)
                AppState.shared.emulationUIState.isRecording = false
                ILOG("[Recording] Recording stopped and preview presented")
            } catch {
                // On error clear the resume callback so we don't hang in a paused state
                PVRecordingManager.shared.onPreviewDismissed = nil
                AppState.shared.emulationUIState.isRecording = false
                ELOG("[Recording] Could not stop recording: \(error.localizedDescription)")
                // Resume emulation since we won't be showing the preview
                if core.isOn { core.setPauseEmulation(false) }
                showRecordingError(error)
            }
        }
    }

    /// Discards the current recording without presenting the preview.
    /// Updates `AppState.shared.emulationUIState.isRecording` to keep state consistent.
    public func discardScreenRecording() {
        PVRecordingManager.shared.discardRecording()
        AppState.shared.emulationUIState.isRecording = false
        ILOG("[Recording] Recording discarded via VC")
    }

    /// Toggles recording on/off.
    public func toggleScreenRecording() {
        if isRecording {
            stopScreenRecording()
        } else {
            startScreenRecording()
        }
    }

    // MARK: Private

    private func showRecordingError(_ error: Error) {
        let alert = UIAlertController(
            title: "Recording Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
#endif
