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
import Combine
import GameController
import PVCoreBridge
import PVLogging
import PVSettings

// MARK: - Associated-object keys

private enum AssociatedKeys {
    static var keyboardHostingVC: UInt8 = 0
    static var keyboardContainer: UInt8 = 0
    static var keyboardViewModel: UInt8 = 0
    static var keyboardHiddenByHW: UInt8 = 0
    static var hwKeyboardObservers: UInt8 = 0
    static var keyboardFrameCancellable: UInt8 = 0
}

// MARK: - PVEmulatorViewController + VirtualKeyboard

@MainActor
extension PVEmulatorViewController {

    // MARK: - Stored properties via Objective-C associated objects

    /// The UIHostingController wrapping the VirtualKeyboardView, if currently presented.
    var virtualKeyboardHostingVC: UIHostingController<AnyView>? {
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

    /// The passthrough container view that wraps the keyboard hosting controller.
    /// Stored so `bringVirtualInputOverlaysToFront` and `radicalCleanup` can access it.
    var virtualKeyboardContainer: KeyboardPassthroughView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.keyboardContainer) as? KeyboardPassthroughView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.keyboardContainer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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

    /// Combine subscription that forwards the keyboard view model's published
    /// visible-sheet frame into the passthrough container for hit-test gating.
    private var keyboardFrameCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.keyboardFrameCancellable) as? AnyCancellable }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.keyboardFrameCancellable,
                                     newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Capability Checks

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

    /// Wire `VirtualInputState` toggle callbacks and auto-show the keyboard
    /// for cores that require it.
    ///
    /// Call this on iOS after `setupVirtualMouseIfNeeded()` so that the mouse
    /// overlay is already installed before the toggle closures are wired.
    /// Hardware keyboard observation is started first so the virtual keyboard
    /// is never briefly shown then hidden when a physical keyboard is already
    /// connected at launch.
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
    /// - Parameters:
    ///   - animated: Whether to animate the appearance.
    ///   - startExpanded: When `true` the keyboard opens fully expanded (for explicit user toggles).
    ///                    When `false` (default) it opens collapsed to a minimal drag handle
    ///                    (appropriate for auto-show on core launch).
    public func showVirtualKeyboard(animated: Bool = true, startExpanded: Bool = false) {
        guard coreSupportsVirtualKeyboard, !isVirtualKeyboardVisible else { return }

        let layout = resolvedKeyboardLayout()
        let opacity = effectiveKeyboardOverlayConfig?.opacity ?? 1.0

        let viewModel = VirtualKeyboardViewModel(layout: layout, startExpanded: startExpanded)
        viewModel.delegate = self
        viewModel.dismissAction = { [weak self] in
            self?.hideVirtualKeyboard(animated: true)
        }
        virtualKeyboardViewModel = viewModel

        let keyboardView = VirtualKeyboardView(viewModel: viewModel)
        let hostingVC = UIHostingController(rootView: AnyView(keyboardView))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false

        // Wrap in a passthrough container so touches on empty areas
        // (especially when collapsed) fall through to the game/skin below
        let container = KeyboardPassthroughView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.isOpaque = false

        addChild(hostingVC)
        container.addSubview(hostingVC.view)
        view.addSubview(container)
        view.bringSubviewToFront(container)
        // Use high zPosition so keyboard stays above skins loaded asynchronously
        container.layer.zPosition = 9998
        hostingVC.didMove(toParent: self)

        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingVC.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let targetAlpha = CGFloat(max(0, min(1, opacity)))
        if animated {
            hostingVC.view.alpha = 0
            UIView.animate(withDuration: 0.25) { hostingVC.view.alpha = targetAlpha }
        } else {
            hostingVC.view.alpha = targetAlpha
        }

        virtualKeyboardHostingVC = hostingVC
        virtualKeyboardContainer = container
        keyboardHiddenByHardware = false

        // Forward the SwiftUI-published visible-sheet frame into the container so
        // its hitTest only captures touches over the actually-visible keyboard.
        keyboardFrameCancellable = viewModel.$keyboardFrame
            .receive(on: RunLoop.main)
            .sink { [weak container] frame in
                container?.visibleKeyboardFrame = frame
            }

        ILOG("[VirtualKeyboard] Keyboard overlay shown (layout: \(layout), opacity: \(opacity), animated: \(animated))")

        // Update the type-safe state so all observers (SwiftUI and UIKit) stay in sync.
        virtualInputState.setKeyboardVisible(true)
    }

    /// Hide the virtual keyboard overlay, releasing all held keys first.
    public func hideVirtualKeyboard(animated: Bool = true) {
        guard let hostingVC = virtualKeyboardHostingVC else { return }

        // Release all held/modifier keys so the emulator doesn't see stuck keys
        virtualKeyboardViewModel?.releaseAllKeys()

        keyboardFrameCancellable?.cancel()
        keyboardFrameCancellable = nil

        let containerToRemove = virtualKeyboardContainer
        let cleanup = {
            hostingVC.willMove(toParent: nil)
            hostingVC.view.removeFromSuperview()
            hostingVC.removeFromParent()
            containerToRemove?.removeFromSuperview()
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                hostingVC.view.alpha = 0
            }, completion: { _ in cleanup() })
        } else {
            cleanup()
        }

        virtualKeyboardHostingVC = nil
        virtualKeyboardContainer = nil
        virtualKeyboardViewModel = nil
        ILOG("[VirtualKeyboard] Keyboard overlay hidden (animated: \(animated))")

        // Update the type-safe state so all observers stay in sync.
        virtualInputState.setKeyboardVisible(false)
    }

    /// Toggle keyboard visibility.
    /// User-triggered toggles always open the keyboard expanded.
    public func toggleVirtualKeyboard(animated: Bool = true) {
        if isVirtualKeyboardVisible {
            hideVirtualKeyboard(animated: animated)
        } else {
            showVirtualKeyboard(animated: animated, startExpanded: true)
        }
    }

    /// Bring all virtual input overlays to the front of the view hierarchy in the correct stacking order.
    ///
    /// Order (back to front) when DeltaSkins are OFF:
    ///   trackpad → controller overlay (HUD buttons) → keyboard container → cursor (non-interactive) → menu button
    ///
    /// Order (back to front) when DeltaSkins are ON (no mouse):
    ///   trackpad → skin container → keyboard container → cursor (non-interactive) → menu button
    ///
    /// Order (back to front) when DeltaSkins are ON + virtual mouse active:
    ///   skin container → trackpad → keyboard container → cursor (non-interactive) → menu button
    ///
    /// When the virtual mouse is active with a skin, the trackpad must sit above the skin container
    /// so it receives game-viewport touches.  TouchTrackpadView.hitTest() gates touches to the
    /// game viewport rect, so skin button touches outside that area still fall through to the skin.
    ///
    /// When a DeltaSkin is active (no mouse), the skin container provides all controller buttons.
    /// The standard controller overlay is hidden and must NOT be raised above the skin container —
    /// doing so intercepts all touches before they reach the skin's MultiTouchView.
    public func bringVirtualInputOverlaysToFront() {
        if let trackpadView = touchTrackpadView {
            view.bringSubviewToFront(trackpadView)
        }
        // When a DeltaSkin is active AND the skin container is already installed,
        // it is the interactive layer for button input — raise it above the trackpad.
        // Exception: when virtual mouse is active, trackpad must be raised above the skin
        // container afterwards so it can intercept game-viewport touches.
        // Fall back to the standard controller overlay in all other cases (skins off,
        // skin mode on but container not yet loaded, native core, etc.) so touches
        // are never blocked by a view that isn't there.
        if isDeltaSkinEnabled, let skinContainer = skinContainerView {
            view.bringSubviewToFront(skinContainer)
            // Raise trackpad above skin when mouse is active — its hitTest() gates
            // to the viewport rect so skin button touches still reach the skin below.
            if isVirtualMouseVisible, let trackpad = touchTrackpadView {
                view.bringSubviewToFront(trackpad)
            }
        } else if let controllerView = controllerViewController?.view {
            view.bringSubviewToFront(controllerView)
        }
        // Keyboard container above whichever interactive layer is active.
        // KeyboardPassthroughView passes non-keyboard-area touches back through.
        if let keyboardContainer = virtualKeyboardContainer {
            view.bringSubviewToFront(keyboardContainer)
        }
        // Light gun touch layer sits above the controller/skin interactive layer
        // but below the cursor overlay, so the aim-point cursor renders on top.
        if let lightGunView = lightGunTouchView {
            view.bringSubviewToFront(lightGunView)
        }
        if let cursorView = cursorHostingController?.view {
            view.bringSubviewToFront(cursorView)
        }
        if let menuButton = menuButton {
            view.bringSubviewToFront(menuButton)
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

// MARK: - Passthrough container

/// A UIView that passes through touches outside the visible keyboard sheet to
/// views below, while still allowing touches on the keyboard itself.
///
/// The hosting controller's view fills this container edge-to-edge, so a naive
/// `hit === self` check never passes (the hit is always the hosting view). Instead
/// we gate hit-testing to `visibleKeyboardFrame`, which the SwiftUI view publishes
/// (via a preference key → view model → here) as the actual on-screen bounds of
/// the visible sheet — collapsed handle or full keyboard. Touches outside that
/// rect fall through to the game / skin / on-screen controls below.
final class KeyboardPassthroughView: UIView {
    /// The frame of the visible keyboard sheet, in this view's coordinate space.
    /// When `.zero` (not yet measured) the view passes all touches through.
    var visibleKeyboardFrame: CGRect = .zero

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Until the SwiftUI view reports its frame, don't steal any touches.
        guard !visibleKeyboardFrame.isEmpty else { return nil }
        // Only capture touches that land within the visible keyboard sheet.
        guard visibleKeyboardFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

#endif // !os(tvOS)
