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

        // Create the SwiftUI view
        let coreOptionsView = CoreOptionsDetailView(
            coreClass: coreClass,
            title: "Core Options"
        )

        // Create a hosting controller
        let hostingController = UIHostingController(rootView: coreOptionsView)
        let nav = UINavigationController(rootViewController: hostingController)

        // Add done button for iOS
        #if os(iOS)
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissNav)
        )
        // disable iOS 13 swipe to dismiss...
        nav.isModalInPresentation = true
        present(nav, animated: true)
        #else
        // Add menu button gesture for tvOS
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissNav))
        tap.allowedPressTypes = [.menu]
        hostingController.view.addGestureRecognizer(tap)
        present(TVFullscreenController(rootViewController: nav), animated: true)
        #endif
    }
}
