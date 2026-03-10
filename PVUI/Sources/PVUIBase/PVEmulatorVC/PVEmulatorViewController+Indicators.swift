//
//  PVEmulatorViewController+Indicators.swift
//  PVUIBase
//
//  Integrates the indicator light overlay into PVEmulatorViewController.
//
//  Usage:
//    // In viewDidLoad or when starting emulation:
//    setupIndicatorOverlay()
//
//    // In viewWillAppear or when emulation resumes:
//    refreshIndicatorOverlay()
//
//    // Before presenting menus (to avoid interaction conflicts):
//    temporarilyHideIndicatorOverlay()
//
//    // After menus are dismissed:
//    restoreIndicatorOverlay()
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import PVSettings
import PVLogging

// MARK: - Stored Properties

private enum IndicatorAssociatedKeys {
    static var overlayVC = "indicatorOverlayVC"
}

// MARK: - Indicator Overlay Extension

public extension PVEmulatorViewController {

    // MARK: - Associated Object Accessors

    /// The overlay view controller that renders indicator lights.
    internal var indicatorOverlayViewController: PVIndicatorOverlayViewController? {
        get { objc_getAssociatedObject(self, &IndicatorAssociatedKeys.overlayVC) as? PVIndicatorOverlayViewController }
        set { objc_setAssociatedObject(self, &IndicatorAssociatedKeys.overlayVC, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Setup

    /// Sets up the indicator overlay if the user preference is enabled.
    /// Call this once during view setup (e.g., in viewDidLoad).
    func setupIndicatorOverlay() {
        guard Defaults[.showStatusIndicators] else {
            DLOG("Indicator overlay: disabled in settings")
            return
        }

        guard indicatorOverlayViewController == nil else {
            DLOG("Indicator overlay: already set up")
            return
        }

        let overlay = PVIndicatorOverlayViewController()
        indicatorOverlayViewController = overlay

        addChild(overlay)
        view.addSubview(overlay.view)
        overlay.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.view.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        overlay.didMove(toParent: self)

        // Refresh JIT state to ensure correct initial indicator
        overlay.refreshJITState()

        ILOG("Indicator overlay: set up successfully")
    }

    /// Removes the indicator overlay.
    /// Call this when cleaning up (e.g., when emulation stops).
    func removeIndicatorOverlay() {
        guard let overlay = indicatorOverlayViewController else { return }

        overlay.willMove(toParent: nil)
        overlay.view.removeFromSuperview()
        overlay.removeFromParent()
        indicatorOverlayViewController = nil

        ILOG("Indicator overlay: removed")
    }

    // MARK: - Lifecycle

    /// Refreshes the indicator overlay state.
    /// Call this when emulation resumes or settings change.
    func refreshIndicatorOverlay() {
        guard Defaults[.showStatusIndicators] else {
            // If disabled, remove if present
            if indicatorOverlayViewController != nil {
                removeIndicatorOverlay()
            }
            return
        }

        // If not set up, set it up now
        if indicatorOverlayViewController == nil {
            setupIndicatorOverlay()
        } else {
            // Otherwise, just refresh the state
            indicatorOverlayViewController?.refreshJITState()
            indicatorOverlayViewController?.updateOverlayVisibility()
        }
    }

    /// Temporarily hides the indicator overlay.
    /// Call this before presenting menus to avoid interaction conflicts.
    func temporarilyHideIndicatorOverlay() {
        indicatorOverlayViewController?.temporarilyHide()
    }

    /// Restores the indicator overlay visibility based on settings.
    /// Call this after menus are dismissed.
    func restoreIndicatorOverlay() {
        indicatorOverlayViewController?.restoreVisibility()
    }

    /// Updates the visibility of the indicator overlay based on current settings.
    func updateIndicatorOverlayVisibility() {
        indicatorOverlayViewController?.updateOverlayVisibility()
    }
}
