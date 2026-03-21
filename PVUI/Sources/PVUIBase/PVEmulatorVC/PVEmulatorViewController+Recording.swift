//
//  PVEmulatorViewController+Recording.swift
//  PVUI
//
//  Created by Claude on 3/7/26.
//

#if os(iOS) || os(tvOS)
import UIKit
import Photos
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
                notifyOSDRecordingStateChanged()
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
                notifyOSDRecordingStateChanged()
                ILOG("[Recording] Recording stopped and preview presented")
            } catch {
                // On error clear the resume callback so we don't hang in a paused state
                PVRecordingManager.shared.onPreviewDismissed = nil
                AppState.shared.emulationUIState.isRecording = false
                notifyOSDRecordingStateChanged()
                ELOG("[Recording] Could not stop recording: \(error.localizedDescription)")
                // Resume emulation since we won't be showing the preview
                if core.isOn { core.setPauseEmulation(false) }
                showRecordingError(error)
            }
        }
    }

    /// Discards the current recording without presenting the preview.
    /// Updates `AppState.shared.emulationUIState.isRecording` to keep state consistent.
    @MainActor public func discardScreenRecording() {
        PVRecordingManager.shared.discardRecording()
        AppState.shared.emulationUIState.isRecording = false
        notifyOSDRecordingStateChanged()
        ILOG("[Recording] Recording discarded via VC")
    }

    /// Notifies the OSD controller to refresh its record button appearance.
    /// Must be called on the main actor since `OSDRecordingObserver` is `@MainActor`-isolated.
    @MainActor private func notifyOSDRecordingStateChanged() {
        (controllerViewController as? OSDRecordingObserver)?.updateRecordButtonAppearance()
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


// MARK: - Clip Capture (iOS/tvOS 15+)

extension PVEmulatorViewController {

    /// Whether always-on clip buffering is currently active.
    public var isClipBufferingActive: Bool {
        AppState.shared.emulationUIState.isClipBufferingActive
    }

    /// Starts always-on clip buffering when the recorder is available.
    /// No-op on iOS < 15 / tvOS < 15.
    ///
    /// Buffering itself starts unconditionally — only the **SAVE CLIP** UI action
    /// is gated behind Provenance Plus.  This ensures the rolling buffer is warm
    /// so that when the user does tap "Save Clip", recent footage is available.
    public func startClipBufferingIfAvailable() {
        guard #available(iOS 15.0, tvOS 15.0, *) else { return }
        guard PVRecordingManager.shared.isAvailable else { return }
        Task { @MainActor in
            do {
                try await PVRecordingManager.shared.startClipBuffering()
                AppState.shared.emulationUIState.isClipBufferingActive = true
                ILOG("[ClipCapture] Clip buffering started")
            } catch {
                ELOG("[ClipCapture] Could not start clip buffering: \(error.localizedDescription)")
            }
        }
    }

    /// Stops always-on clip buffering. Called when the game exits.
    public func stopClipBuffering() {
        guard #available(iOS 15.0, tvOS 15.0, *) else { return }
        guard isClipBufferingActive else { return }
        Task { @MainActor in
            await PVRecordingManager.shared.stopClipBuffering()
            // Sync UI state with the actual recorder state after the stop attempt.
            AppState.shared.emulationUIState.isClipBufferingActive = PVRecordingManager.shared.isClipBuffering
        }
    }

    /// Exports the last `duration` seconds as a clip and saves it to Photos (iOS)
    /// or the app's Documents folder (tvOS).
    public func saveClip(duration: TimeInterval = 30.0) {
        guard #available(iOS 15.0, tvOS 15.0, *) else { return }
        Task { @MainActor in
            do {
                let url = try await PVRecordingManager.shared.exportClip(duration: duration)
                saveClipToStorage(url: url)
            } catch {
                ELOG("[ClipCapture] Failed to export clip: \(error.localizedDescription)")
                showClipAlert(title: "Clip Error", message: error.localizedDescription)
            }
        }
    }

    private func saveClipToStorage(url: URL) {
        #if os(iOS)
        // Request add-only authorization before writing so that if the user has
        // denied or restricted access we can show a meaningful error rather than
        // silently failing inside performChanges.
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard let self else { return }
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    ELOG("[ClipCapture] Photos access denied (status: \(status.rawValue))")
                    self.showClipAlert(
                        title: "Photos Access Required",
                        message: "Allow Provenance to add to Photos in Settings > Privacy > Photos."
                    )
                }
                return
            }
            // Save to Camera Roll on iOS using PHPhotoLibrary for proper success/failure reporting.
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        ILOG("[ClipCapture] Clip saved to Photos")
                        // Clean up the temporary file now that it's safely in Photos.
                        try? FileManager.default.removeItem(at: url)
                        self?.showClipAlert(title: "Clip Saved", message: "Your gameplay clip was saved to Photos.")
                    } else {
                        let msg = error?.localizedDescription ?? "Unknown error"
                        ELOG("[ClipCapture] Failed to save clip to Photos: \(msg)")
                        self?.showClipAlert(title: "Clip Error", message: "Failed to save to Photos: \(msg)")
                    }
                }
            }
        }
        #elseif os(tvOS)
        // tvOS has no Photos write API — copy to the app's Documents folder instead.
        // The clip can then be accessed via Finder/iTunes File Sharing or developer
        // tools such as Xcode's device container download.
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docsURL.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            try FileManager.default.removeItem(at: url)
            ILOG("[ClipCapture] Clip saved to Documents: \(destURL.lastPathComponent)")
            showClipAlert(title: "Clip Saved", message: "Your gameplay clip was saved to the app's Documents folder.")
        } catch {
            ELOG("[ClipCapture] Failed to move clip to Documents: \(error.localizedDescription)")
            showClipAlert(title: "Clip Error", message: error.localizedDescription)
        }
        #endif
    }

    private func showClipAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
#endif // os(iOS) || os(tvOS)
