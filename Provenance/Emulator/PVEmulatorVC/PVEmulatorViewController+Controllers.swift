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

    @objc func controllerDidConnect(_ note: Notification?) {
        let controller = note?.object as? GCController
        // 8Bitdo controllers don't have a pause button, so don't hide the menu
        if !(controller is PViCade8BitdoController || controller is PViCade8BitdoZeroController) {
            menuButton?.isHidden = true
            // In instances where the controller is connected *after* the VC has been shown, we need to set the pause handler
            controller?.setupPauseHandler(onPause: controllerPauseButtonPressed)
            #if os(iOS)
                setNeedsUpdateOfHomeIndicatorAutoHidden()
            #endif
        }
    }

    @objc func controllerDidDisconnect(_: Notification?) {
        menuButton?.isHidden = false
        #if os(iOS)
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        #endif
    }

    @objc func handleControllerManagerControllerReassigned(_: Notification?) {
        core.controller1 = PVControllerManager.shared.player1
        core.controller2 = PVControllerManager.shared.player2
        core.controller3 = PVControllerManager.shared.player3
        core.controller4 = PVControllerManager.shared.player4
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
            glViewController.view?.removeFromSuperview()
            glViewController.removeFromParent()
            secondaryWindow?.rootViewController = glViewController
            glViewController.view?.frame = secondaryWindow?.bounds ?? .zero
            if let aView = glViewController.view {
                secondaryWindow?.addSubview(aView)
            }
            secondaryWindow?.isHidden = false
            glViewController.view?.setNeedsLayout()
        }
    }

    @objc func screenDidDisconnect(_ note: Notification?) {
        ILOG("Screen did disconnect: \(note?.object ?? "")")
        let screen = note?.object as? UIScreen
        if secondaryScreen == screen {
            glViewController.view?.removeFromSuperview()
            glViewController.removeFromParent()
            addChild(glViewController)

            if let aView = glViewController.view, let aView1 = controllerViewController?.view {
                view.insertSubview(aView, belowSubview: aView1)
            }

            glViewController.view?.setNeedsLayout()
            secondaryWindow = nil
            secondaryScreen = nil
        }
    }
}
