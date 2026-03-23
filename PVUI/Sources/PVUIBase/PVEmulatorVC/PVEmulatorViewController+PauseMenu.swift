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

        // If something is already presented, don't permanently wedge the pause menu.
        // This can happen if we're racing a prior dismissal or another modal flow.
        if let presented = presentedViewController {
            if presented === menuPresentationViewController {
                DLOG("Pause menu already presented, ignoring duplicate request")
                return
            }
            if presented.isBeingDismissed || presented.isBeingPresented {
                DLOG("Presented VC is in transition (\(type(of: presented))); retrying showMenu shortly")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.showMenu(sender)
                }
                return
            }
            DLOG("Dismissing existing presented VC (\(type(of: presented))) to show pause menu")
            presented.dismiss(animated: false) { [weak self] in
                self?.showMenu(sender)
            }
            return
        }

        // Pause the game and prepare for menu
        enableControllerInput(true)
        // Setting isShowingMenu will handle pausing the emulation
        isShowingMenu = true

        // Temporarily hide indicator overlay to avoid interaction conflicts
        temporarilyHideIndicatorOverlay()

        // Create a hosting view controller for our custom menu
        let menuVC = UIViewController()
        menuVC.modalPresentationStyle = .overFullScreen
        menuVC.view.backgroundColor = .clear
        menuPresentationViewController = menuVC

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

        // Add the SwiftUI hosting controller as a proper child VC so SwiftUI .sheet()
        // and other presentation APIs work correctly from within the tile menu.
        // Without addChild, the hosting controller has no parent VC and UIKit cannot
        // find a valid presenter — causing any sheet tap to freeze the app.
        if let hostingVC = menuOverlay.hostingController {
            menuVC.addChild(hostingVC)
            hostingVC.didMove(toParent: menuVC)
        }

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
            #if os(tvOS)
            resetTVOSMenuGestures()
            #endif

            // Reset controller state
            #if !os(tvOS)
            PVControllerManager.shared.controllerUserInteractionEnabled = false
            #endif

            // For RetroArch cores with skipLayout and no skins, ensure GPU view stays hidden
            // RetroArch's CocoaView manages its own rendering and should be on top
            if core.coreIdentifier?.contains("libretro") == true,
               core.skipLayout,
               currentSkin == nil {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Ensure GPU view is hidden and sent to back so CocoaView is visible
                    self.gpuViewController.view.isHidden = true
                    self.view.sendSubviewToBack(self.gpuViewController.view)
                    ILOG("[RA] Ensured GPU view is hidden after menu dismissal - CocoaView should be visible")
                }
            }

            // Setting isShowingMenu to false will handle resuming the emulation
            isShowingMenu = false

            // Restore indicator overlay visibility
            restoreIndicatorOverlay()
        }
        menuPresentationViewController = nil
    }
}
