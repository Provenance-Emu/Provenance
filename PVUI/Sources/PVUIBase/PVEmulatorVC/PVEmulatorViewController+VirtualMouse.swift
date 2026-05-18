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
    static var cursorHostKey: UInt8 = 0
    static var trackpadViewKey: UInt8 = 0
    static var gcMouseDriverKey: UInt8 = 0
    static var lastValidViewportFrameKey: UInt8 = 0
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

    /// Driver that routes physical GCMouse hardware to the MouseResponder core.
    var gcMouseDriver: GCMouseMouseResponderDriver? {
        get { objc_getAssociatedObject(self, &VMKeys.gcMouseDriverKey) as? GCMouseMouseResponderDriver }
        set { objc_setAssociatedObject(self, &VMKeys.gcMouseDriverKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Last validated viewport frame used by virtual mouse gating.
    ///
    /// Cached to survive transient rotation states where viewport providers briefly
    /// clear their frame and GPU layout can momentarily report full-screen bounds.
    private var lastValidMouseViewportFrame: CGRect? {
        get {
            (objc_getAssociatedObject(self, &VMKeys.lastValidViewportFrameKey) as? NSValue)?.cgRectValue
        }
        set {
            let boxed = newValue.map { NSValue(cgRect: $0) }
            objc_setAssociatedObject(self, &VMKeys.lastValidViewportFrameKey, boxed, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
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
        installVirtualMouseInfrastructure(mouseCore: mouseCore, manualOverride: false)
    }

    /// User-initiated install via the pause-menu Virtual Mouse tile. Bypasses
    /// the `gameSupportsMouse` registry check so users can opt in on titles
    /// the static MD5/title list doesn't cover, as long as the *system* has
    /// any mouse support (SNES Mouse, Dreamcast Maple, PSX Mouse, etc.).
    func setupVirtualMouseManually() {
        guard let mouseCore = core as? MouseResponder else { return }
        installVirtualMouseInfrastructure(mouseCore: mouseCore, manualOverride: true)
    }

    /// Shared installer used by both the auto-detect path and the manual
    /// pause-menu tile. Idempotent — returns immediately if already installed.
    private func installVirtualMouseInfrastructure(mouseCore: MouseResponder, manualOverride: Bool) {
        guard cursorHostingController == nil else { return }

        ILOG("[VirtualMouse] Installing cursor overlay and trackpad (manualOverride=\(manualOverride))")

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

        /// During toggle-on, viewport sources can lag one run-loop behind.
        /// Retry shortly so mouse interaction recovers without requiring rotation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self, self.isVirtualMouseVisible else { return }
            self.refreshVirtualMouseLayout()
            self.bringVirtualInputOverlaysToFront()
        }

        /// Fix z-order so controller buttons, menu, and skin controls remain
        /// interactive above the trackpad from the very first frame.
        bringVirtualInputOverlaysToFront()

        virtualInputState.setMouseVisible(true)

        // Attach GCMouse hardware driver so physical mice (Bluetooth, USB)
        // route directly to the core without going through the touch trackpad.
        let driver = GCMouseMouseResponderDriver()
        driver.attach(to: mouseCore)
        gcMouseDriver = driver

        // On iPadOS 14+ request pointer lock so the system cursor is
        // suppressed and raw deltas are delivered while emulation is active.
        if #available(iOS 14.0, *) {
            setNeedsUpdateOfPrefersPointerLocked()
        }

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

    /// Manual show invoked from the pause-menu Virtual Mouse tile. Skips the
    /// per-game `gameSupportsMouse` gate so users can opt in on titles outside
    /// the static registry, but still requires the active core to conform to
    /// `MouseResponder`.
    public func showVirtualMouseManually() {
        guard (core as? MouseResponder) != nil, !isVirtualMouseVisible else { return }
        setupVirtualMouseManually()
    }

    /// Pause-menu toggle. Mirrors `toggleVirtualMouse()` but uses the manual
    /// install path so it works even when the auto-detect would refuse.
    public func toggleVirtualMouseManually() {
        if isVirtualMouseVisible {
            hideVirtualMouse()
        } else {
            showVirtualMouseManually()
        }
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

        // Detach GCMouse driver — releases button state and removes handlers.
        gcMouseDriver?.detach()
        gcMouseDriver = nil

        // Release pointer lock so the system cursor reappears.
        if #available(iOS 14.0, *) {
            setNeedsUpdateOfPrefersPointerLocked()
        }

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

        /// Resolve a trustworthy viewport for touch capture.
        if let viewportFrame = resolvedVirtualMouseViewportFrame() {
            trackpad.isUserInteractionEnabled = true
            trackpad.frame = viewportFrame
            trackpad.explicitGameViewRect = viewportFrame
            cursorHostingController?.view.frame = viewportFrame
            lastValidMouseViewportFrame = viewportFrame
            return
        }

        /// No trustworthy viewport yet (common during rotation): disable capture
        /// so menu/controller/skin buttons remain interactive until frame recovery.
        trackpad.isUserInteractionEnabled = false
        trackpad.explicitGameViewRect = nil
    }

    /// Resolves the best viewport candidate for virtual mouse capture.
    ///
    /// Priority order:
    /// 1) Skin/viewport delegate frame (`currentTargetFrame`)
    /// 2) Live GPU frame
    /// 3) Last known valid viewport cache
    /// 4) Full view fallback only for non-DeltaSkin layouts
    private func resolvedVirtualMouseViewportFrame() -> CGRect? {
        if let targetFrame = currentTargetFrame, isTrustedVirtualMouseViewportFrame(targetFrame) {
            return targetFrame
        }

        let gpuFrame = gpuViewController.view.frame
        if isTrustedVirtualMouseViewportFrame(gpuFrame) {
            return gpuFrame
        }

        if let cachedFrame = lastValidMouseViewportFrame, isTrustedVirtualMouseViewportFrame(cachedFrame) {
            return cachedFrame
        }

        if !isDeltaSkinEnabled, isTrustedVirtualMouseViewportFrame(view.bounds) {
            return view.bounds
        }

        return nil
    }

    /// Validates viewport frames used by the touch trackpad.
    ///
    /// In DeltaSkin mode, a near full-screen frame is rejected to prevent stale
    /// rotation fallback from turning the trackpad into a global touch interceptor.
    private func isTrustedVirtualMouseViewportFrame(_ frame: CGRect) -> Bool {
        guard !frame.isEmpty,
              frame.width > 0,
              frame.height > 0,
              frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite else {
            return false
        }

        let fullBounds = view.bounds
        guard !fullBounds.isEmpty else { return true }

        let maxWidth = fullBounds.width + 2
        let maxHeight = fullBounds.height + 2
        guard frame.width <= maxWidth, frame.height <= maxHeight else { return false }

        if isDeltaSkinEnabled {
            let epsilon: CGFloat = 1.0
            let isNearFullscreen =
                abs(frame.minX - fullBounds.minX) <= epsilon &&
                abs(frame.minY - fullBounds.minY) <= epsilon &&
                abs(frame.width - fullBounds.width) <= epsilon &&
                abs(frame.height - fullBounds.height) <= epsilon
            if isNearFullscreen {
                return false
            }
        }

        return true
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

        // Detach and release the GCMouse driver on deinit. GCMouseMouseResponderDriver
        // is @MainActor-isolated so detach() must run on the main actor.
        if let driver = objc_getAssociatedObject(self, &VMKeys.gcMouseDriverKey) as? GCMouseMouseResponderDriver {
            Task { @MainActor in
                driver.detach()
            }
        }
        objc_setAssociatedObject(self, &VMKeys.gcMouseDriverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return (trackpadView, cursorHost)
    }
}
#endif // canImport(UIKit) && !os(tvOS)
