//
//  PVEmulatorViewController+CoreOptions.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import SwiftUI

extension PVEmulatorViewController {
    public func showCoreOptions() {
        guard let coreClass = type(of: core) as? CoreOptional.Type else { return }

        /// Enable controller-driven UI navigation so the d-pad and buttons
        /// can navigate the options list via UIKit's focus system.
        enableControllerInput(true)

        let coreOptionsView = CoreOptionsDetailView(
            coreClass: coreClass,
            title: "Core Options",
            gameMD5: game.md5Hash.isEmpty ? nil : game.md5Hash,
            onClose: { [weak self] in self?.dismissCoreOptions() }
        )

        let hostingController = UIHostingController(rootView: coreOptionsView)
        let nav = UINavigationController(rootViewController: hostingController)

        #if os(iOS)
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissCoreOptions)
        )
        nav.isModalInPresentation = true
        present(nav, animated: true)
        #else
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissCoreOptions))
        tap.allowedPressTypes = [.menu]
        hostingController.view.addGestureRecognizer(tap)
        present(TVFullscreenController(rootViewController: nav), animated: true)
        #endif
    }

    /// Triggers the given ``CoreAction`` on the active core.
    ///
    /// Called from ``PauseTileMenuView`` after the menu has been dismissed.
    /// The caller is responsible for resuming emulation via `dismissAction(true)` /
    /// `dismissNav(resumeEmulation: true)` **before** invoking this method — that
    /// ensures `dismissNav`'s completion handler runs `setPauseEmulation(false)`,
    /// which is the single source of truth for the post-action emulation state.
    ///
    /// This method only forwards the action to the core and, when `requiresReset`
    /// is true, triggers a reset.
    public func handleCoreAction(_ action: CoreAction) {
        guard let coreWithActions = core as? CoreActions else { return }
        coreWithActions.selected(action: action)
        if action.requiresReset {
            core.resetEmulation()
        }
    }

    /// Dismisses core options and returns to the pause menu it was opened from.
    ///
    /// The game is still paused at this point (the pause menu handed off to
    /// this screen without resuming). Closing straight back to the game used
    /// to leave it frozen with nothing on screen until the user opened and
    /// closed the pause menu again; going back to the menu also lets them
    /// resume, or carry on changing things, from where they were.
    @objc func dismissCoreOptions() {
        guard let presented = presentedViewController, !presented.isBeingDismissed else { return }
        presented.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.enableControllerInput(false)
            #if os(tvOS)
            self.resetTVOSMenuGestures()
            self.reestablishPauseHandlers()
            self.view.becomeFirstResponder()
            #endif
            if self.core.isOn {
                self.showMenu(nil)
            }
        }
    }
}
