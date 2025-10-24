// MARK: - Controllers
import PVLogging
import GameController
import PVSupport
import PVSettings
#if canImport(SteamController)
import SteamController
#endif

extension PVEmulatorViewController {
    @objc func handlePause(_ note: Notification?) {
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
