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

        // Top-left corner, respecting the safe area so it clears the notch/Dynamic Island
        // and lands above the skin controller area (which is at the bottom/sides).
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            host.view.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
        ])

        host.didMove(toParent: self)
        hostingController = host
    }

    /// Presents a compact `UIAlertController` describing the current JIT status.
    ///
    /// The alert title and message are tailored to the core's support level:
    /// - **JIT Required**: strong call to action with setup instructions
    /// - **JIT Recommended**: explains performance benefit and how to enable
    /// - **JIT Auto-Managed**: informs the user no action is needed
    /// - **JIT Active**: confirms optimal performance is running
    private func presentStatusAlert() {
        let title = viewModel.alertTitle
        let message = viewModel.explanation

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // When JIT is inactive and the user should take action, add a second button
        // that opens the app's JIT settings (if available via PVSettings) or shows
        // the in-app guide for enabling JIT.
        if viewModel.coreSupportLevel.requiresUserAction && viewModel.status != .active {
            let settingsAction = UIAlertAction(title: "How to Enable JIT", style: .default) { [weak self] _ in
                self?.presentJITEnableGuide()
            }
            alert.addAction(settingsAction)
        }

        // Present from the parent (emulator) VC so the alert sits above the game view
        let presenter = parent ?? self
        guard presenter.presentedViewController == nil else {
            return
        }
        presenter.present(alert, animated: true)
    }

    /// Presents a brief guide alert listing ways to enable JIT.
    private func presentJITEnableGuide() {
        let guide = UIAlertController(
            title: "Enabling JIT",
            message: """
            JIT compilation can be enabled using one of the following tools:

            • AltStore / AltServer — free, requires a Mac or PC to refresh periodically
            • SideStore — wireless alternative to AltStore
            • SideJITServer — lightweight local server for over-the-air JIT
            • StikDebug — on-device JIT enabler (requires compatible setup)
            • TrollStore — permanent JIT for supported iOS/iPadOS versions

            After enabling JIT, return to the game and the indicator will update automatically.
            """,
            preferredStyle: .alert
        )
        guide.addAction(UIAlertAction(title: "OK", style: .default))

        let presenter = parent ?? self
        guard presenter.presentedViewController == nil else { return }
        presenter.present(guide, animated: true)
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
    /// Delegates to `JITCoreCapability.isJITRelevant(_:)` and `coreIsJITRequired(_:)`,
    /// which consult `PVJITRequirementRegistry` (runtime plist data) first and fall back
    /// to compile-time keyword matching for partial identifiers or pre-CoreLoader contexts.
    public func updateForCore(id coreIdentifier: String) {
        let isRelevant = JITCoreCapability.isJITRelevant(coreIdentifier)
        let isRequired = JITCoreCapability.coreIsJITRequired(coreIdentifier)
        let supportLevel: CoreJITSupportLevel = isRelevant
            ? (isRequired ? .required : .recommended(fallbackMode: "Compatibility"))
            : .notApplicable
        updateForCore(isRelevant: isRelevant, isRequired: isRequired, supportLevel: supportLevel)
    }

    /// Updates the indicator with explicit relevancy, requirement, and support-level information.
    ///
    /// This is the preferred entry-point when the authoritative `PVJITRequirement` is available.
    /// - Parameters:
    ///   - isRelevant: `true` when the core uses JIT at all (show the HUD pill).
    ///     Pass `core.jitRequirement.hasJIT`.
    ///   - isRequired: `true` when the core requires JIT to run without crashing.
    ///     Pass `core.jitRequirement == .requiredOrCrash`.
    ///   - supportLevel: `CoreJITSupportLevel` derived from `PVJITRequirement` for rich messaging.
    public func updateForCore(isRelevant: Bool, isRequired: Bool, supportLevel: CoreJITSupportLevel) {
        if isRelevant {
            viewModel.coreSupportLevel = supportLevel
            viewModel.coreJITIsRequired = isRequired
            viewModel.updateStatus()
            handleStatusTransition()
        } else {
            viewModel.coreSupportLevel = .notApplicable
            viewModel.coreJITIsRequired = false
            viewModel.status = .notApplicable
            handleStatusTransition()
        }
    }

    /// Updates the status based on whether the current core requires JIT.
    ///
    /// When `requiresJIT` is `false`, the core is treated as JIT-relevant but not required
    /// (i.e. the indicator remains visible with `.interpreterFallback` status when JIT is
    /// inactive).  The `.notApplicable` state is only set when the core genuinely has no JIT
    /// path, which should be gated upstream by `coreRequiresJIT()`.
    ///
    /// Prefer `updateForCore(isRelevant:isRequired:supportLevel:)` when you have the full
    /// `PVJITRequirement` available, as it enables differentiated support-level messaging.
    public func updateForCore(requiresJIT: Bool) {
        viewModel.coreSupportLevel = requiresJIT ? .required : .recommended(fallbackMode: "Compatibility")
        viewModel.coreJITIsRequired = requiresJIT
        viewModel.updateStatus()
        handleStatusTransition()
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
