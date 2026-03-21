//
//  PVEmulatorViewController+Recording.swift
//  PVUI
//
//  Created by Claude on 3/7/26.
//

#if os(iOS) || os(tvOS)
import UIKit
import PVLogging

// MARK: - Live Broadcast (iOS + tvOS)

extension PVEmulatorViewController {

    /// Whether the device/session supports ReplayKit broadcasting.
    public var isBroadcastAvailable: Bool {
        PVBroadcastManager.shared.isAvailable
    }

    /// Whether a live broadcast session is currently active.
    /// Reads from `PVBroadcastManager.shared.isBroadcasting` (the authoritative source).
    public var isBroadcasting: Bool {
        PVBroadcastManager.shared.isBroadcasting
    }

    /// Presents `RPBroadcastActivityViewController` so the user can choose a
    /// broadcast provider and start a live stream.  The manager keeps
    /// `PVBroadcastManager.isBroadcasting` and `AppState.emulationUIState.isBroadcasting`
    /// in sync via `RPBroadcastControllerDelegate` callbacks.
    ///
    /// - Parameter presenter: The view controller from which to present the picker.
    ///   Defaults to `self`.
    public func startBroadcast(from presenter: UIViewController? = nil) {
        let presentingVC = presenter ?? self
        // Surface load failures to the user so "GO LIVE" doesn't silently do nothing.
        PVBroadcastManager.shared.onBroadcastLoadError = { [weak self] _ in
            guard let self else { return }
            let alert = UIAlertController(
                title: "Live Broadcast Unavailable",
                message: "No broadcast extensions are installed. Install an app like Twitch or YouTube to enable live streaming.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
        PVBroadcastManager.shared.presentBroadcastActivity(from: presentingVC)
        // isBroadcasting state is updated asynchronously via RPBroadcastControllerDelegate
        ILOG("[Broadcast] Broadcast activity VC requested from VC")
    }

    /// Convenience wrapper: stops any active broadcast.
    /// Guards on the manager's own state to avoid false negatives from a stale UI flag.
    public func stopBroadcast() {
        guard PVBroadcastManager.shared.isBroadcasting else { return }
        PVBroadcastManager.shared.stopBroadcast()
        ILOG("[Broadcast] Stop broadcast requested from VC")
    }
}

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
#endif // os(iOS)
#endif // os(iOS) || os(tvOS)
