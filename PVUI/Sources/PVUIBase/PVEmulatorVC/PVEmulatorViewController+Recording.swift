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
    public var isRecording: Bool {
        PVRecordingManager.shared.isRecording
    }

    /// Starts a ReplayKit screen recording session.
    /// Updates `AppState.shared.emulationUIState.isRecording` on success.
    public func startScreenRecording() {
        PVRecordingManager.shared.startRecording { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                ELOG("[Recording] Could not start recording: \(error.localizedDescription)")
                self.showRecordingError(error)
            } else {
                AppState.shared.emulationUIState.isRecording = true
                ILOG("[Recording] Recording started")
            }
        }
    }

    /// Stops the current ReplayKit recording and presents the share sheet.
    public func stopScreenRecording() {
        PVRecordingManager.shared.stopRecording(presenter: self) { [weak self] error in
            guard let self = self else { return }
            AppState.shared.emulationUIState.isRecording = false
            if let error = error {
                ELOG("[Recording] Could not stop recording: \(error.localizedDescription)")
                self.showRecordingError(error)
            } else {
                ILOG("[Recording] Recording stopped and preview presented")
            }
        }
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
