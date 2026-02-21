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

    /// Dismisses core options and resumes emulation
    @objc private func dismissCoreOptionsAndResume() {
        presentedViewController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.core.setPauseEmulation(false)
            self.isShowingMenu = false
            self.enableControllerInput(false)
            #if os(tvOS)
            self.resetTVOSMenuGestures()
            self.reestablishPauseHandlers()
            self.view.becomeFirstResponder()
            #endif
        }
    }
}
