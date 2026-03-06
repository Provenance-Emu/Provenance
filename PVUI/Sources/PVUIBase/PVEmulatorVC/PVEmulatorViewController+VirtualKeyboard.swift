//
//  PVEmulatorViewController+VirtualKeyboard.swift
//  PVUI
//
//  Created by Claude on behalf of Provenance Emu.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

#if canImport(UIKit) && !os(tvOS)
import UIKit
import PVCoreBridge
import PVLogging
import GameController

// MARK: - Stored Properties via Association

private enum VirtualKeyboardAssoc {
    static var keyboardView: UInt8 = 0
    static var mouseOverlayView: UInt8 = 0
    static var isKeyboardVisible: UInt8 = 0
}

// MARK: - PVEmulatorViewController + VirtualKeyboard

@available(iOS 14.0, *)
extension PVEmulatorViewController: VirtualKeyboardViewDelegate {

    // MARK: - Stored Property Accessors

    /// The on-screen keyboard overlay, lazily created on first access.
    var virtualKeyboardView: VirtualKeyboardView? {
        get { objc_getAssociatedObject(self, &VirtualKeyboardAssoc.keyboardView) as? VirtualKeyboardView }
        set { objc_setAssociatedObject(self, &VirtualKeyboardAssoc.keyboardView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The mouse cursor overlay, lazily created on first access.
    var mouseCursorOverlayView: MouseCursorOverlayView? {
        get { objc_getAssociatedObject(self, &VirtualKeyboardAssoc.mouseOverlayView) as? MouseCursorOverlayView }
        set { objc_setAssociatedObject(self, &VirtualKeyboardAssoc.mouseOverlayView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Whether the virtual keyboard is currently visible.
    public var isVirtualKeyboardVisible: Bool {
        get { (objc_getAssociatedObject(self, &VirtualKeyboardAssoc.isKeyboardVisible) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &VirtualKeyboardAssoc.isKeyboardVisible, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Capability Checks

    /// Whether the running core supports a virtual keyboard.
    var coreSupportsVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.gameSupportsKeyboard ?? false
    }

    /// Whether the running core requires the virtual keyboard to be shown automatically.
    var coreRequiresVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.requiresKeyboard ?? false
    }

    /// Whether the running core supports virtual mouse input.
    var coreSupportsMouse: Bool {
        (core as? MouseResponder)?.gameSupportsMouse ?? false
    }

    // MARK: - Lifecycle

    /// Call this after the core has started and the view hierarchy is ready.
    /// It will auto-show the keyboard overlay if the core requires it and
    /// add the mouse overlay if the core supports mouse input.
    public func setupVirtualInputOverlaysIfNeeded() {
        if coreSupportsMouse {
            showMouseCursorOverlay()
        }
        if coreRequiresVirtualKeyboard {
            showVirtualKeyboard(animated: false)
        }
    }

    /// Tears down both overlays.  Call from `viewWillDisappear` or `deinit`.
    public func removeVirtualInputOverlays() {
        virtualKeyboardView?.removeFromSuperview()
        virtualKeyboardView = nil
        mouseCursorOverlayView?.removeFromSuperview()
        mouseCursorOverlayView = nil
        isVirtualKeyboardVisible = false
    }

    // MARK: - Virtual Keyboard

    /// Shows the on-screen keyboard overlay without pausing emulation.
    public func showVirtualKeyboard(animated: Bool = true) {
        guard coreSupportsVirtualKeyboard else {
            DLOG("[VirtualKeyboard] Core does not support virtual keyboard, skipping.")
            return
        }

        if virtualKeyboardView == nil {
            let kbView = VirtualKeyboardView()
            kbView.delegate = self
            kbView.translatesAutoresizingMaskIntoConstraints = false
            kbView.alpha = 0
            view.addSubview(kbView)

            let keyboardHeight: CGFloat = 200
            NSLayoutConstraint.activate([
                kbView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                kbView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                kbView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                kbView.heightAnchor.constraint(equalToConstant: keyboardHeight)
            ])
            virtualKeyboardView = kbView
        }

        isVirtualKeyboardVisible = true

        let show = {
            self.virtualKeyboardView?.alpha = 1
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: show)
        } else {
            show()
        }

        ILOG("[VirtualKeyboard] Virtual keyboard shown.")
    }

    /// Hides the on-screen keyboard overlay without pausing emulation.
    public func hideVirtualKeyboard(animated: Bool = true) {
        guard let kbView = virtualKeyboardView else { return }

        isVirtualKeyboardVisible = false

        if animated {
            UIView.animate(withDuration: 0.2) { kbView.alpha = 0 }
        } else {
            kbView.alpha = 0
        }

        ILOG("[VirtualKeyboard] Virtual keyboard hidden.")
    }

    /// Toggles the on-screen keyboard overlay.
    public func toggleVirtualKeyboard() {
        if isVirtualKeyboardVisible {
            hideVirtualKeyboard()
        } else {
            showVirtualKeyboard()
        }
    }

    // MARK: - Mouse Cursor Overlay

    func showMouseCursorOverlay() {
        guard coreSupportsMouse else { return }

        if mouseCursorOverlayView == nil {
            let overlay = MouseCursorOverlayView()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            // Forward events to the core
            overlay.mouseCore = core as? MouseResponder
            view.addSubview(overlay)

            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                // Leave space for the keyboard when it is visible
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            mouseCursorOverlayView = overlay
        }

        ILOG("[VirtualKeyboard] Mouse cursor overlay shown.")
    }

    // MARK: - VirtualKeyboardViewDelegate

    public func virtualKeyboard(_ keyboard: VirtualKeyboardView, keyDown keyCode: GCKeyCode) {
        (core as? KeyboardResponder)?.keyDown(keyCode)
    }

    public func virtualKeyboard(_ keyboard: VirtualKeyboardView, keyUp keyCode: GCKeyCode) {
        (core as? KeyboardResponder)?.keyUp(keyCode)
    }
}
#endif
