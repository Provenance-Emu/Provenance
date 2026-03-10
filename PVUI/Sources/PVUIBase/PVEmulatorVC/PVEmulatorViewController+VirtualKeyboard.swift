// PVEmulatorViewController+VirtualKeyboard.swift
// PVUI
//
// Presentation logic for the SwiftUI virtual keyboard overlay.
// The keyboard is added as a child UIHostingController so it floats
// over the game without interrupting emulation or presenting a modal.
//
// Cores advertise keyboard support via the KeyboardResponder protocol
// property `gameSupportsKeyboard`. The keyboard button in the pause
// menu is shown only when that property is `true`.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import UIKit
import SwiftUI
import GameController
import PVCoreBridge
import PVLogging

// MARK: - Associated-object keys

private enum AssociatedKeys {
    static var keyboardHostingVC: UInt8 = 0
    static var keyboardViewModel: UInt8 = 0
}

// MARK: - PVEmulatorViewController + VirtualKeyboard

@MainActor
extension PVEmulatorViewController {

    // MARK: - Stored properties via Objective-C associated objects

    /// The UIHostingController wrapping the VirtualKeyboardView, if currently presented.
    private var virtualKeyboardHostingVC: UIHostingController<AnyView>? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.keyboardHostingVC)
                as? UIHostingController<AnyView>
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.keyboardHostingVC,
                newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// The view model backing the keyboard overlay.
    private var virtualKeyboardViewModel: VirtualKeyboardViewModel? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.keyboardViewModel)
                as? VirtualKeyboardViewModel
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.keyboardViewModel,
                newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Capability Checks

    /// Whether the emulator core reports keyboard support.
    public var coreSupportsVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.gameSupportsKeyboard == true
    }

    /// Whether the emulator core requires the keyboard to be shown automatically on launch.
    public var coreRequiresVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.requiresKeyboard == true
    }

    // MARK: - DeltaSkin Config Resolution

    /// The `KeyboardOverlayConfig` that should be used for the current session.
    ///
    /// Resolution order:
    ///   1. Config declared in the active skin's JSON (`keyboardOverlay` key).
    ///   2. Hard-coded default for the game type (from `DeltaSkinDefaults`).
    ///   3. `nil` — no keyboard overlay for this system.
    var effectiveKeyboardOverlayConfig: KeyboardOverlayConfig? {
        // 1. Active skin declaration takes priority
        if let skinConfig = currentSkin?.keyboardOverlay {
            return skinConfig
        }

        // 2. Fall back to the hard-coded default for this game type
        if let gameType = currentSkin?.gameType {
            return DeltaSkinDefaults.defaultKeyboardOverlay(for: gameType)
        }

        return nil
    }

    /// Call this after the emulator has started (e.g. at the end of `viewDidAppear` /
    /// after `applySkin` completes) to honour `autoShow` from the DeltaSkin config.
    func applyKeyboardOverlayConfigIfNeeded() {
        guard let config = effectiveKeyboardOverlayConfig else { return }
        DLOG("VirtualKeyboard: effectiveConfig variant=\(config.variant.rawValue) autoShow=\(config.autoShow)")
        if config.autoShow {
            showVirtualKeyboard(animated: false)
        }
    }

    // MARK: - Lifecycle

    /// Whether the virtual keyboard overlay is currently visible.
    public var isVirtualKeyboardVisible: Bool {
        virtualKeyboardHostingVC != nil
    }

    /// Call this after the core has started and the view hierarchy is ready.
    /// Auto-shows the keyboard if the core requires it.
    /// Mouse cursor overlay is handled separately by `setupVirtualMouseIfNeeded()`.
    public func setupVirtualInputOverlaysIfNeeded() {
        if coreRequiresVirtualKeyboard {
            showVirtualKeyboard()
        }
        // Also honour DeltaSkin autoShow
        applyKeyboardOverlayConfigIfNeeded()
    }

    /// Tears down the keyboard overlay. Call from `viewWillDisappear` or `deinit`.
    public func removeVirtualInputOverlays() {
        hideVirtualKeyboard()
    }

    /// Show the virtual keyboard overlay.
    /// Does nothing if the core does not support keyboard input or if already visible.
    public func showVirtualKeyboard(animated: Bool = true) {
        guard coreSupportsVirtualKeyboard, !isVirtualKeyboardVisible else { return }

        let viewModel = VirtualKeyboardViewModel()
        viewModel.delegate = self
        viewModel.dismissAction = { [weak self] in
            self?.hideVirtualKeyboard(animated: true)
        }
        virtualKeyboardViewModel = viewModel

        let keyboardView = VirtualKeyboardView(viewModel: viewModel)
        let hostingVC = UIHostingController(rootView: AnyView(keyboardView))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        view.bringSubviewToFront(hostingVC.view)
        hostingVC.didMove(toParent: self)

        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if animated {
            hostingVC.view.alpha = 0
            UIView.animate(withDuration: 0.25) { hostingVC.view.alpha = 1 }
        }

        virtualKeyboardHostingVC = hostingVC
        ILOG("[VirtualKeyboard] Keyboard overlay shown (animated: \(animated))")
    }

    /// Hide the virtual keyboard overlay, releasing all held keys first.
    public func hideVirtualKeyboard(animated: Bool = true) {
        guard let hostingVC = virtualKeyboardHostingVC else { return }

        // Release all held/modifier keys so the emulator doesn't see stuck keys
        virtualKeyboardViewModel?.releaseAllKeys()

        let cleanup = {
            hostingVC.willMove(toParent: nil)
            hostingVC.view.removeFromSuperview()
            hostingVC.removeFromParent()
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                hostingVC.view.alpha = 0
            }, completion: { _ in cleanup() })
        } else {
            cleanup()
        }

        virtualKeyboardHostingVC = nil
        virtualKeyboardViewModel = nil
        ILOG("[VirtualKeyboard] Keyboard overlay hidden (animated: \(animated))")
    }

    /// Toggle keyboard visibility.
    public func toggleVirtualKeyboard(animated: Bool = true) {
        if isVirtualKeyboardVisible {
            hideVirtualKeyboard(animated: animated)
        } else {
            showVirtualKeyboard(animated: animated)
        }
    }

    /// Bring all virtual input overlays (keyboard + mouse cursor) to the front of the view
    /// hierarchy.  Call this after applying a new skin so the overlays stay on top.
    public func bringVirtualInputOverlaysToFront() {
        if let keyboardView = virtualKeyboardHostingVC?.view {
            view.bringSubviewToFront(keyboardView)
        }
        if let cursorView = cursorHostingController?.view {
            view.bringSubviewToFront(cursorView)
        }
    }
}

