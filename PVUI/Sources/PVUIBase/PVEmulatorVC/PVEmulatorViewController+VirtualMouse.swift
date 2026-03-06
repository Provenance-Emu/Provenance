///
/// PVEmulatorViewController+VirtualMouse.swift
/// PVUI
///
/// Adds a visible mouse-cursor overlay and a touch-trackpad layer for cores
/// that report `gameSupportsMouse == true` (e.g. DOSBox via libretro).
///
/// The cursor overlay is a SwiftUI `MouseCursorOverlayView` hosted in a
/// transparent `UIHostingController` that sits on top of everything else
/// in the emulator view hierarchy.  The trackpad view intercepts touches
/// and forwards normalised (0–1) coordinates to the core.
///

#if canImport(UIKit) && !os(tvOS)
import UIKit
import SwiftUI
import PVCoreBridge
import PVLogging

// MARK: - Associated-object keys for extension-level "stored" properties

private enum VMKeys {
    static var cursorHostKey = "PVEmuVC_cursorHost"
    static var trackpadViewKey = "PVEmuVC_trackpadView"
}

// MARK: - Extension

extension PVEmulatorViewController {

    // MARK: Computed "stored" properties via associated objects

    /// The hosting controller that renders the SwiftUI cursor overlay.
    var cursorHostingController: UIHostingController<MouseCursorOverlayView>? {
        get { objc_getAssociatedObject(self, &VMKeys.cursorHostKey) as? UIHostingController<MouseCursorOverlayView> }
        set { objc_setAssociatedObject(self, &VMKeys.cursorHostKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The transparent view that translates touches into mouse events.
    var touchTrackpadView: TouchTrackpadView? {
        get { objc_getAssociatedObject(self, &VMKeys.trackpadViewKey) as? TouchTrackpadView }
        set { objc_setAssociatedObject(self, &VMKeys.trackpadViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Setup

    /// Attach the cursor overlay and trackpad layer when the active core supports mouse input.
    /// Safe to call multiple times — returns immediately if already installed.
    func setupVirtualMouseIfNeeded() {
        guard let mouseCore = core as? MouseResponder,
              mouseCore.gameSupportsMouse else { return }
        guard cursorHostingController == nil else { return }

        ILOG("[VirtualMouse] Core supports mouse — installing cursor overlay and trackpad")

        // 1. Trackpad view (transparent, intercepts touches)
        let trackpad = TouchTrackpadView(frame: view.bounds)
        trackpad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        trackpad.mouseResponder = mouseCore
        view.addSubview(trackpad)
        touchTrackpadView = trackpad

        // 2. Cursor overlay (pass-through, no hit-testing)
        let overlay = MouseCursorOverlayView()
        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        cursorHostingController = host

        ILOG("[VirtualMouse] Setup complete")
    }

    /// Remove cursor overlay and trackpad if present (called on teardown / core change).
    /// Safe to call from any thread — UIKit operations are dispatched to the main thread.
    func teardownVirtualMouse() {
        // Capture views before clearing the stored references so the async block
        // can remove them even if self has been released by then.
        let trackpad = touchTrackpadView
        let host = cursorHostingController
        touchTrackpadView = nil
        cursorHostingController = nil

        let doTeardown = {
            trackpad?.removeFromSuperview()
            host?.view.removeFromSuperview()
            host?.removeFromParent()
        }

        if Thread.isMainThread {
            doTeardown()
        } else {
            DispatchQueue.main.async(execute: doTeardown)
        }
    }
}
#endif // canImport(UIKit) && !os(tvOS)
