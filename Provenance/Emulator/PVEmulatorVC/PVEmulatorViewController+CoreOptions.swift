//
//  PVEmulatorViewController+CoreOptions.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

extension PVEmulatorViewController {
    func showCoreOptions() {
        let coreClass = type(of: core) as! CoreOptional.Type
        coreClass.className = core.coreIdentifier ?? ""
        coreClass.systemName = core.systemIdentifier ?? ""
        let optionsVC = CoreOptionsViewController(withCore: coreClass)
        optionsVC.title = "Core Options"
        let nav = UINavigationController(rootViewController: optionsVC)
        #if os(iOS)
            optionsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissNav))
            // disable iOS 13 swipe to dismiss...
            nav.isModalInPresentation = true
            present(nav, animated: true, completion: nil)
        #else
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissNav))
            tap.allowedPressTypes = [.menu]
            optionsVC.view.addGestureRecognizer(tap)
            present(TVFullscreenController(rootViewController: nav), animated: true, completion: nil)
        #endif
    }
}
