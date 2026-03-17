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
            title: "Core Options"
        )

        let hostingController = UIHostingController(rootView: coreOptionsView)
        let nav = UINavigationController(rootViewController: hostingController)

        #if os(iOS)
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissCoreOptionsAndResume)
        )
        nav.isModalInPresentation = true
        present(nav, animated: true)
        #else
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissCoreOptionsAndResume))
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

    /// Dismisses core options.
    /// Emulation pause state is handled by the menu system; we don't resume here
    /// to prevent unpausing when navigating back to the pause menu.
    @objc private func dismissCoreOptionsAndResume() {
        presentedViewController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.enableControllerInput(false)
            #if os(tvOS)
            self.resetTVOSMenuGestures()
            self.reestablishPauseHandlers()
            self.view.becomeFirstResponder()
            #endif
        }
    }
}
