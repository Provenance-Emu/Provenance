//
//  PVIndicatorOverlayViewController.swift
//  PVUIBase
//
//  UIKit host controller for the indicator light overlay in the emulator HUD.
//
//  Usage (from PVEmulatorViewController):
//    indicatorOverlayController = PVIndicatorOverlayViewController()
//    addChild(indicatorOverlayController)
//    view.addSubview(indicatorOverlayController.view)
//    indicatorOverlayController.didMove(toParent: self)
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Combine
import PVSettings
import PVLogging

// MARK: - Overlay View Controller

/// A UIViewController that hosts the SwiftUI indicator overlay.
/// Add it as a child of `PVEmulatorViewController` so it floats above the GPU view.
@MainActor
public final class PVIndicatorOverlayViewController: UIViewController {

    private var hostingController: UIHostingController<PVIndicatorOverlayView>?
    private var cancellables = Set<AnyCancellable>()

    /// Whether the overlay should be visible (controlled by user preference).
    public var isOverlayEnabled: Bool {
        get { Defaults[.showStatusIndicators] }
        set {
            Defaults[.showStatusIndicators] = newValue
            updateVisibility()
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupObservers()
        refreshJITState()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateVisibility()
    }

    // MARK: - Setup

    private func setupView() {
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let overlayView = PVIndicatorOverlayView(registry: PVIndicatorRegistry.shared)
        let host = UIHostingController(rootView: overlayView)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = true

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host

        updateVisibility()
    }

    private func setupObservers() {
        // Observe setting changes
        Defaults.publisher(.showStatusIndicators)
            .sink { [weak self] _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)

        // Observe indicator registry changes
        PVIndicatorRegistry.shared.$indicators
            .sink { [weak self] _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)
    }

    // MARK: - Visibility

    private func updateVisibility() {
        let shouldShow = isOverlayEnabled && PVIndicatorRegistry.shared.hasVisibleIndicators
        view.isHidden = !shouldShow
        hostingController?.view.isUserInteractionEnabled = shouldShow
    }

    // MARK: - Public Interface

    /// Refreshes the JIT indicator state.
    /// Call this when the emulator starts to ensure correct initial state.
    public func refreshJITState() {
        guard isOverlayEnabled else { return }
        PVIndicatorRegistry.shared.refreshJITState()
    }

    /// Shows or hides the overlay based on the user preference.
    public func updateOverlayVisibility() {
        updateVisibility()
    }

    /// Temporarily hides the overlay (e.g., during menu presentation).
    public func temporarilyHide() {
        view.isHidden = true
    }

    /// Restores the overlay visibility based on settings.
    public func restoreVisibility() {
        updateVisibility()
    }
}
