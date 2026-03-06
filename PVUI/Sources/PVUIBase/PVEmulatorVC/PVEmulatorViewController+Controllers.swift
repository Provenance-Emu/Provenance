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

        // In instances where the controller is connected *after* the VC has been shown, we need to set the pause handler
        // pause handler moved to controller (Notification PauseGame)
        hideOrShowMenuButton()
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
        #endif
    }

    // MARK: - UIScreenNotifications

    @objc func screenDidConnect(_ note: Notification?) {
        ILOG("Screen did connect: \(note?.object ?? "")")
        if secondaryScreen == nil {
            secondaryScreen = UIScreen.screens[1]
            if let aBounds = secondaryScreen?.bounds {
                secondaryWindow = UIWindow(frame: aBounds)
            }
            if let aScreen = secondaryScreen {
                secondaryWindow?.screen = aScreen
            }
            gpuViewController.view?.removeFromSuperview()
            gpuViewController.removeFromParent()
            secondaryWindow?.rootViewController = gpuViewController
            gpuViewController.view?.frame = secondaryWindow?.bounds ?? .zero
            if let aView = gpuViewController.view {
                secondaryWindow?.addSubview(aView)
            }
            secondaryWindow?.isHidden = false
            gpuViewController.view?.setNeedsLayout()
        }
        hideOrShowMenuButton()
    }

    @objc func screenDidDisconnect(_ note: Notification?) {
        ILOG("Screen did disconnect: \(note?.object ?? "")")
        let screen = note?.object as? UIScreen
        if secondaryScreen == screen {
            gpuViewController.view?.removeFromSuperview()
            gpuViewController.removeFromParent()
            addChild(gpuViewController)

            if let aView = gpuViewController.view, let aView1 = controllerViewController?.view {
                view.insertSubview(aView, belowSubview: aView1)
            }

            gpuViewController.view?.setNeedsLayout()
            secondaryWindow = nil
            secondaryScreen = nil
        }
        hideOrShowMenuButton()
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

    /// Installs value-changed handlers on the Siri Remote (GCMicroGamepad) for
    /// cores that implement KeyboardResponder / MouseResponder.
    func setupSiriRemoteForKeyboardCore() {
        guard let microGamepad = GCController.controllers().first(where: { $0.microGamepad != nil })?.microGamepad else {
            return
        }

        let keyboardCore = core as? KeyboardResponder
        let mouseCore = core as? MouseResponder

        guard keyboardCore != nil || mouseCore != nil else { return }
        guard keyboardCore?.gameSupportsKeyboard == true || mouseCore?.gameSupportsMouse == true else { return }

        ILOG("tvOS: Installing Siri Remote handlers for keyboard/mouse core")

        if let kbCore = keyboardCore, kbCore.gameSupportsKeyboard {
            installDpadKeyboardHandler(on: microGamepad, core: kbCore)
        }

        if let msCore = mouseCore, msCore.gameSupportsMouse {
            installTouchSurfaceMouseHandler()
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

/// Simple generic box so we can store value types in associated-object storage.
private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
#endif
