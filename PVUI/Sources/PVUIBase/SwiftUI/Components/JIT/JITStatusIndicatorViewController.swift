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
@MainActor
public final class JITStatusIndicatorViewController: UIViewController {

    public let viewModel = JITStatusViewModel()
    private var hostingController: UIHostingController<JITStatusIndicatorView>?
    private var cancellables = Set<AnyCancellable>()

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
    /// This replaces the previous SwiftUI popover / cover-sheet approach.
    private func presentStatusAlert() {
        let title = viewModel.status.label.isEmpty ? "JIT Status" : viewModel.status.label
        let message = viewModel.explanation

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // Present from the parent (emulator) VC so the alert sits above the game view
        let presenter = parent ?? self
        presenter.present(alert, animated: true)
    }

    private func setupNotificationObservers() {
        #if canImport(PVJIT)
        // Listen for JIT acquisition notifications
        NotificationCenter.default.publisher(for: .DOLJitAcquired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.updateStatus()
            }
            .store(in: &cancellables)
        #endif

        // Also set up a periodic check in case the JIT status changes
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.viewModel.updateStatus()
            }
            .store(in: &cancellables)
    }

    /// Updates the status based on whether the core requires JIT
    /// - Parameter requiresJIT: Whether the current core requires JIT
    public func updateForCore(requiresJIT: Bool) {
        if requiresJIT {
            viewModel.updateStatus()
        } else {
            viewModel.status = .notApplicable
        }
    }

    /// Manually refresh the JIT status
    public func refreshStatus() {
        viewModel.updateStatus()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
