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
import PVSettings

// MARK: - Associated-object keys

private enum AssociatedKeys {
    static var keyboardHostingVC: UInt8 = 0
    static var keyboardViewModel: UInt8 = 0
    static var keyboardHiddenByHW: UInt8 = 0
    static var hwKeyboardObservers: UInt8 = 0
    static var virtualInputState: UInt8 = 0
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

    /// Tracks whether the virtual keyboard was auto-hidden due to a hardware keyboard
    /// connecting, so it can be restored when the hardware keyboard disconnects.
    private var keyboardHiddenByHardware: Bool {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.keyboardHiddenByHW) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self, &AssociatedKeys.keyboardHiddenByHW,
                newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Notification observer tokens (`NSObjectProtocol`) for hardware keyboard
    /// connect/disconnect events — typed for safe `removeObserver(_:)` calls.
    private var hwKeyboardObservers: [NSObjectProtocol]? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.hwKeyboardObservers)
                as? [NSObjectProtocol]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.hwKeyboardObservers,
                                     newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - VirtualInputState (type-safe state & callback container)

    /// The observable state object that drives virtual-input overlay UI.
    ///
    /// Created lazily on first access (after `core` is available).  The same
    /// instance is reused for the lifetime of the session.  Inject it into the
    /// SwiftUI environment via `.environmentObject(virtualInputState)`.
    public var virtualInputState: VirtualInputState {
        if let existing = objc_getAssociatedObject(self, &AssociatedKeys.virtualInputState)
                            as? VirtualInputState {
            return existing
        }
        let state = VirtualInputState(
            supportsKeyboard: coreSupportsVirtualKeyboard,
            supportsMouse: coreSupportsVirtualMouse
        )
        objc_setAssociatedObject(
            self, &AssociatedKeys.virtualInputState,
            state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return state
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
    /// Wires the `VirtualInputState` action callbacks, then auto-shows the
    /// keyboard if the core requires it and no hardware keyboard is connected.
    ///
    /// Hardware keyboard observation is started first so the virtual keyboard
    /// is never briefly shown then hidden when a physical keyboard is already
    /// connected.
    public func setupVirtualInputOverlaysIfNeeded() {
        // Wire action callbacks on the shared state object so SwiftUI buttons
        // and UIKit buttons both route through the same typed interface.
        virtualInputState.onToggleKeyboard = { [weak self] in
            self?.toggleVirtualKeyboard()
        }
        virtualInputState.onToggleMouse = { [weak self] in
            self?.toggleVirtualMouse()
        }

        startObservingHardwareKeyboard()

        if GCKeyboard.coalesced != nil {
            ILOG("[VirtualKeyboard] Hardware keyboard already connected — skipping auto-show")
            keyboardHiddenByHardware = coreRequiresVirtualKeyboard || (effectiveKeyboardOverlayConfig?.autoShow == true)
            return
        }

        if coreRequiresVirtualKeyboard {
            showVirtualKeyboard()
        }
        applyKeyboardOverlayConfigIfNeeded()
        DLOG("[VirtualKeyboard] setupVirtualInputOverlaysIfNeeded completed, visible=\(isVirtualKeyboardVisible)")
    }

    /// Tears down the keyboard overlay. Call from `viewWillDisappear` or `deinit`.
    public func removeVirtualInputOverlays() {
        stopObservingHardwareKeyboard()
        hideVirtualKeyboard()
    }

    /// Resolves which `VirtualKeyboardLayout` to use.
    ///
    /// Priority:
    ///   1. Explicit skin JSON `keyboardOverlay` — skin authors' intent wins.
    ///   2. User's persisted `preferredKeyboardVariant` — last layout the user chose.
    ///   3. System default from `DeltaSkinDefaults` — built-in per-game-type fallback.
    ///   4. `.full` — universal fallback.
    private func resolvedKeyboardLayout() -> VirtualKeyboardLayout {
        if let skinConfig = currentSkin?.keyboardOverlay {
            return skinConfig.variant.toLayout()
        }
        if let variant = VirtualKeyboardVariant(rawValue: Defaults[.preferredKeyboardVariant]) {
            return variant.toLayout()
        }
        if let gameType = currentSkin?.gameType,
           let defaultConfig = DeltaSkinDefaults.defaultKeyboardOverlay(for: gameType) {
            return defaultConfig.variant.toLayout()
        }
        return .full
    }

    /// Show the virtual keyboard overlay.
    /// Does nothing if the core does not support keyboard input or if already visible.
    public func showVirtualKeyboard(animated: Bool = true) {
        guard coreSupportsVirtualKeyboard, !isVirtualKeyboardVisible else { return }

        let layout = resolvedKeyboardLayout()
        let opacity = effectiveKeyboardOverlayConfig?.opacity ?? 1.0

        let viewModel = VirtualKeyboardViewModel(layout: layout)
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
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let targetAlpha = CGFloat(max(0, min(1, opacity)))
        if animated {
            hostingVC.view.alpha = 0
            UIView.animate(withDuration: 0.25) { hostingVC.view.alpha = targetAlpha }
        } else {
            hostingVC.view.alpha = targetAlpha
        }

        virtualKeyboardHostingVC = hostingVC
        keyboardHiddenByHardware = false
        ILOG("[VirtualKeyboard] Keyboard overlay shown (layout: \(layout), opacity: \(opacity), animated: \(animated))")

        // Update the type-safe state so all observers (SwiftUI and UIKit) stay in sync.
        virtualInputState.setKeyboardVisible(true)
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

        // Update the type-safe state so all observers stay in sync.
        virtualInputState.setKeyboardVisible(false)
    }

    /// Toggle keyboard visibility.
    public func toggleVirtualKeyboard(animated: Bool = true) {
        if isVirtualKeyboardVisible {
            hideVirtualKeyboard(animated: animated)
        } else {
            showVirtualKeyboard(animated: animated)
        }
    }

    /// Bring all virtual input overlays (keyboard → trackpad → mouse cursor) to the front
    /// of the view hierarchy in the correct stacking order.
    public func bringVirtualInputOverlaysToFront() {
        if let keyboardView = virtualKeyboardHostingVC?.view {
            view.bringSubviewToFront(keyboardView)
        }
        if let trackpadView = touchTrackpadView {
            view.bringSubviewToFront(trackpadView)
        }
        if let cursorView = cursorHostingController?.view {
            view.bringSubviewToFront(cursorView)
        }
    }

    // MARK: - Hardware Keyboard Detection

    /// Begin observing GCKeyboard connect/disconnect to auto-hide the virtual keyboard
    /// when a physical keyboard is available.
    private func startObservingHardwareKeyboard() {
        guard hwKeyboardObservers == nil, coreSupportsVirtualKeyboard else { return }

        let connectToken = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleHardwareKeyboardConnected()
        }
        let disconnectToken = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleHardwareKeyboardDisconnected()
        }
        hwKeyboardObservers = [connectToken, disconnectToken]
    }

    /// Stop observing hardware keyboard notifications.
    private func stopObservingHardwareKeyboard() {
        if let observers = hwKeyboardObservers {
            for token in observers {
                NotificationCenter.default.removeObserver(token)
            }
        }
        hwKeyboardObservers = nil
    }

    private func handleHardwareKeyboardConnected() {
        guard isVirtualKeyboardVisible else { return }
        ILOG("[VirtualKeyboard] Hardware keyboard connected — auto-hiding virtual keyboard")
        keyboardHiddenByHardware = true
        hideVirtualKeyboard(animated: true)
    }

    private func handleHardwareKeyboardDisconnected() {
        guard GCKeyboard.coalesced == nil, keyboardHiddenByHardware else { return }
        ILOG("[VirtualKeyboard] Hardware keyboard disconnected — restoring virtual keyboard")
        keyboardHiddenByHardware = false
        showVirtualKeyboard(animated: true)
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
