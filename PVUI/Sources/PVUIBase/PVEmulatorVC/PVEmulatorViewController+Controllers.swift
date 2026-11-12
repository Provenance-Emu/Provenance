// MARK: - Controllers
import PVLogging
import GameController
import PVCoreBridge
import PVSupport
import PVSettings
import SkinKitCore
#if canImport(SteamController)
import SteamController
#endif

extension PVEmulatorViewController {
    @objc func handlePause(_ note: Notification?) {
        /// Every pause source funnels through here, so this is the one place
        /// that can stop a single press from toggling the menu open and shut.
        let uptime = ProcessInfo.processInfo.systemUptime
        guard pauseToggleCoalescer.shouldAccept(at: uptime) else {
            ILOG("handlePause: duplicate PauseGame for the same press — ignored (isShowingMenu=\(isShowingMenu))")
            return
        }
        ILOG("handlePause: PauseGame notification received")
        self.controllerPauseButtonPressed(note)
    }

    /// How long the skin layer gets to put its controls on screen before the
    /// floating menu button comes back.
    private static let skinLoadGrace: TimeInterval = 3

    public func hideOrShowMenuButton() {
        /// A skin — or the built-in controller that stands in when none is
        /// installed — draws its own menu button, so the floating one stays
        /// hidden while that layer is on screen or still loading. When the
        /// layer never comes up, or is hidden because a controller is
        /// connected, nothing else on a touch screen opens the pause menu, so
        /// the floating button returns rather than leaving the player stuck.
        /// That matches the classic controls, which keep it visible too.
        let skinControlsOnScreen = skinDidReportLoaded && skinContainerView.map { !$0.isHidden && $0.superview != nil } == true
        /// The programmatic touch overlay has no menu control in Phase 1, so it keeps the floating one.
        let skinOwnsMenuButton = isDeltaSkinEnabled && !isProgrammaticOverlayActive
            && (skinControlsOnScreen || !skinLoadGraceExpired)
        menuButton?.isHidden = skinOwnsMenuButton
        if !skinOwnsMenuButton, let menuButton {
            view.bringSubviewToFront(menuButton)
        }

        #if os(iOS)
            self.setNeedsStatusBarAppearanceUpdate()
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
            self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        #endif
    }

    /// The skin container is re-fronted on every layout pass; while the programmatic overlay
    /// relies on the floating menu button, put the button back above it.
    func keepOverlayMenuButtonInFront() {
        guard isProgrammaticOverlayActive, let menuButton, !menuButton.isHidden else { return }
        view.bringSubviewToFront(menuButton)
    }

    /// Re-evaluates the floating menu button once the skin layer has had time
    /// to load. Called when skin setup starts.
    func scheduleMenuButtonFallback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.skinLoadGrace) { [weak self] in
            guard let self else { return }
            self.skinLoadGraceExpired = true
            self.hideOrShowMenuButton()
            if self.menuButton?.isHidden == false {
                WLOG("skins: no skin controls on screen \(Int(Self.skinLoadGrace))s after setup — showing the floating menu button")
            }
        }
    }

    @objc func controllerDidConnect(_ note: Notification?) {
        hideOrShowMenuButton()
        updateOnScreenControlsVisibility()
        #if os(iOS)
        updateExternalDisplay()
        #endif
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

    @objc func controllerDidDisconnect(_ note: Notification?) {
        hideOrShowMenuButton()
        updateOnScreenControlsVisibility()
        #if os(iOS)
        updateExternalDisplay()
        #endif
        pauseIfLastGamepadDisconnected(note?.object as? GCController)
    }

    /// A game pauses when its last gamepad goes away (flat battery, sleep, out of range) instead of
    /// playing on with nobody at the controls, as Apple's controller guidance asks.
    /// The keyboard-backed controller (a snapshot) and the Siri Remote don't count.
    private func pauseIfLastGamepadDisconnected(_ controller: GCController?) {
        guard let controller, Self.isGameplayController(controller) else { return }
        let disconnected = (controller as? PVPhysicalProfileController)?.base ?? controller
        let gamepadRemains = PVControllerManager.shared.controllers.contains { candidate in
            let physical = (candidate as? PVPhysicalProfileController)?.base ?? candidate
            return physical !== disconnected && Self.isGameplayController(candidate)
        }
        guard !gamepadRemains, core.isOn, !isShowingMenu, !isQuitting else { return }
        ILOG("Gamepad \(controller.vendorName ?? "unknown") disconnected — pausing")
        isShowingMenu = true
        showMenu(nil)
    }

    // MARK: - Auto-hide on-screen controls when a physical controller is connected

    /// Hides or shows the on-screen touch controls (both legacy OSD and DeltaSkin
    /// overlays) based on whether a real physical controller is connected.
    ///
    /// Gated by the `hideOnScreenControlsWithController` user preference.
    /// No-ops on tvOS and macCatalyst where on-screen touch controls are not used.
    func updateOnScreenControlsVisibility() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        setOnScreenControlsHidden(controllerHidesOnScreenControls)
        #endif
    }

    /// Auto-hide is on and a real gamepad is connected (snapshots, which include the
    /// keyboard-backed controller, don't count). Layout passes use the same rule.
    var controllerHidesOnScreenControls: Bool {
        guard Defaults[.hideOnScreenControlsWithController] else { return false }
        return PVControllerManager.shared.controllers.contains { controller in
            Self.isGameplayController(controller)
        }
    }

    /// Resolve synthesized profiles to their hardware identity. A disconnect notification carries
    /// the original controller even when the manager exposes its synthesized Nintendo profile.
    private static func isGameplayController(_ controller: GCController) -> Bool {
        let physical = (controller as? PVPhysicalProfileController)?.base ?? controller
        return !physical.isSnapshot && !physical.isRemote
            && (physical.extendedGamepad != nil || physical.microGamepad != nil
                || PVPhysicalProfileController.isNeeded(for: physical))
    }

    /// Shows or hides the on-screen controls (the skin layer, which also hosts the touch overlay).
    ///
    /// - Parameter hidden: `true` to hide on-screen controls, `false` to show them.
    private func setOnScreenControlsHidden(_ hidden: Bool) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if isDeltaSkinEnabled {
            skinContainerView?.isHidden = hidden
            DLOG("On-screen controls (DeltaSkin): \(hidden ? "hidden" : "visible")")
            hideOrShowMenuButton()
        }
        #endif
    }

    /// A remap changed: hand the controllers to the core again so a native core picks
    /// up (or drops) its `PVRemappedController`. The store may post off the main thread.
    @objc nonisolated func handleControllerMappingsChanged(_ note: Notification?) {
        Task { @MainActor [weak self] in
            self?.handleControllerManagerControllerReassigned(nil)
        }
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
        updateOnScreenControlsVisibility()
        #if os(tvOS) && canImport(SteamController)
        PVControllerManager.shared.setSteamControllersMode(core.isRunning ? .gameController : .keyboardAndMouse)
        #endif
        #if os(tvOS)
        setupSiriRemoteForKeyboardCore()
        setupSiriRemoteForLightGunCore()
        #endif
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
