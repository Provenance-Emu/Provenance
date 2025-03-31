//
//  PVEmulatorViewController~iOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
#if canImport(UIKit)
import UIKit
#endif
import GameController
import PVEmulatorCore
import PVCoreBridge
import PVSettings
import PVLogging

extension PVEmulatorViewController: UIAdaptivePresentationControllerDelegate {
    @objc public func showMenu(_ sender: AnyObject?) {
        if (!core.isOn) { // TODO: Should we just do this code anyway?
            WLOG("Core isn't on, ignoring showMenu.")
            return;
        }
        
        // Check if a menu is already being presented
        if presentedViewController != nil {
            DLOG("A view controller is already being presented, ignoring duplicate request")
            return
        }
        
        // Pause the game and prepare for menu
        enableControllerInput(true)
        core.setPauseEmulation(true)
        isShowingMenu = true
        
        // Create a hosting view controller for our custom menu
        let menuVC = UIViewController()
        menuVC.modalPresentationStyle = .overCurrentContext
        menuVC.view.backgroundColor = .clear
        
        // Create our custom menu overlay
        let menuOverlay = PVGameMenuOverlay(frame: menuVC.view.bounds, emulatorViewController: self)
        menuVC.view.addSubview(menuOverlay)
        
        // Set up constraints
        menuOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            menuOverlay.topAnchor.constraint(equalTo: menuVC.view.topAnchor),
            menuOverlay.leadingAnchor.constraint(equalTo: menuVC.view.leadingAnchor),
            menuOverlay.trailingAnchor.constraint(equalTo: menuVC.view.trailingAnchor),
            menuOverlay.bottomAnchor.constraint(equalTo: menuVC.view.bottomAnchor)
        ])
        
        // Set the presentation delegate to handle dismissal
        menuVC.presentationController?.delegate = self
        
        // Present the menu view controller
        present(menuVC, animated: true) {
            DLOG("Presented custom game menu overlay")
        }
    }
    
    // MARK: - UIAdaptivePresentationControllerDelegate
    
    /// Handle dismissal when clicking outside the menu
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // This is called when the user dismisses by clicking outside the menu
        DLOG("Menu dismissed by clicking outside")
        
        // Ensure we properly clean up when the menu is dismissed
        cleanupAfterMenuDismissal()
    }
    
    /// Common cleanup code after menu dismissal
    private func cleanupAfterMenuDismissal() {
        if isShowingMenu && !AppState.shared.emulationUIState.isInBackground {
            DLOG("Cleaning up after menu dismissal")
            
            // First disable controller input
            enableControllerInput(false)
            
            // Then update emulation state
            isShowingMenu = false
            core.setPauseEmulation(false)
            
            // Reset controller state
            PVControllerManager.shared.controllerUserInteractionEnabled = false
        }
    }
}
