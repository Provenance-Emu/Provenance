///
/// PVEmulatorViewController+LightGun.swift
/// PVUI
///
/// Adds a touch-gesture layer for light gun input when the active core reports
/// `gameSupportsLightGun == true`.  The `LightGunTouchView` intercepts touches
/// and translates them into `LightGunResponder` callbacks:
///
///   - Single-finger tap          → trigger
///   - Single-finger drag         → aim update
///   - Two-finger tap             → offscreen reload
///   - Long press (≥ 0.5 s)       → auxA button
///   - Double tap                 → start button
///

#if canImport(UIKit) && !os(tvOS)
import UIKit
import SwiftUI
import PVCoreBridge
import PVLogging

// MARK: - Associated-object keys

private enum LGKeys {
    static var touchViewKey: UInt8 = 0
    static var gcMouseDriverKey: UInt8 = 1
    /// Tracks whether the light gun setup installed the cursor overlay (so teardown
    /// knows whether to remove it, or to leave it for the virtual-mouse system).
    static var ownsCursorOverlayKey: UInt8 = 2
}

// MARK: - Extension

@MainActor
extension PVEmulatorViewController {

    // MARK: - Stored properties via associated objects

    /// The touch-interception view for light gun input, if currently installed.
    var lightGunTouchView: LightGunTouchView? {
        get { objc_getAssociatedObject(self, &LGKeys.touchViewKey) as? LightGunTouchView }
        set { objc_setAssociatedObject(self, &LGKeys.touchViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Driver that routes physical GCMouse hardware to the LightGunResponder core.
    var gcMouseLightGunDriver: GCMouseLightGunDriver? {
        get { objc_getAssociatedObject(self, &LGKeys.gcMouseDriverKey) as? GCMouseLightGunDriver }
        set { objc_setAssociatedObject(self, &LGKeys.gcMouseDriverKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// `true` when the light gun setup installed the cursor overlay itself (not the virtual-mouse system).
    private var lightGunOwnsCursorOverlay: Bool {
        get { objc_getAssociatedObject(self, &LGKeys.ownsCursorOverlayKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &LGKeys.ownsCursorOverlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Capability check

    /// Whether the active core supports light gun peripherals.
    public var coreSupportsLightGun: Bool {
        (core as? LightGunResponder)?.gameSupportsLightGun == true
    }

    // MARK: - Setup

    /// Install the `LightGunTouchView` when the active core supports light gun input.
    /// Safe to call multiple times — returns immediately if already installed.
    func setupLightGunIfNeeded() {
        guard let gunCore = core as? LightGunResponder,
              gunCore.gameSupportsLightGun else { return }
        guard lightGunTouchView == nil else { return }

        ILOG("[LightGun] Core supports light gun — installing touch gesture layer")

        let touchView = LightGunTouchView(frame: view.bounds)
        touchView.lightGunResponder = gunCore
        touchView.gameViewRef = gpuViewController.view
        view.addSubview(touchView)
        lightGunTouchView = touchView

        // Mutual exclusion: if a virtual-touch-mouse trackpad is also active (rare case
        // where a core implements both MouseResponder and LightGunResponder), disable its
        // touch interception so the same finger doesn't drive both systems.
        // Physical GCMouse hardware continues to work via GCMouseMouseResponderDriver.
        if let trackpad = touchTrackpadView {
            trackpad.isUserInteractionEnabled = false
            ILOG("[LightGun] TouchTrackpadView suspended — light gun has touch priority")
        }

        // Install a cursor overlay to show the current aim point.
        // Reuse the existing overlay if the virtual-mouse system already installed one;
        // otherwise create our own so the crosshair/cursor renders over the game surface.
        if cursorHostingController == nil {
            let overlay = MouseCursorOverlayView()
            let host = UIHostingController(rootView: overlay)
            host.view.backgroundColor = .clear
            host.view.isOpaque = false
            host.view.isUserInteractionEnabled = false
            host.view.frame = view.bounds
            addChild(host)
            view.addSubview(host.view)
            host.didMove(toParent: self)
            cursorHostingController = host
            lightGunOwnsCursorOverlay = true
            ILOG("[LightGun] Cursor overlay installed for aim visualization")
        }

        // Attach GCMouse hardware driver so physical mice (Bluetooth, USB, PS5 touchpad)
        // route directly to the core's LightGunResponder.
        let driver = GCMouseLightGunDriver()
        driver.attach(to: gunCore)
        gcMouseLightGunDriver = driver

        refreshLightGunLayout()
        bringVirtualInputOverlaysToFront()

        ILOG("[LightGun] Touch gesture layer installed")
    }

    // MARK: - Teardown

    /// Remove the light gun touch layer if present.
    func teardownLightGun() {
        lightGunTouchView?.removeFromSuperview()
        lightGunTouchView = nil

        // Detach physical-mouse driver — releases button state and removes handlers.
        gcMouseLightGunDriver?.detach()
        gcMouseLightGunDriver = nil

        // Restore touch trackpad if it was suppressed to give light gun touch priority.
        if let trackpad = touchTrackpadView {
            trackpad.isUserInteractionEnabled = coreSupportsVirtualMouse
        }

        // Remove cursor overlay only if we installed it (not the virtual-mouse system).
        if lightGunOwnsCursorOverlay {
            cursorHostingController?.view.removeFromSuperview()
            cursorHostingController?.removeFromParent()
            cursorHostingController = nil
            lightGunOwnsCursorOverlay = false
        }
    }

    // MARK: - Layout refresh

    /// Update the `LightGunTouchView` frame to match the current game viewport.
    ///
    /// Call this after any layout event that repositions the game screen —
    /// e.g. from `viewDidAppear`, `viewDidLayoutSubviews`, `applyFrameToGPUView`.
    func refreshLightGunLayout() {
        guard let touchView = lightGunTouchView else { return }

        let viewportFrame: CGRect
        if let targetFrame = currentTargetFrame, !targetFrame.isEmpty {
            viewportFrame = targetFrame
        } else {
            let gpuFrame = gpuViewController.view.frame
            viewportFrame = gpuFrame.isEmpty ? view.bounds : gpuFrame
        }

        touchView.frame = viewportFrame
        touchView.explicitGameViewRect = viewportFrame

        // Keep the cursor overlay frame in sync when we own it.
        if lightGunOwnsCursorOverlay {
            cursorHostingController?.view.frame = viewportFrame
        }
    }
}

// MARK: - Cleanup handle (nonisolated for deinit)

extension PVEmulatorViewController {
    /// Captures and clears the light gun touch view without requiring a main-actor
    /// hop, so `deinit` can schedule UI teardown safely.
    nonisolated func takeLightGunCleanupHandle() -> LightGunTouchView? {
        let touchView = objc_getAssociatedObject(self, &LGKeys.touchViewKey) as? LightGunTouchView
        objc_setAssociatedObject(self, &LGKeys.touchViewKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Detach and release the GCMouseLightGunDriver on deinit.
        if let driver = objc_getAssociatedObject(self, &LGKeys.gcMouseDriverKey) as? GCMouseLightGunDriver {
            Task { @MainActor in
                driver.detach()
            }
        }
        objc_setAssociatedObject(self, &LGKeys.gcMouseDriverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &LGKeys.ownsCursorOverlayKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return touchView
    }
}
#endif // canImport(UIKit) && !os(tvOS)
