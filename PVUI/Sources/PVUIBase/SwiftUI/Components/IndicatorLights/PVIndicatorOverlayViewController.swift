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

// MARK: - Pass-Through View

/// A full-screen container view whose touch handling only claims hits that land on an
/// interactive subview.  Any tap in the empty space between indicators falls through to
/// the controller overlay and game view underneath.
///
/// Uses explicit subview iteration so the container itself can never claim a touch,
/// matching the pattern used by `QuickActionsContainerView` in PVControllerViewController.
private final class PassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        for subview in subviews.reversed() {
            let convertedPoint = convert(point, to: subview)
            if let hit = subview.hitTest(convertedPoint, with: event) {
                return hit
            }
        }
        return nil
    }
}

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

    public override func loadView() {
        // Use a pass-through root view so dead-zone touches reach the controller overlay below.
        view = PassThroughView()
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
        // isUserInteractionEnabled is managed by updateVisibility(); start disabled so
        // the overlay never blocks touches when no indicators are shown.
        view.isUserInteractionEnabled = false

        let overlayView = PVIndicatorOverlayView(registry: PVIndicatorRegistry.shared)
        let host = UIHostingController(rootView: overlayView)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false

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
        // Only enable user interaction when indicators are actually visible so the
        // overlay never intercepts game or controller-button touches in empty areas.
        view.isUserInteractionEnabled = shouldShow
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
        view.isUserInteractionEnabled = false
        hostingController?.view.isUserInteractionEnabled = false
    }

    /// Restores the overlay visibility based on settings.
    public func restoreVisibility() {
        updateVisibility()
    }
}
