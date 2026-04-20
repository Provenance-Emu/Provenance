// MARK: - Controllers
import PVLogging
import GameController
import PVCoreBridge
import PVSupport
import PVSettings
#if canImport(SteamController)
import SteamController
#endif

extension PVEmulatorViewController {
    @objc func handlePause(_ note: Notification?) {
        ILOG("handlePause: PauseGame notification received")
        self.controllerPauseButtonPressed(note)
    }

    public func hideOrShowMenuButton() {

        // If DeltaSkins are enabled, hide the legacy overlay menu button
        if isDeltaSkinEnabled {
            menuButton?.isHidden = true
        } else {
            // find out how many *real* controllers we have....
            let controllers = PVControllerManager.shared.controllers.filter { controller in
                // 8Bitdo controllers don't have a pause button, so don't hide the menu
                if (controller is PViCade8BitdoController || controller is PViCade8BitdoZeroController) {
                    return false
                }
                // show menu for "virtual" controllers
                if (controller.isSnapshot) {
                    return false
                }
                return true
            }

            // don't hide menu button
            menuButton?.isHidden = false; //controllers.count != 0
        }

        #if os(iOS)
            self.setNeedsStatusBarAppearanceUpdate()
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
            self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        #endif
    }

    @objc func controllerDidConnect(_ note: Notification?) {
        hideOrShowMenuButton()
        /// Rebind pause handlers for the freshly connected controller. Deferred by
        /// one runloop tick so the core's own `controllerDidConnect` observer runs
        /// first (cores typically install their own `pressedChangedHandler` on the
        /// same buttons we use for pause) — we want our binding to be the last one
        /// written so pause survives core wiring. A second pass at +0.3s catches
        /// cores that wire the controller asynchronously during their first frame.
        DispatchQueue.main.async { [weak self] in
            self?.reestablishPauseHandlers()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.reestablishPauseHandlers()
        }
    }

    @objc func controllerDidDisconnect(_: Notification?) {
        hideOrShowMenuButton()
    }

    @objc func handleControllerManagerControllerReassigned(_: Notification?) {
        core.controller1 = PVControllerManager.shared.player1
        core.controller2 = PVControllerManager.shared.player2
        core.controller3 = PVControllerManager.shared.player3
        core.controller4 = PVControllerManager.shared.player4
        core.controller5 = PVControllerManager.shared.player5
        core.controller6 = PVControllerManager.shared.player6
        core.controller7 = PVControllerManager.shared.player7
        core.controller8 = PVControllerManager.shared.player8

        hideOrShowMenuButton()
        #if os(tvOS) && canImport(SteamController)
        PVControllerManager.shared.setSteamControllersMode(core.isRunning ? .gameController : .keyboardAndMouse)
        #endif
        #if os(tvOS)
        setupSiriRemoteForKeyboardCore()
        setupSiriRemoteForLightGunCore()
        #endif
    }

    // MARK: - UIScreenNotifications

    @objc func screenDidConnect(_ note: Notification?) {
        ILOG("Screen did connect: \(note?.object ?? "")")
        guard secondaryScreen == nil else { return }

        guard let screen = note?.object as? UIScreen else {
            ELOG("screenDidConnect: notification did not carry a UIScreen – ignoring")
            Task { @MainActor in self.hideOrShowMenuButton() }
            return
        }

        let mode = Defaults[.externalDisplayMode]
        let canUseDedicated = core.supportsExternalDisplay

        guard mode == .dedicated && canUseDedicated else {
            ILOG("External display connected – using system mirror mode (mode=\(mode.rawValue), canUseDedicated=\(canUseDedicated))")
            Task { @MainActor in self.hideOrShowMenuButton() }
            return
        }

        ILOG("External display connected – activating dedicated game view")
        Task { @MainActor in
            self.attachGPUView(to: screen)
            self.hideOrShowMenuButton()
        }
    }

    @objc func screenDidDisconnect(_ note: Notification?) {
        ILOG("Screen did disconnect: \(note?.object ?? "")")
        let screen = note?.object as? UIScreen
        guard secondaryScreen == screen else { return }
        Task { @MainActor in
            self.restoreGPUViewToDevice()
            self.hideOrShowMenuButton()
        }
    }

