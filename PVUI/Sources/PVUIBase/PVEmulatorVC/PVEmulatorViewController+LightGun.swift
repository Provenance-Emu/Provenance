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
/// On tvOS, Siri Remote interaction is mapped separately via `pressesBegan`:
///   - Play/Pause press           → trigger
///   - Menu press                 → start button
///   - Touch-surface swipe        → reload (send off-screen shot)
///

#if canImport(UIKit) && !os(tvOS)
import UIKit
import PVCoreBridge
import PVLogging

// MARK: - Associated-object keys

private enum LGKeys {
    static var touchViewKey: UInt8 = 0
}

// MARK: - Extension

@MainActor
extension PVEmulatorViewController {

    // MARK: - Stored property via associated object

    /// The touch-interception view for light gun input, if currently installed.
    var lightGunTouchView: LightGunTouchView? {
        get { objc_getAssociatedObject(self, &LGKeys.touchViewKey) as? LightGunTouchView }
        set { objc_setAssociatedObject(self, &LGKeys.touchViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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

        refreshLightGunLayout()
        bringVirtualInputOverlaysToFront()

        ILOG("[LightGun] Touch gesture layer installed")
    }

    // MARK: - Teardown

    /// Remove the light gun touch layer if present.
    func teardownLightGun() {
        lightGunTouchView?.removeFromSuperview()
        lightGunTouchView = nil
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
    }
}

// MARK: - Cleanup handle (nonisolated for deinit)

extension PVEmulatorViewController {
    /// Captures and clears the light gun touch view without requiring a main-actor
    /// hop, so `deinit` can schedule UI teardown safely.
    nonisolated func takeLightGunCleanupHandle() -> LightGunTouchView? {
        let view = objc_getAssociatedObject(self, &LGKeys.touchViewKey) as? LightGunTouchView
        objc_setAssociatedObject(self, &LGKeys.touchViewKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return view
    }
}
#endif // canImport(UIKit) && !os(tvOS)
