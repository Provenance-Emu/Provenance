//
//  PVEmulatorViewController+Recording.swift
//  PVUI
//
//  Created by Claude on 3/7/26.
//

#if os(iOS)
import UIKit
import PVLogging

// MARK: - Screen Recording

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
    public func stopScreenRecording() {
        Task { @MainActor in
            do {
                try await PVRecordingManager.shared.stopRecording(presenter: self)
                AppState.shared.emulationUIState.isRecording = false
                ILOG("[Recording] Recording stopped and preview presented")
            } catch {
                AppState.shared.emulationUIState.isRecording = false
                ELOG("[Recording] Could not stop recording: \(error.localizedDescription)")
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