    // MARK: - External Display Helpers

    /// Moves the GPU view controller to the specified external screen's window.
    func attachGPUView(to screen: UIScreen) {
        secondaryScreen = screen
        // Only run the containment removal sequence when the VC is currently parented
        // (e.g., the launch-time path calls this before the first addChild, so there is
        // nothing to remove and calling willMove/removeFromParent would be a no-op).
        if gpuViewController.parent != nil {
            gpuViewController.willMove(toParent: nil)
            gpuViewController.view?.removeFromSuperview()
            gpuViewController.removeFromParent()
            // Note: removeFromParent() automatically calls didMove(toParent: nil)
        }

        let window = UIWindow(frame: screen.bounds)
        // `UIWindow.screen` is deprecated in iOS 13 but remains the only reliable
        // way to target a specific `UIScreen` without a full `UIWindowScene`
        // integration.  The scene-based path (iOS 16+) would require adopting
        // `UIWindowSceneGeometryPreferencesExternal`, which is a multi-step refactor
        // tracked in the issue body.  For now we keep the legacy assignment so the
        // feature works on iOS 15 and up.
        window.screen = screen
        // Setting rootViewController lets UIWindow own and manage the view lifecycle.
        // Do NOT also call window.addSubview(gpuViewController.view) — that would
        // create a redundant subview relationship and cause layout/lifecycle issues.
        window.rootViewController = gpuViewController
        window.isHidden = false
        gpuViewController.view?.setNeedsLayout()
        secondaryWindow = window
    }

    /// Restores the GPU view controller back to the primary device screen after
    /// an external display disconnects.
    func restoreGPUViewToDevice() {
        // Detach from the external window FIRST, before re-parenting, so that
        // gpuViewController is never simultaneously owned by two windows/hierarchies.
        secondaryWindow?.rootViewController = nil
        secondaryWindow?.isHidden = true
        secondaryWindow = nil
        secondaryScreen = nil

        // Only run the containment removal sequence when the VC has a parent.
        // When it is a window rootViewController (the dedicated-display path),
        // UIKit manages its lifecycle via `secondaryWindow?.rootViewController = nil`
        // above, so manually calling willMove/removeFromParent/didMove on a
        // parentless VC would be incorrect.
        if gpuViewController.parent != nil {
            gpuViewController.willMove(toParent: nil)
            gpuViewController.view?.removeFromSuperview()
            gpuViewController.removeFromParent()
            // Note: removeFromParent() automatically calls didMove(toParent: nil)
        }

        // addChild automatically calls willMove(toParent: self) on the child.
        addChild(gpuViewController)

        if let gpuView = gpuViewController.view {
            // Reset to device bounds so the view isn't left with an external-display
            // sized frame after disconnect.
            gpuView.frame = view.bounds
            gpuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            if let controllerView = controllerViewController?.view {
                view.insertSubview(gpuView, belowSubview: controllerView)
            } else {
                // Fallback: reattach GPU view even when controller view is unavailable.
                view.addSubview(gpuView)
            }
        }

        // Complete the containment cycle; this triggers viewDidMove and appearance callbacks.
        gpuViewController.didMove(toParent: self)
        gpuViewController.view?.setNeedsLayout()
    }
}

// MARK: - tvOS Siri Remote Input

#if os(tvOS)
extension PVEmulatorViewController {

    /// Tracks which Siri Remote dpad/button keys are currently pressed so we can
    /// send matching keyUp events when they are released.
    private struct SiriRemoteKeyState {
        var upPressed = false
        var downPressed = false
        var leftPressed = false
        var rightPressed = false
        var aPressed = false
    }

    // We use associated objects to store per-instance state without stored properties.
    private static var siriKeyStateKey = "siriKeyStateKey"
    private static var siriPanStartKey = "siriPanStartKey"
    private static var siriKeyboardActiveKey = "siriKeyboardActiveKey"
    private static var siriMouseActiveKey = "siriMouseActiveKey"

