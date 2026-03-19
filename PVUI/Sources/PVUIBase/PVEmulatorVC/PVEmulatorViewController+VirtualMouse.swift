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

@MainActor
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

    // MARK: - Capability Checks

    /// Whether the virtual mouse overlay is currently visible.
    public var isVirtualMouseVisible: Bool {
        cursorHostingController != nil
    }

    // MARK: - Setup

    /// Attach the cursor overlay and trackpad layer when the active core supports mouse input.
    /// Safe to call multiple times — returns immediately if already installed.
    func setupVirtualMouseIfNeeded() {
        guard let mouseCore = core as? MouseResponder,
              mouseCore.gameSupportsMouse else { return }
        guard cursorHostingController == nil else { return }

        ILOG("[VirtualMouse] Core supports mouse — installing cursor overlay and trackpad")

        /// Frame is managed by `refreshVirtualMouseLayout()` — no autoresizingMask
        /// so the trackpad stays confined to the game viewport, not the full view.
        let trackpad = TouchTrackpadView(frame: view.bounds)
        trackpad.mouseResponder = mouseCore
        trackpad.gameViewRef = gpuViewController.view
        view.addSubview(trackpad)
        touchTrackpadView = trackpad

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

        /// Constrain trackpad and cursor overlay to the game viewport immediately.
        refreshVirtualMouseLayout()

        /// Fix z-order so controller buttons, menu, and skin controls remain
        /// interactive above the trackpad from the very first frame.
        bringVirtualInputOverlaysToFront()

        virtualInputState.setMouseVisible(true)

        ILOG("[VirtualMouse] Setup complete")
    }

    // MARK: - Show / Hide / Toggle

    /// Show the virtual mouse cursor and trackpad (main-actor isolated).
    /// No-op if the core does not support mouse or if already visible.
    public func showVirtualMouse() {
        guard coreSupportsVirtualMouse, !isVirtualMouseVisible else { return }
        setupVirtualMouseIfNeeded()
        // State is updated inside setupVirtualMouseIfNeeded() when the overlay installs.
    }

    /// Hide the virtual mouse cursor and trackpad.
    public func hideVirtualMouse() {
        guard isVirtualMouseVisible else { return }
        teardownVirtualMouse()
    }

    /// Toggle virtual mouse visibility.
    public func toggleVirtualMouse() {
        if isVirtualMouseVisible {
            hideVirtualMouse()
        } else {
            showVirtualMouse()
        }
    }

    /// Remove cursor overlay and trackpad if present, and update shared state.
    ///
    /// This is the single teardown path used by both `hideVirtualMouse()` and
    /// the deinit cleanup route (`takeVirtualMouseCleanupHandles`), ensuring
    /// `VirtualInputState.isMouseVisible` is always reset to `false` on removal.
    func teardownVirtualMouse() {
        touchTrackpadView?.removeFromSuperview()
        touchTrackpadView = nil
        cursorHostingController?.view.removeFromSuperview()
        cursorHostingController?.removeFromParent()
        cursorHostingController = nil
        // Keep shared state in sync regardless of which teardown path was taken.
        virtualInputState.setMouseVisible(false)
    }

    /// Refresh the trackpad and cursor overlay frames to match the game viewport.
    ///
    /// Call this after any layout event that changes where the game screen
    /// appears on screen — e.g. from `viewDidAppear`, `viewDidLayoutSubviews`,
    /// and `applyFrameToGPUView` — so the trackpad only captures touches
    /// within the game screen and never steals skin-button / menu touches.
    ///
    /// Both the trackpad and cursor overlay are resized to the viewport so
    /// normalised 0–1 coordinates map to pixels within the game screen.
    func refreshVirtualMouseLayout() {
        guard let trackpad = touchTrackpadView else { return }

        /// Resolve the authoritative viewport rect: prefer the skin-supplied
        /// target frame, fall back to the GPU view's live frame, then full view.
        let viewportFrame: CGRect
        if let targetFrame = currentTargetFrame, !targetFrame.isEmpty {
            viewportFrame = targetFrame
        } else {
            let gpuFrame = gpuViewController.view.frame
            viewportFrame = gpuFrame.isEmpty ? view.bounds : gpuFrame
        }

        trackpad.frame = viewportFrame
        trackpad.explicitGameViewRect = viewportFrame
        cursorHostingController?.view.frame = viewportFrame
    }
}

extension PVEmulatorViewController {
    /// Captures and clears virtual-mouse associated objects without requiring a
    /// main-actor hop, so `deinit` can schedule UI teardown safely.
    nonisolated func takeVirtualMouseCleanupHandles() -> (TouchTrackpadView?, UIHostingController<MouseCursorOverlayView>?) {
        let trackpadView = objc_getAssociatedObject(self, &VMKeys.trackpadViewKey) as? TouchTrackpadView
        let cursorHost = objc_getAssociatedObject(self, &VMKeys.cursorHostKey) as? UIHostingController<MouseCursorOverlayView>

        objc_setAssociatedObject(self, &VMKeys.trackpadViewKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &VMKeys.cursorHostKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return (trackpadView, cursorHost)
    }
}
#endif // canImport(UIKit) && !os(tvOS)
