// MARK: - Controllers

extension PVEmulatorViewController {
    func controllerPauseButtonPressed() {
        DispatchQueue.main.async(execute: { () -> Void in
            if !self.isShowingMenu {
                self.showMenu(self)
            } else {
                self.hideMenu()
            }
        })
    }

    func hideOrShowMenuButton() {

        // find out how many *real* controllers we have....
        let controllers = PVControllerManager.shared.controllers().filter { controller in
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

        // and hide menu button if we have zero
        menuButton?.isHidden = controllers.count != 0

        #if os(iOS)
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        #endif
    }

    @objc func controllerDidConnect(_ note: Notification?) {

        // In instances where the controller is connected *after* the VC has been shown, we need to set the pause handler
        let controller = note?.object as? GCController
        controller?.setupPauseHandler(onPause: controllerPauseButtonPressed)

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
        hideOrShowMenuButton()
        #if os(tvOS)
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
    }
}
