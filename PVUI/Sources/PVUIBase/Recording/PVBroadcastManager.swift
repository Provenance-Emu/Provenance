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
/// On iOS 12+ this wraps `RPBroadcastPickerView` (the system broadcast-service
/// sheet).  On tvOS 13+ it falls back to `RPBroadcastActivityViewController`
/// because `RPBroadcastPickerView` is not available on tvOS.
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

    /// Presents the system broadcast-service picker from `presenter`.
    ///
    /// If a broadcast is already active, calling this method stops it instead.
    ///
    /// - Parameter presenter: The `UIViewController` from which to present the picker.
    public func showBroadcastPicker(from presenter: UIViewController) {
        if isBroadcasting {
            stopBroadcast()
            return
        }

#if os(iOS)
        showPickerViewiOS(from: presenter)
#else
        showActivityViewControllerTvOS(from: presenter)
#endif
    }

    // MARK: - Internal (fileprivate for hosting VC)

    fileprivate func handleBroadcastStarted(controller: RPBroadcastController) {
        broadcastController = controller
        isBroadcasting = true
        ILOG("[Broadcast] Broadcast started: \(controller.serviceIdentifier ?? "unknown")")
    }

    fileprivate func handleBroadcastFinished() {
        broadcastController = nil
        isBroadcasting = false
        ILOG("[Broadcast] Broadcast stopped")
    }

    // MARK: - Private helpers

    private func stopBroadcast() {
        guard let controller = broadcastController else {
            isBroadcasting = false
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

#if os(iOS)
    /// iOS: embed `RPBroadcastPickerView` in a transparent hosting VC and simulate a tap.
    private func showPickerViewiOS(from presenter: UIViewController) {
        let pickerView = RPBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        pickerView.preferredExtensionBundleIdentifier = nil // let user choose

        let hostVC = BroadcastPickerHostViewController(pickerView: pickerView, delegate: self)
        hostVC.modalPresentationStyle = .overCurrentContext
        hostVC.view.backgroundColor = .clear
        presenter.present(hostVC, animated: false) {
            hostVC.triggerPicker()
        }
        ILOG("[Broadcast] RPBroadcastPickerView presented (iOS)")
    }
#else
    /// tvOS: use `RPBroadcastActivityViewController` to choose a broadcast provider.
    private func showActivityViewControllerTvOS(from presenter: UIViewController) {
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
                await presenter.present(activityVC, animated: true)
                ILOG("[Broadcast] RPBroadcastActivityViewController presented (tvOS)")
            }
        }
    }
#endif
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

// MARK: - RPBroadcastActivityViewControllerDelegate (tvOS)

#if os(tvOS)
extension PVBroadcastManager: RPBroadcastActivityViewControllerDelegate {
    public nonisolated func broadcastActivityViewController(
        _ broadcastActivityViewController: RPBroadcastActivityViewController,
        didFinishWith broadcastController: RPBroadcastController?,
        error: Error?
    ) {
        if let error {
            ELOG("[Broadcast] Activity VC finished with error: \(error.localizedDescription)")
            Task { @MainActor in self.handleBroadcastFinished() }
            return
        }
        guard let controller = broadcastController else {
            WLOG("[Broadcast] Activity VC finished without a controller")
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
        Task { @MainActor in
            broadcastActivityViewController.dismiss(animated: true)
        }
    }
}
#endif

// MARK: - Private hosting view controller (iOS only)

#if os(iOS)
/// Minimal `UIViewController` that hosts an `RPBroadcastPickerView` off-screen
/// and programmatically triggers its internal button to show the system sheet.
private final class BroadcastPickerHostViewController: UIViewController {
    private let pickerView: RPBroadcastPickerView
    private weak var delegate: PVBroadcastManager?

    init(pickerView: RPBroadcastPickerView, delegate: PVBroadcastManager) {
        self.pickerView = pickerView
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(pickerView)
        pickerView.center = view.center
    }

    /// Programmatically activates the `RPBroadcastPickerView` button so the
    /// system sheet appears without requiring a real touch event.
    func triggerPicker() {
        // The picker view contains a UIButton subview; simulate a tap on it.
        for subview in pickerView.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            }
        }
        // Fallback: walk one more level deep.
        for subview in pickerView.subviews {
            for child in subview.subviews {
                if let button = child as? UIButton {
                    button.sendActions(for: .touchUpInside)
                    return
                }
            }
        }
        WLOG("[Broadcast] Could not find RPBroadcastPickerView button to trigger")
    }
}
#endif
#endif // os(iOS) || os(tvOS)
