//
//  PVEmulatorViewController+CoreOptions.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

extension PVEmulatorViewController {
    func showCoreOptions() {
        let optionsVC = CoreOptionsViewController(withCore: type(of: core) as! CoreOptional.Type)
        optionsVC.title = "Core Options"
        let nav = self.navigationController ?? UINavigationController(rootViewController: optionsVC)
        #if os(iOS)
            optionsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissNav))
        #else
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissNav))
            tap.allowedPressTypes = [.menu]
            optionsVC.view.addGestureRecognizer(tap)
            nav.navigationBar.isTranslucent = false
            nav.navigationBar.backgroundColor =  UIColor.black.withAlphaComponent(0.8)
        #endif
        // disable iOS 13 swipe to dismiss...
        if #available(iOS 13.0, tvOS 13.0, *) {
            nav.isModalInPresentation = true
        }
        present(nav, animated: true, completion: nil)
    }
}