    private var siriKeyState: SiriRemoteKeyState {
        get {
            return (objc_getAssociatedObject(self, &Self.siriKeyStateKey) as? Box<SiriRemoteKeyState>)?.value
                ?? SiriRemoteKeyState()
        }
        set {
            objc_setAssociatedObject(self, &Self.siriKeyStateKey, Box(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var siriPanLastPosition: CGPoint? {
        get { return (objc_getAssociatedObject(self, &Self.siriPanStartKey) as? Box<CGPoint?>)?.value ?? nil }
        set { objc_setAssociatedObject(self, &Self.siriPanStartKey, Box(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Whether the Siri Remote D-pad keyboard handler is currently installed.
    private var isSiriKeyboardActive: Bool {
        get { (objc_getAssociatedObject(self, &Self.siriKeyboardActiveKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &Self.siriKeyboardActiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Whether the Siri Remote touch-surface mouse pan gesture is currently installed.
    private var isSiriMouseActive: Bool {
        get { (objc_getAssociatedObject(self, &Self.siriMouseActiveKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &Self.siriMouseActiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Installs value-changed handlers on the Siri Remote (GCMicroGamepad) for
    /// cores that implement KeyboardResponder / MouseResponder.
    /// Also wires `VirtualInputState` toggle closures so future tvOS UI can
    /// trigger input-mode changes through the same typed interface as iOS.
    func setupSiriRemoteForKeyboardCore() {
        guard let microGamepad = GCController.controllers().first(where: { $0.microGamepad != nil })?.microGamepad else {
            return
        }

        let keyboardCore = core as? KeyboardResponder
        let mouseCore = core as? MouseResponder

        guard keyboardCore != nil || mouseCore != nil else { return }
        guard keyboardCore?.gameSupportsKeyboard == true || mouseCore?.gameSupportsMouse == true else { return }

        ILOG("tvOS: Installing Siri Remote handlers for keyboard/mouse core")

        // Wire toggle closures so any future tvOS UI (pause menu, status bar) can
        // flip input modes through the same VirtualInputState interface as iOS.
        virtualInputState.onToggleKeyboard = { [weak self] in self?.toggleSiriRemoteKeyboard() }
        virtualInputState.onToggleMouse    = { [weak self] in self?.toggleSiriRemoteMouse() }

        if let kbCore = keyboardCore, kbCore.gameSupportsKeyboard {
            installDpadKeyboardHandler(on: microGamepad, core: kbCore)
            isSiriKeyboardActive = true
            virtualInputState.setKeyboardVisible(true)
        }

        if let msCore = mouseCore, msCore.gameSupportsMouse {
            installTouchSurfaceMouseHandler()
            isSiriMouseActive = true
            virtualInputState.setMouseVisible(true)
        }
    }

    /// Toggle the Siri Remote D-pad keyboard handler on/off, keeping
    /// `VirtualInputState` in sync so UI observers always reflect reality.
    func toggleSiriRemoteKeyboard() {
        if isSiriKeyboardActive {
            // Remove the D-pad keyboard handler.
            if let micro = GCController.controllers().first(where: { $0.microGamepad != nil })?.microGamepad {
                micro.valueChangedHandler = nil
            }
            // Reset Siri Remote key-tracking state so no stale flags persist
            // across disable/enable cycles.
            siriKeyState = SiriRemoteKeyState()
            isSiriKeyboardActive = false
            virtualInputState.setKeyboardVisible(false)
            ILOG("tvOS: Siri Remote keyboard handler removed")
        } else {
            guard let kbCore = core as? KeyboardResponder, kbCore.gameSupportsKeyboard,
                  let micro = GCController.controllers().first(where: { $0.microGamepad != nil })?.microGamepad else {
                return
            }
            // Start from a clean Siri Remote key-tracking state whenever we
            // (re)install the D-pad keyboard handler.
            siriKeyState = SiriRemoteKeyState()
            installDpadKeyboardHandler(on: micro, core: kbCore)
            isSiriKeyboardActive = true
            virtualInputState.setKeyboardVisible(true)
            ILOG("tvOS: Siri Remote keyboard handler installed")
        }
    }

    /// Toggle the Siri Remote touch-surface mouse pan gesture on/off, keeping
    /// `VirtualInputState` in sync so UI observers always reflect reality.
    func toggleSiriRemoteMouse() {
        if isSiriMouseActive {
            view.gestureRecognizers?
                .filter { $0.name == "SiriRemoteMousePan" }
                .forEach { view.removeGestureRecognizer($0) }
            isSiriMouseActive = false
            virtualInputState.setMouseVisible(false)
            ILOG("tvOS: Siri Remote mouse pan gesture removed")
        } else {
            guard let mouseCore = core as? MouseResponder, mouseCore.gameSupportsMouse else { return }
            installTouchSurfaceMouseHandler()
            isSiriMouseActive = true
            virtualInputState.setMouseVisible(true)
            ILOG("tvOS: Siri Remote mouse pan gesture installed")
        }
    }

    /// Maps the Siri Remote D-pad to arrow keys and buttonA to Return.
    private func installDpadKeyboardHandler(on microGamepad: GCMicroGamepad, core: KeyboardResponder) {
        microGamepad.valueChangedHandler = { [weak self] (gamepad, element) in
            guard let self = self else { return }
            var state = self.siriKeyState

            // Up
            let upNow = gamepad.dpad.up.isPressed
            if upNow != state.upPressed {
                upNow ? core.keyDown(.upArrow) : core.keyUp(.upArrow)
                state.upPressed = upNow
            }
            // Down
            let downNow = gamepad.dpad.down.isPressed
            if downNow != state.downPressed {
                downNow ? core.keyDown(.downArrow) : core.keyUp(.downArrow)
                state.downPressed = downNow
            }
            // Left
            let leftNow = gamepad.dpad.left.isPressed
            if leftNow != state.leftPressed {
                leftNow ? core.keyDown(.leftArrow) : core.keyUp(.leftArrow)
                state.leftPressed = leftNow
            }
            // Right
            let rightNow = gamepad.dpad.right.isPressed
            if rightNow != state.rightPressed {
                rightNow ? core.keyDown(.rightArrow) : core.keyUp(.rightArrow)
                state.rightPressed = rightNow
            }
            // buttonA → Return/Enter
            let aNow = gamepad.buttonA.isPressed
            if aNow != state.aPressed {
                aNow ? core.keyDown(.returnOrEnter) : core.keyUp(.returnOrEnter)
                state.aPressed = aNow
            }

            self.siriKeyState = state
        }
    }

    /// Installs a pan gesture on the emulator view so the Siri Remote touch surface
    /// produces relative mouse-movement events.
    private func installTouchSurfaceMouseHandler() {
        // Remove any previously installed recognizer of the same kind.
        view.gestureRecognizers?
            .filter { $0.name == "SiriRemoteMousePan" }
            .forEach { view.removeGestureRecognizer($0) }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSiriRemoteMousePan(_:)))
        pan.name = "SiriRemoteMousePan"
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        view.addGestureRecognizer(pan)
    }

    @objc private func handleSiriRemoteMousePan(_ gesture: UIPanGestureRecognizer) {
        guard let mouseCore = core as? MouseResponder, mouseCore.gameSupportsMouse else { return }

        let sensitivity = Float(Defaults[.tvOSSiriRemoteMouseSensitivity])
        let translation = gesture.translation(in: view)
        let delta = CGPoint(
            x: translation.x * CGFloat(sensitivity),
            y: translation.y * CGFloat(sensitivity)
        )

        switch gesture.state {
        case .began:
            siriPanLastPosition = CGPoint.zero
        case .changed:
            let last = siriPanLastPosition ?? .zero
            let moveDelta = CGPoint(x: delta.x - last.x, y: delta.y - last.y)
            mouseCore.mouseMoved(atPoint: moveDelta)
            siriPanLastPosition = delta
        case .ended, .cancelled:
            siriPanLastPosition = nil
        default:
            break
        }
    }
}

// MARK: - tvOS Light Gun Remote Input

private enum LGRemoteHandlerKey {
    static var savedHandler: UInt8 = 0
}

extension PVEmulatorViewController {

    /// Installs Siri Remote (GCMicroGamepad) gesture handlers for cores that
    /// implement `LightGunResponder`.
    ///
    /// Mapping:
    ///   - D-pad                      → aim (lightGunMovedToPoint)
    ///   - Button A (select)          → trigger (lightGunTriggerDown/Up)
    ///   - Touch-surface tap          → trigger at current aim point
    ///   - Touch-surface long press   → reload (lightGunReloadDown/Up)
    func setupSiriRemoteForLightGunCore() {
        guard let gunCore = core as? LightGunResponder,
              gunCore.gameSupportsLightGun else { return }
        guard let microGamepad = GCController.controllers()
                .first(where: { $0.microGamepad != nil })?.microGamepad else {
            WLOG("tvOS: No micro-gamepad found for light gun mapping")
            return
        }

        teardownSiriRemoteForLightGun()

        ILOG("tvOS: Installing Siri Remote light-gun handlers")

        // Save the existing valueChangedHandler so teardown can restore it.
        let savedHandler = microGamepad.valueChangedHandler
        objc_setAssociatedObject(
            microGamepad,
            &LGRemoteHandlerKey.savedHandler,
            Box(savedHandler),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        // D-pad → aim; accumulates a virtual normalized position.
        var aimPosition = CGPoint(x: 0.5, y: 0.5)
        let step: CGFloat = 0.05
        var wasButtonAPressed = false

        microGamepad.valueChangedHandler = { [weak gunCore] (gamepad, _) in
            guard let gunCore = gunCore else { return }

            // Move aim with D-pad.
            aimPosition.x = max(0, min(1, aimPosition.x + CGFloat(gamepad.dpad.right.value - gamepad.dpad.left.value) * step))
            aimPosition.y = max(0, min(1, aimPosition.y + CGFloat(gamepad.dpad.down.value  - gamepad.dpad.up.value)   * step))
            gunCore.lightGunMovedToPoint(aimPosition, isOffscreen: false)

            // buttonA → trigger (fire only on state transitions to avoid repeated calls)
            let isPressed = gamepad.buttonA.isPressed
            if isPressed != wasButtonAPressed {
                wasButtonAPressed = isPressed
                if isPressed {
                    gunCore.lightGunTriggerDown()
                } else {
                    gunCore.lightGunTriggerUp()
                }
            }
        }

        // Touch-surface tap → trigger at current aim position
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSiriRemoteLightGunTap(_:)))
        tapGesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        tapGesture.name = "SiriRemoteLightGunTap"
        view.addGestureRecognizer(tapGesture)

        // Touch-surface long press → reload
        let reloadGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSiriRemoteLightGunReload(_:)))
        reloadGesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        reloadGesture.name = "SiriRemoteLightGunReload"
        reloadGesture.minimumPressDuration = 0.6
        view.addGestureRecognizer(reloadGesture)
    }

    @objc private func handleSiriRemoteLightGunTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
              let gunCore = core as? LightGunResponder,
              gunCore.gameSupportsLightGun else { return }
        gunCore.lightGunTriggerDown()
        gunCore.lightGunTriggerUp()
    }

    @objc private func handleSiriRemoteLightGunReload(_ gesture: UILongPressGestureRecognizer) {
        guard let gunCore = core as? LightGunResponder,
              gunCore.gameSupportsLightGun else { return }
        switch gesture.state {
        case .began:
            gunCore.lightGunReloadDown?()
        case .ended, .cancelled, .failed:
            gunCore.lightGunReloadUp?()
        default:
            break
        }
    }

    /// Remove all Siri Remote light-gun gesture recognizers and restore the previous
    /// valueChangedHandler on the micro-gamepad.
    func teardownSiriRemoteForLightGun() {
        view.gestureRecognizers?
            .filter { $0.name == "SiriRemoteLightGunTap" || $0.name == "SiriRemoteLightGunReload" }
            .forEach { view.removeGestureRecognizer($0) }

        guard let microGamepad = GCController.controllers()
                .first(where: { $0.microGamepad != nil })?.microGamepad else { return }

        // Restore the previously saved valueChangedHandler (if any).
        let boxedHandler = objc_getAssociatedObject(
            microGamepad,
            &LGRemoteHandlerKey.savedHandler
        ) as? Box<GCMicroGamepadValueChangedHandler?>
        microGamepad.valueChangedHandler = boxedHandler?.value ?? nil
        objc_setAssociatedObject(
            microGamepad,
            &LGRemoteHandlerKey.savedHandler,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

/// Simple generic box so we can store value types in associated-object storage.
private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
#endif
