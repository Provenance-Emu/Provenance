// PVEmulatorViewController+KeyboardHUD.swift
// PVUI
//
// Hosting logic for the desktop-input keyboard HUD (Phase B of the macOS
// desktop input design). Mirrors the child-UIHostingController pattern in
// `PVEmulatorViewController+VirtualKeyboard.swift`: a small SwiftUI overlay
// added as a child view controller, sized to its own content and anchored to
// a screen corner rather than filling the view, so it never needs the
// visible-frame passthrough trick that file uses for its full-width sheet.
// `.allowsHitTesting(false)` in `KeyboardHUDView` (applied whenever the HUD
// is unpinned) already makes the hosting view non-interactive at the UIKit
// level, so untouched areas — and the whole HUD, when unpinned — fall
// through to the game below with no extra plumbing.
//
// Only relevant when `GamepadManager.isDesktopInputMode` is true (Mac
// "Designed for iPad" always, iPad opt-in via Settings > Controller).
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import UIKit
import SwiftUI
import PVLogging

// MARK: - Associated-object keys

private enum KeyboardHUDAssociatedKeys {
    static var hostingVC: UInt8 = 0
    static var viewModel: UInt8 = 0
}

// MARK: - PVEmulatorViewController + KeyboardHUD

@MainActor
extension PVEmulatorViewController {

    /// The UIHostingController wrapping `KeyboardHUDView`, if installed.
    private var keyboardHUDHostingVC: UIHostingController<KeyboardHUDView>? {
        get {
            objc_getAssociatedObject(self, &KeyboardHUDAssociatedKeys.hostingVC)
                as? UIHostingController<KeyboardHUDView>
        }
        set {
            objc_setAssociatedObject(
                self, &KeyboardHUDAssociatedKeys.hostingVC,
                newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// The view model backing the keyboard HUD. Exposed `private(set)` via
    /// the computed property below so the Game menu can reach `togglePinned()`.
    private var keyboardHUDViewModelStorage: KeyboardHUDViewModel? {
        get {
            objc_getAssociatedObject(self, &KeyboardHUDAssociatedKeys.viewModel)
                as? KeyboardHUDViewModel
        }
        set {
            objc_setAssociatedObject(
                self, &KeyboardHUDAssociatedKeys.viewModel,
                newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Installs the keyboard HUD and begins passively sampling keyboard
    /// state. No-ops outside desktop input mode, and idempotent if already
    /// installed. Call from `viewDidLoad`, alongside
    /// `setupVirtualInputOverlaysIfNeeded()`.
    public func setupKeyboardHUDIfNeeded() {
        guard GamepadManager.isDesktopInputMode else { return }
        guard keyboardHUDHostingVC == nil else { return }

        let viewModel = KeyboardHUDViewModel()
        keyboardHUDViewModelStorage = viewModel

        let hostingVC = UIHostingController(rootView: KeyboardHUDView(viewModel: viewModel))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false
        if #available(iOS 16.0, tvOS 16.0, *) {
            hostingVC.sizingOptions = [.intrinsicContentSize]
        }

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        // High zPosition so the HUD paints above skins/controller overlays
        // loaded asynchronously, without needing to re-sort the subview array.
        hostingVC.view.layer.zPosition = 9999
        hostingVC.didMove(toParent: self)

        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
        ])

        keyboardHUDHostingVC = hostingVC
        viewModel.startObserving()
        ILOG("[KeyboardHUD] Installed (desktop input mode)")
    }

    /// Tears down the keyboard HUD: stops sampling, ends any in-progress
    /// capture, and removes the hosted view. Call from `viewWillDisappear`,
    /// alongside `removeVirtualInputOverlays()`.
    public func teardownKeyboardHUD() {
        keyboardHUDViewModelStorage?.stopObserving()
        keyboardHUDViewModelStorage = nil

        guard let hostingVC = keyboardHUDHostingVC else { return }
        hostingVC.willMove(toParent: nil)
        hostingVC.view.removeFromSuperview()
        hostingVC.removeFromParent()
        keyboardHUDHostingVC = nil
    }

    /// Toggles pinned mode — the Game menu's "Toggle Keyboard HUD" item calls
    /// this. Pinning keeps the HUD open and reveals the rebind affordance;
    /// unpinning re-arms the auto-fade timer. No-ops if the HUD was never
    /// installed (e.g. not in desktop input mode).
    @objc public func toggleKeyboardHUDPinned() {
        guard let viewModel = keyboardHUDViewModelStorage else { return }
        viewModel.togglePinned()
    }
}
#endif // !os(tvOS)
