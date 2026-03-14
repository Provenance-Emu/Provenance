//
//  JITStatusIndicatorViewController.swift
//  PVUIBase
//
//  UIKit host for the JIT status indicator overlay.
//  Part of issue #2796.
//

import SwiftUI
import Combine
#if canImport(PVJIT)
import PVJIT
#endif

// MARK: - PassthroughView

/// A transparent container view that forwards touches to its subviews only.
/// Any touch that does not land on a subview returns `nil` from `hitTest`,
/// letting it fall through to the game view beneath the overlay.
private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

// MARK: - JITStatusIndicatorViewController

/// A UIViewController that hosts the SwiftUI JIT status indicator.
/// Add it as a child of `PVEmulatorViewController` so it floats above the GPU view.
///
/// The root view is a `PassthroughView` so touches outside the pill fall through
/// to the game content below.  When the user taps the pill, a compact
/// `UIAlertController` is presented from the nearest view controller in the
/// hierarchy — no full-screen cover sheet.
///
/// ## PVToast notifications
/// Status transitions automatically post in-game toasts via `PVToastManager`:
///  - JIT acquired → `.jit` success toast (auto-dismissed after 4 s)
///  - JIT unavailable for a required core → persistent `.error` toast until status changes
@MainActor
public final class JITStatusIndicatorViewController: UIViewController {

    public let viewModel = JITStatusViewModel()
    private var hostingController: UIHostingController<JITStatusIndicatorView>?
    private var cancellables = Set<AnyCancellable>()

    /// Stable id for the persistent "JIT unavailable" toast so it can be deduped / dismissed.
    private let jitUnavailableToastID = "jit-unavailable"
    /// Previous status, used to detect transitions for toast firing.
    private var previousStatus: JITStatus = .notApplicable

    public override func loadView() {
        let passthrough = PassthroughView()
        passthrough.backgroundColor = .clear
        passthrough.isUserInteractionEnabled = true
        view = passthrough
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
        setupNotificationObservers()
    }

    private func setupHostingController() {
        let indicatorView = JITStatusIndicatorView(viewModel: viewModel, onTap: { [weak self] in
            self?.presentStatusAlert()
        })
        let host = UIHostingController(rootView: indicatorView)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = true

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        // Position in the top-left corner (opposite to FPS HUD which is top-right)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            host.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            host.view.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])

        host.didMove(toParent: self)
        hostingController = host
    }

    /// Presents a compact `UIAlertController` describing the current JIT status.
    private func presentStatusAlert() {
        let title = viewModel.status.label.isEmpty ? "JIT Status" : viewModel.status.label
        let message = viewModel.explanation

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // Present from the parent (emulator) VC so the alert sits above the game view
        let presenter = parent ?? self
        guard presenter.presentedViewController == nil else {
            return
        }
        presenter.present(alert, animated: true)
    }

    private func setupNotificationObservers() {
        #if canImport(PVJIT)
        // Listen for JIT acquisition notifications
        NotificationCenter.default.publisher(for: .DOLJitAcquired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.updateStatus()
                self?.handleStatusTransition()
            }
            .store(in: &cancellables)
        #endif

        // Periodic check in case the JIT status changes between notification posts
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.viewModel.updateStatus()
                self?.handleStatusTransition()
            }
            .store(in: &cancellables)
    }

    /// Posts PVToast notifications when the JIT status transitions to a new state.
    private func handleStatusTransition() {
        let newStatus = viewModel.status
        guard newStatus != previousStatus else { return }
        defer { previousStatus = newStatus }

        switch newStatus {
        case .active:
            // Dismiss any lingering "unavailable" toast
            PVToastManager.shared.dismiss(id: jitUnavailableToastID)
            let label = viewModel.indicatorLabel
            PVToastManager.shared.show("JIT active — \(label)", type: .jit, duration: 4.0)

        case .unavailable:
            // Persistent toast so the user always sees the guidance
            PVToastManager.shared.showPersistent(
                "JIT required — enable via AltStore, SideJITServer, or StikDebug",
                id: jitUnavailableToastID,
                type: .error,
                icon: "bolt.slash.fill"
            )

        case .interpreterFallback:
            PVToastManager.shared.dismiss(id: jitUnavailableToastID)
            if previousStatus == .active {
                PVToastManager.shared.show(
                    "JIT lost — running in compatibility mode",
                    type: .warning,
                    duration: 5.0
                )
            }

        case .notApplicable:
            PVToastManager.shared.dismiss(id: jitUnavailableToastID)
        }
    }

    // MARK: - Public API

    /// Updates the indicator for the given core identifier.
    ///
    /// Looks up `JITCoreCapability` to determine both whether the indicator
    /// should be shown (`isJITRelevant`) and whether the core strictly requires JIT
    /// (`coreIsJITRequired`), which gates the `.unavailable` status.
    public func updateForCore(id coreIdentifier: String) {
        let isRelevant = JITCoreCapability.isJITRelevant(coreIdentifier)
        let isRequired = JITCoreCapability.coreIsJITRequired(coreIdentifier)

        if isRelevant {
            viewModel.coreJITIsRequired = isRequired
            viewModel.updateStatus()
            handleStatusTransition()
        } else {
            viewModel.coreJITIsRequired = false
            viewModel.status = .notApplicable
            handleStatusTransition()
        }
    }

    /// Updates the status based on whether the current core requires JIT.
    /// Prefer `updateForCore(id:)` when you have the core identifier available,
    /// as it also determines whether JIT is strictly required vs. merely beneficial.
    public func updateForCore(requiresJIT: Bool) {
        if requiresJIT {
            viewModel.coreJITIsRequired = true
            viewModel.updateStatus()
            handleStatusTransition()
        } else {
            viewModel.coreJITIsRequired = false
            viewModel.status = .notApplicable
            handleStatusTransition()
        }
    }

    /// Manually refresh the JIT status
    public func refreshStatus() {
        viewModel.updateStatus()
        handleStatusTransition()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
