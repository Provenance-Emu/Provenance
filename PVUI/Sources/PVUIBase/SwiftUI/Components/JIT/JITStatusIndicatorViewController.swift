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

/// A UIViewController that hosts the SwiftUI JIT status indicator.
/// Add it as a child of `PVEmulatorViewController` so it floats above the GPU view.
@MainActor
public final class JITStatusIndicatorViewController: UIViewController {

    public let viewModel = JITStatusViewModel()
    private var hostingController: UIHostingController<JITStatusIndicatorView>?
    private var cancellables = Set<AnyCancellable>()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        setupHostingController()
        setupNotificationObservers()
    }

    private func setupHostingController() {
        let indicatorView = JITStatusIndicatorView(viewModel: viewModel)
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
