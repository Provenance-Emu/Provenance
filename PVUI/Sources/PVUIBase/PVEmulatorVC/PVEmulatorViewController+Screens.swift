//
//  File.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import Foundation
import UIKit

/// Second screen or AirPlay support
public extension PVEmulatorViewController {

    func setupScreenNotifications() {
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(screenDidConnect),
                                             name: UIScreen.didConnectNotification,
                                             object: nil)
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(screenDidDisconnect),
                                             name: UIScreen.didDisconnectNotification,
                                             object: nil)

        // Check for existing external screen
        if let screen = UIScreen.screens.first(where: { $0 != .main }) {
            screenDidConnect(Notification(name: UIScreen.didConnectNotification, object: screen))
        }
    }

    @objc func screenDidConnect(_ note: Notification?) {
        ILOG("Screen did connect: \(note?.object ?? "")")
        if secondaryScreen == nil {
            secondaryScreen = UIScreen.screens.first(where: { $0 != .main })
            guard let screen = secondaryScreen else { return }

            // Create and configure secondary window
            secondaryWindow = UIWindow(frame: screen.bounds)
            secondaryWindow?.screen = screen

            // Move game view to secondary screen
            gpuViewController.view?.removeFromSuperview()
            gpuViewController.removeFromParent()
            secondaryWindow?.rootViewController = gpuViewController
            gpuViewController.view?.frame = secondaryWindow?.bounds ?? .zero

            secondaryWindow?.makeKeyAndVisible()
            gpuViewController.view?.setNeedsLayout()

            // Ensure controls stay on main screen
            if let controlsView = controllerViewController?.view {
                view.bringSubviewToFront(controlsView)
            }
        }
    }

    @objc func screenDidDisconnect(_ note: Notification?) {
        ILOG("Screen did disconnect: \(note?.object ?? "")")
        let screen = note?.object as? UIScreen
        if secondaryScreen == screen {
            // Move game view back to main screen
            gpuViewController.view?.removeFromSuperview()
            gpuViewController.removeFromParent()
            addChild(gpuViewController)

            if let gameView = gpuViewController.view,
               let controlsView = controllerViewController?.view {
                view.insertSubview(gameView, belowSubview: controlsView)
                gameView.frame = view.bounds
            }

            gpuViewController.view?.setNeedsLayout()
            secondaryWindow = nil
            secondaryScreen = nil
        }
    }
}
