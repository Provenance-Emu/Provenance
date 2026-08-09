// PVEmulatorViewController+KeyboardHUD.swift
// PVUI
//
// Hosting logic for the in-game input legend (Phase B of the macOS desktop
// input design). Mirrors the child-UIHostingController pattern in
// `PVEmulatorViewController+VirtualKeyboard.swift`: a small SwiftUI overlay
// added as a child view controller, sized to its own content and anchored to
// the bottom safe-area edge rather than filling the view, so it never needs
// the visible-frame passthrough trick that file uses for its full-width sheet.
// `KeyboardHUDView` applies `.allowsHitTesting(false)` unconditionally, so the
// hosting view is non-interactive at the UIKit level and everything falls
// through to the game below with no extra plumbing.
//
// Installed whenever the player has hardware the legend can describe — a
// keyboard or a game controller. That's always true in desktop input mode
// (Mac "Designed for iPad"), and true on iPad/iPhone as soon as either is
// attached; both of those also hide the on-screen touch controls, which is
// what frees the bottom band the legend occupies.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import UIKit
import SwiftUI
import GameController
import PVLibrary
import PVLogging

// MARK: - Associated-object keys

private enum KeyboardHUDAssociatedKeys {
    static var hostingVC: UInt8 = 0
    static var viewModel: UInt8 = 0
    static var didShowLaunchLegend: UInt8 = 0
}

/// Inset from the safe area on every edge the legend is pinned to.
private let kInputLegendEdgeInset: CGFloat = 8

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

    /// Whether the at-launch legend has already been shown for this game.
    ///
    /// `setupKeyboardHUDIfNeeded()` runs again from `viewDidAppear` (see the
    /// comment at its call site — the pause menu's `.overFullScreen`
    /// presentation drives a disappear/appear cycle that tears the HUD down),
    /// so without this the launch legend would pop up again every time the
    /// pause menu closed.
    private var didShowLaunchLegend: Bool {
        get { (objc_getAssociatedObject(self, &KeyboardHUDAssociatedKeys.didShowLaunchLegend) as? Bool) ?? false }
        set {
            objc_setAssociatedObject(
                self, &KeyboardHUDAssociatedKeys.didShowLaunchLegend,
                newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Installs the input legend and begins passively sampling keyboard state.
    /// No-ops when there's no keyboard or controller to describe, and
    /// idempotent if already installed. Call from `viewDidLoad`, alongside
    /// `setupVirtualInputOverlaysIfNeeded()`.
    public func setupKeyboardHUDIfNeeded() {
        // Anything that can drive the legend: a keyboard, or a gamepad. Desktop
        // input mode implies a keyboard, so it needs no separate check.
        let hasKeyboard = GCKeyboard.coalesced?.keyboardInput != nil
        let hasController = GCController.controllers().contains { $0.extendedGamepad != nil }
        guard hasKeyboard || hasController else { return }
        guard keyboardHUDHostingVC == nil else { return }

        let viewModel = KeyboardHUDViewModel()
        keyboardHUDViewModelStorage = viewModel
        configureInputLegend(viewModel)

        let hostingVC = UIHostingController(rootView: KeyboardHUDView(viewModel: viewModel))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false
        if #available(iOS 16.0, tvOS 16.0, *) {
            hostingVC.sizingOptions = [.intrinsicContentSize]
        }

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        // High zPosition so the legend paints above skins/controller overlays
        // loaded asynchronously, without needing to re-sort the subview array.
        hostingVC.view.layer.zPosition = 9999
        hostingVC.didMove(toParent: self)

        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                   constant: -kInputLegendEdgeInset),
            hostingVC.view.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            hostingVC.view.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor,
                                                    constant: kInputLegendEdgeInset),
            hostingVC.view.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                                                     constant: -kInputLegendEdgeInset)
        ])

        keyboardHUDHostingVC = hostingVC
        viewModel.startObserving()

        if !didShowLaunchLegend {
            didShowLaunchLegend = true
            viewModel.showLaunchLegend()
        }
        ILOG("[InputLegend] Installed (keyboard: \(hasKeyboard), controller: \(hasController))")
    }

    /// Feeds the legend the real mapping data for the running game.
    ///
    /// `faceNamesAreTrustworthy` is the one judgement call: it says the running
    /// core follows the positional MFi↔console face-button convention, so the
    /// system's own A/B/X/Y (or ○✕▵□, Ⅰ/Ⅱ, …) titles from Systems.plist can be
    /// placed on the gamepad's face buttons by geometry. Only the thin libretro
    /// wrapper qualifies: its `PVThinLibretroCore+Controls.swift` performs that
    /// swap uniformly for every core it hosts. Native bridges are each their
    /// own convention — Dolphin maps `buttonA → GameCube BUTTON_A` (identity,
    /// not positional) — so they fall back to generic gamepad labels, which are
    /// true whatever the core does. See `InputLegend.swift`.
    ///
    /// Class-name probing (rather than an `is PVThinLibretroCore` check) is the
    /// established idiom here: PVUIBase deliberately does not link
    /// PVCoreBridgeRetro, and `PVCoreFactory` identifies the same class the
    /// same way.
    private func configureInputLegend(_ viewModel: KeyboardHUDViewModel) {
        let systemID = game?.system?.systemIdentifier
        let layout = systemID.flatMap { PVEmulatorConfiguration.controllerLayout(forSystemIdentifier: $0) }
        let systemName = systemID.flatMap { PVEmulatorConfiguration.shortName(forSystemIdentifier: $0) }
        let isThinLibretroCore = NSStringFromClass(type(of: core)).contains("ThinLibretro")
        viewModel.configure(layout: layout,
                            systemName: systemName,
                            faceNamesAreTrustworthy: isThinLibretroCore)
    }

    /// Tears down the input legend: stops sampling and removes the hosted
    /// view. Call from `viewWillDisappear`, alongside
    /// `removeVirtualInputOverlays()`.
    public func teardownKeyboardHUD() {
        keyboardHUDViewModelStorage?.stopObserving()
        keyboardHUDViewModelStorage = nil

        guard let hostingVC = keyboardHUDHostingVC else { return }
        hostingVC.willMove(toParent: nil)
        hostingVC.view.removeFromSuperview()
        hostingVC.removeFromParent()
        keyboardHUDHostingVC = nil
    }

    /// Shows or hides the persistent input legend — the Game menu's HUD item
    /// calls this. It's the legend's only control: it dismisses the at-launch
    /// legend early while that's still up, and brings the legend back after it
    /// has faded. No-ops if the legend was never installed (no keyboard and no
    /// controller).
    ///
    /// Name and signature are load-bearing — `EmulatorScene.swift` binds a
    /// keyboard shortcut to this selector.
    @objc public func toggleKeyboardHUDPinned() {
        guard let viewModel = keyboardHUDViewModelStorage else { return }
        viewModel.togglePinned()
    }
}
#endif // !os(tvOS)
