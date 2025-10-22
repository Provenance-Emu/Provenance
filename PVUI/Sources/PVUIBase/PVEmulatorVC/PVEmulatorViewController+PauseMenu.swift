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
    @MainActor
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
        // Setting isShowingMenu will handle pausing the emulation
        isShowingMenu = true
        
        // Create a hosting view controller for our custom menu
        let menuVC = UIViewController()
        menuVC.modalPresentationStyle = .overFullScreen
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
        present(menuVC, animated: true) { [weak self, weak menuVC] in
            DLOG("Presented custom game menu overlay")
            // Some presentation controllers are created during presentation; set the delegate again to be safe
            if let pc = menuVC?.presentationController, let self = self {
                pc.delegate = self
            }
        }
    }
    
    // MARK: - UIAdaptivePresentationControllerDelegate

    /// Also handle the willDismiss phase to ensure we resume even if DidDismiss isn't called in some cases
    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        DLOG("Menu will dismiss")
        cleanupAfterMenuDismissal()
    }

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
            
            // Reset controller state
            #if !os(tvOS)
            PVControllerManager.shared.controllerUserInteractionEnabled = false
            #endif
            // Setting isShowingMenu to false will handle resuming the emulation
            isShowingMenu = false
        }
    }
}
