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
/// All public methods must be called on the main thread.
public final class PVRecordingManager: NSObject {

    public static let shared = PVRecordingManager()

    /// Whether a recording session is currently active.
    public private(set) var isRecording: Bool = false

    /// Whether the recorder is available on this device/session.
    public var isAvailable: Bool {
        RPScreenRecorder.shared().isAvailable
    }

    private override init() {
        super.init()
    }

    /// Starts a screen recording session with microphone audio enabled.
    /// - Parameter completion: Called on the main queue. Receives an error if recording could not start.
    public func startRecording(completion: @escaping (Error?) -> Void) {
        guard isAvailable else {
            WLOG("[Recording] RPScreenRecorder not available")
            completion(RecordingError.unavailable)
            return
        }

        guard !isRecording else {
            WLOG("[Recording] Already recording — ignoring startRecording call")
            completion(nil)
            return
        }

        let recorder = RPScreenRecorder.shared()
        recorder.isMicrophoneEnabled = true

        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    ELOG("[Recording] Failed to start recording: \(error.localizedDescription)")
                    self?.isRecording = false
                    completion(error)
                } else {
                    ILOG("[Recording] Recording started successfully")
                    self?.isRecording = true
                    completion(nil)
                }
            }
        }
    }

    /// Stops the current recording session and presents the share sheet.
    /// - Parameters:
    ///   - presenter: The view controller from which to present the RPPreviewViewController.
    ///   - completion: Called on the main queue after the preview controller is presented (or on error).
    public func stopRecording(presenter: UIViewController, completion: @escaping (Error?) -> Void) {
        guard isRecording else {
            WLOG("[Recording] Not currently recording — ignoring stopRecording call")
            completion(nil)
            return
        }

        RPScreenRecorder.shared().stopRecording { [weak self, weak presenter] previewVC, error in
            DispatchQueue.main.async {
                self?.isRecording = false

                if let error = error {
                    ELOG("[Recording] Failed to stop recording: \(error.localizedDescription)")
                    completion(error)
                    return
                }

                guard let previewVC = previewVC else {
                    WLOG("[Recording] No preview controller returned after stop")
                    completion(nil)
                    return
                }

                guard let presenter = presenter else {
                    WLOG("[Recording] Presenter was deallocated, cannot show preview")
                    completion(nil)
                    return
                }

                previewVC.previewControllerDelegate = self
                previewVC.modalPresentationStyle = .fullScreen
                presenter.present(previewVC, animated: true) {
                    completion(nil)
                }
            }
        }
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

// MARK: - RPPreviewViewControllerDelegate

extension PVRecordingManager: RPPreviewViewControllerDelegate {
    public func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
        ILOG("[Recording] Preview controller dismissed")
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
