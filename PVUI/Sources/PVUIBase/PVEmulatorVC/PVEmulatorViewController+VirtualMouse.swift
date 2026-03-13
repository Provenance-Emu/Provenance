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

        let trackpad = TouchTrackpadView(frame: view.bounds)
        trackpad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        trackpad.mouseResponder = mouseCore
        // Limit touch capture to the game viewport so skin buttons and the
        // virtual keyboard remain interactive outside the display area.
        trackpad.gameViewRef = gpuViewController.view
        view.addSubview(trackpad)
        touchTrackpadView = trackpad

        let overlay = MouseCursorOverlayView()
        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.isUserInteractionEnabled = false
        // Frame is managed manually (via refreshVirtualMouseLayout) so the cursor
        // is confined to the game viewport, not the full emulator view.
        host.view.frame = view.bounds
        addChild(host)
        view.addSubview(host.view)
        view.bringSubviewToFront(host.view)
        host.didMove(toParent: self)
        cursorHostingController = host

        // Apply the game viewport rect immediately so the cursor starts confined.
        refreshVirtualMouseLayout()

        // Update the shared state so SwiftUI overlay buttons and UIKit buttons
        // both reflect the correct initial visibility.
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
        // Update the shared state so all observers stay in sync.
        virtualInputState.setMouseVisible(false)
    }

    /// Toggle virtual mouse visibility.
    public func toggleVirtualMouse() {
        if isVirtualMouseVisible {
            hideVirtualMouse()
        } else {
            showVirtualMouse()
        }
    }

    /// Remove cursor overlay and trackpad if present (called on teardown / core change).
    /// Must be called on the main actor (enforced by the `@MainActor` extension).
    func teardownVirtualMouse() {
        touchTrackpadView?.removeFromSuperview()
        touchTrackpadView = nil
        cursorHostingController?.view.removeFromSuperview()
        cursorHostingController?.removeFromParent()
        cursorHostingController = nil
    }

    /// Refresh the trackpad's authoritative game-viewport rect.
    ///
    /// Call this after any layout event that changes where the game screen
    /// appears on screen — e.g. from `viewDidAppear`, `viewDidLayoutSubviews`,
    /// and `applyFrameToGPUView` — so `TouchTrackpadView.hitTest` always uses
    /// the correct bounds and never accidentally captures skin-button touches.
    ///
    /// Also resizes the cursor overlay to match the game viewport so the cursor
    /// can never escape the rendered game screen area (e.g. when the game is
    /// letterboxed in a 16:9 container).
    func refreshVirtualMouseLayout() {
        guard let trackpad = touchTrackpadView else { return }
        if let targetFrame = currentTargetFrame, !targetFrame.isEmpty {
            // Skin system has determined the authoritative game rect — use it.
            trackpad.explicitGameViewRect = targetFrame
            // Confine cursor overlay to the same rect so normalised 0–1 coords
            // map to pixels within the game screen, not the full emulator view.
            cursorHostingController?.view.frame = targetFrame
        } else {
            // No target frame is known — clear any stale explicit rect so hitTest
            // falls back to the live gameViewRef frame derivation.
            trackpad.explicitGameViewRect = nil
            // Confine cursor to GPU view frame when no explicit rect is available,
            // falling back to full view bounds only if gpuViewController is absent.
            if let cursorView = cursorHostingController?.view {
                let gpuFrame = gpuViewController.view.frame
                cursorView.frame = gpuFrame.isEmpty ? view.bounds : gpuFrame
            }
        }
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
