//
//  PVRecordingManager.swift
//  PVUI
//
//  Created by Claude on 3/7/26.
//

#if os(iOS)
import ReplayKit
import UIKit
import PVLogging

/// Manages ReplayKit screen recording for Provenance.
///
/// `@MainActor`-isolated — all properties and methods are safe to access from
/// SwiftUI views and `UIViewController` call sites without additional dispatching.
@MainActor public final class PVRecordingManager {

    public static let shared = PVRecordingManager()

    /// Whether a recording session is currently active.
    public private(set) var isRecording: Bool = false

    /// Whether the recorder is available on this device/session.
    public var isAvailable: Bool {
        RPScreenRecorder.shared().isAvailable
    }

    /// Separate `NSObject` subclass used as `RPPreviewViewControllerDelegate`,
    /// keeping `PVRecordingManager` free of Objective-C inheritance.
    private let previewDelegate = PreviewDelegate()

    /// Called on the main actor after the ReplayKit preview sheet is dismissed.
    /// Set this before calling `stopRecording` to be notified when the user is done
    /// with the recording preview (saved, discarded, or cancelled).
    public var onPreviewDismissed: (() -> Void)?

    private init() {}

    // MARK: - Public API

    /// Starts a screen recording session with microphone audio enabled.
    /// - Throws: `RecordingError.unavailable` if the recorder is not available,
    ///   or an `RPScreenRecorder` error if recording could not start.
    public func startRecording() async throws {
        guard isAvailable else {
            WLOG("[Recording] RPScreenRecorder not available")
            throw RecordingError.unavailable
        }

        guard !isRecording else {
            WLOG("[Recording] Already recording — ignoring startRecording call")
            return
        }

        let recorder = RPScreenRecorder.shared()
        recorder.isMicrophoneEnabled = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.startRecording { error in
                if let error {
                    ELOG("[Recording] Failed to start recording: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        isRecording = true
        ILOG("[Recording] Recording started successfully")
    }

    /// Stops the current recording session and presents the share sheet.
    /// - Parameter presenter: The view controller from which to present `RPPreviewViewController`.
    /// - Throws: An `RPScreenRecorder` error if stopping failed.
    public func stopRecording(presenter: UIViewController) async throws {
        guard isRecording else {
            WLOG("[Recording] Not currently recording — ignoring stopRecording call")
            return
        }

        let previewVC: RPPreviewViewController? = try await withCheckedThrowingContinuation { continuation in
            RPScreenRecorder.shared().stopRecording { previewVC, error in
                if let error {
                    ELOG("[Recording] Failed to stop recording: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: previewVC)
                }
            }
        }

        isRecording = false

        guard let previewVC else {
            WLOG("[Recording] No preview controller returned after stop")
            return
        }

        previewVC.previewControllerDelegate = previewDelegate
        previewVC.modalPresentationStyle = .fullScreen
        // Transfer the callback to the delegate; clear it so it isn't re-used
        previewDelegate.onFinished = onPreviewDismissed
        onPreviewDismissed = nil
        await presenter.present(previewVC, animated: true)
        ILOG("[Recording] Preview controller presented")
    }

    /// Discards any in-progress recording without presenting the preview.
    public func discardRecording() {
        guard isRecording else { return }
        RPScreenRecorder.shared().discardRecording {
            ILOG("[Recording] Recording discarded")
        }
        isRecording = false
    }
}

// MARK: - Private Delegate

extension PVRecordingManager {
    private final class PreviewDelegate: NSObject, RPPreviewViewControllerDelegate {
        /// Called on the main actor after the preview sheet is dismissed.
        var onFinished: (() -> Void)?

        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            previewController.dismiss(animated: true) { [weak self] in
                ILOG("[Recording] Preview controller dismissed")
                let action = self?.onFinished
                self?.onFinished = nil
                action?()
            }
        }
    }
}

// MARK: - Errors

extension PVRecordingManager {
    public enum RecordingError: LocalizedError {
        case unavailable

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Screen recording is not available on this device or in this session."
            }
        }
    }
}
#endif
