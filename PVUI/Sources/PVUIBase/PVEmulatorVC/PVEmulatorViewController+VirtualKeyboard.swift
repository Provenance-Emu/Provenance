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

    // MARK: - Public interface

    /// Whether the emulator core reports keyboard support.
    public var coreSupportsVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.gameSupportsKeyboard == true
    }

    /// Whether the emulator core requires the keyboard to be shown automatically on launch.
    public var coreRequiresVirtualKeyboard: Bool {
        (core as? KeyboardResponder)?.requiresKeyboard == true
    }

    /// Whether the virtual keyboard overlay is currently visible.
    public var isVirtualKeyboardVisible: Bool {
        virtualKeyboardHostingVC != nil
    }

    /// Call this after the core has started and the view hierarchy is ready.
    /// Auto-shows the keyboard if the core requires it.
    public func setupVirtualInputOverlaysIfNeeded() {
        if coreRequiresVirtualKeyboard {
            showVirtualKeyboard()
        }
    }

    /// Tears down the keyboard overlay. Call from `viewWillDisappear` or `deinit`.
    public func removeVirtualInputOverlays() {
        hideVirtualKeyboard()
    }

    /// Show the virtual keyboard overlay.
    /// Does nothing if the core does not support keyboard input or if already visible.
    public func showVirtualKeyboard() {
        guard !isVirtualKeyboardVisible else { return }

        let viewModel = VirtualKeyboardViewModel()
        viewModel.delegate = self
        viewModel.dismissAction = { [weak self] in
            self?.hideVirtualKeyboard()
        }
        virtualKeyboardViewModel = viewModel

        let keyboardView = VirtualKeyboardView(viewModel: viewModel)
        let hostingVC = UIHostingController(rootView: AnyView(keyboardView))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        virtualKeyboardHostingVC = hostingVC
        ILOG("[VirtualKeyboard] Keyboard overlay shown")
    }

    /// Hide the virtual keyboard overlay, releasing all held keys first.
    public func hideVirtualKeyboard() {
        guard let hostingVC = virtualKeyboardHostingVC else { return }

        // Release all held/modifier keys so the emulator doesn't see stuck keys
        virtualKeyboardViewModel?.releaseAllKeys()

        hostingVC.willMove(toParent: nil)
        hostingVC.view.removeFromSuperview()
        hostingVC.removeFromParent()

        virtualKeyboardHostingVC = nil
        virtualKeyboardViewModel = nil
        ILOG("[VirtualKeyboard] Keyboard overlay hidden")
    }

    /// Toggle keyboard visibility.
    public func toggleVirtualKeyboard() {
        if isVirtualKeyboardVisible {
            hideVirtualKeyboard()
        } else {
            showVirtualKeyboard()
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
#endif // !os(tvOS)
