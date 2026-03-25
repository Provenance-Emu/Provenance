//
//  PVCameraOverlayView.swift
//  PVUI
//
//  Face-cam picture-in-picture overlay displayed during ReplayKit recording.
//  Wraps `RPScreenRecorder.cameraPreviewLayer` and positions it in a
//  configurable corner of the parent view.
//

#if os(iOS)
import UIKit
import ReplayKit
import Defaults
import PVSettings
import PVLogging

// MARK: - PVCameraOverlayView

/// A `UIView` that hosts the `RPScreenRecorder.cameraPreviewLayer` as a
/// face-cam picture-in-picture overlay during screen recording.
///
/// Usage:
/// ```swift
/// let overlay = PVCameraOverlayView()
/// view.addSubview(overlay)
/// overlay.startObservingSettings()
/// overlay.attach()   // call after startRecording succeeds
/// // …
/// overlay.detach()   // call after stopRecording / discard
/// ```
///
/// The view observes `Defaults` for live changes to position, size, and shape so
/// that the user can tweak the overlay appearance in Settings without restarting.
@MainActor public final class PVCameraOverlayView: UIView {

    // MARK: - State

    /// Whether `cameraPreviewLayer` has been successfully added.
    public private(set) var isAttached: Bool = false

    /// The ReplayKit-supplied preview layer, retained while recording is active.
    private weak var cameraLayer: CALayer?

    /// Inset from the safe-area edge in points.
    private let edgeInset: CGFloat = 16

    /// Handles for the Defaults observation tasks; cancelled when the overlay is detached or deallocated.
    private var observationTasks: [Task<Void, Never>] = []

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
    }

    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = .clear
        // Ensure the overlay renders on top of the game content.
        layer.zPosition = 100
    }

    // MARK: - Public API

    /// Attaches `RPScreenRecorder.cameraPreviewLayer` to this view and makes it visible.
    ///
    /// Call this **after** `RPScreenRecorder.startRecording()` completes successfully
    /// and `recordingCameraEnabled` is `true`.  If `cameraPreviewLayer` is `nil`
    /// (recording not active or camera permission denied) this is a no-op.
    ///
    /// Camera enable/disable (`isCameraEnabled`) is owned by the recording lifecycle
    /// caller, not this view.
    public func attach() {
        guard !isAttached else { return }
        guard Defaults[.recordingCameraEnabled] else { return }

        let recorder = RPScreenRecorder.shared()

        guard let layer = recorder.cameraPreviewLayer else {
            WLOG("[CameraOverlay] cameraPreviewLayer is nil — camera may not be permitted")
            return
        }

        cameraLayer = layer
        self.layer.addSublayer(layer)
        applyCurrentSettings()
        isHidden = false
        isAttached = true
        ILOG("[CameraOverlay] Camera overlay attached")
    }

    /// Removes the camera layer and hides the view.
    ///
    /// Call this after `stopRecording()` or `discardRecording()` returns.
    /// Camera enable/disable is owned by the recording lifecycle caller, not this view.
    public func detach() {
        // Always stop observing settings and clean up the camera layer, even if we were never attached.
        stopObservingSettings()
        cameraLayer?.removeFromSuperlayer()
        cameraLayer = nil
        isHidden = true

        if isAttached {
            isAttached = false
            ILOG("[CameraOverlay] Camera overlay detached")
        }
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard isAttached else { return }
        applyCurrentSettings()
    }

    // MARK: - Private helpers

    /// Reads current Defaults and repositions / resizes / reshapes the camera layer.
    private func applyCurrentSettings() {
        guard let cameraLayer else { return }

        let size = CGFloat(Defaults[.cameraOverlaySize].points)
        let position = Defaults[.recordingCameraPosition]
        let shape = Defaults[.cameraOverlayShape]

        let safeArea = superview?.safeAreaInsets ?? .zero
        let parentBounds = superview?.bounds ?? bounds

        // Compute origin based on corner selection.
        let x: CGFloat
        let y: CGFloat
        switch position {
        case .topLeft:
            x = safeArea.left + edgeInset
            y = safeArea.top + edgeInset
        case .topRight:
            x = parentBounds.width - safeArea.right - edgeInset - size
            y = safeArea.top + edgeInset
        case .bottomLeft:
            x = safeArea.left + edgeInset
            y = parentBounds.height - safeArea.bottom - edgeInset - size
        case .bottomRight:
            x = parentBounds.width - safeArea.right - edgeInset - size
            y = parentBounds.height - safeArea.bottom - edgeInset - size
        }

        let cornerRadius: CGFloat
        switch shape {
        case .circle:
            cornerRadius = size / 2
        case .roundedRect:
            cornerRadius = size / 5
        }

        let cameraRect = CGRect(x: x, y: y, width: size, height: size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cameraLayer.frame = cameraRect
        cameraLayer.cornerRadius = cornerRadius
        cameraLayer.masksToBounds = true

        // Subtle drop shadow scoped to the camera PIP rect for correctness and performance.
        // Setting shadowPath avoids CoreAnimation rasterising the full-screen view bounds.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowPath = UIBezierPath(roundedRect: cameraRect, cornerRadius: cornerRadius).cgPath

        CATransaction.commit()
    }
}

// MARK: - Settings observation

extension PVCameraOverlayView {
    /// Re-apply layout whenever the user changes overlay preferences in Settings.
    ///
    /// Call before each `attach()` — including when reusing an existing overlay
    /// after a previous `detach()`, which cancels observation tasks.
    /// Tasks are stored and cancelled when `detach()` is called or the view is deallocated.
    public func startObservingSettings() {
        stopObservingSettings()
        observationTasks = [
            Task { @MainActor [weak self] in
                for await _ in Defaults.updates(.recordingCameraPosition) {
                    guard !Task.isCancelled else { break }
                    self?.applyCurrentSettings()
                }
            },
            Task { @MainActor [weak self] in
                for await _ in Defaults.updates(.cameraOverlaySize) {
                    guard !Task.isCancelled else { break }
                    self?.applyCurrentSettings()
                }
            },
            Task { @MainActor [weak self] in
                for await _ in Defaults.updates(.cameraOverlayShape) {
                    guard !Task.isCancelled else { break }
                    self?.applyCurrentSettings()
                }
            }
        ]
    }

    /// Cancels all active Defaults observation tasks.
    public func stopObservingSettings() {
        observationTasks.forEach { $0.cancel() }
        observationTasks = []
    }
}
#endif // os(iOS)