// MARK: - VirtualKeyboardDelegate

extension PVEmulatorViewController: VirtualKeyboardDelegate {

    @available(iOS 14.0, *)
    public func virtualKeyboard(
        _ keyboard: VirtualKeyboardViewModel,
        keyDown keyCode: GCKeyCode
    ) {
        guard let keyboardResponder = core as? KeyboardResponder else { return }
        keyboardResponder.keyDown(keyCode)
    }

    @available(iOS 14.0, *)
    public func virtualKeyboard(
        _ keyboard: VirtualKeyboardViewModel,
        keyUp keyCode: GCKeyCode
    ) {
        guard let keyboardResponder = core as? KeyboardResponder else { return }
        keyboardResponder.keyUp(keyCode)
    }
}

// MARK: - Notification names

public extension Notification.Name {
    /// Posted when the virtual keyboard overlay should be shown.
    static let pvShowVirtualKeyboard = Notification.Name("com.provenance.virtualKeyboard.show")

    /// Posted when the virtual keyboard overlay should be hidden.
    static let pvHideVirtualKeyboard = Notification.Name("com.provenance.virtualKeyboard.hide")

    /// Posted when the virtual keyboard overlay should be toggled.
    static let pvToggleVirtualKeyboard = Notification.Name("com.provenance.virtualKeyboard.toggle")
}

/// Namespace for virtual keyboard notification user-info keys.
public enum PVVirtualKeyboardNotification {
    /// `userInfo` key whose value is a `KeyboardOverlayConfig`.
    public static let configKey = "keyboardOverlayConfig"
}
#endif // !os(tvOS)
