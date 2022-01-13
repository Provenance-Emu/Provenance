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
        let nav = self.navigationController ?? UINavigationController(rootViewController: optionsVC)
        optionsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissNav))
        present(nav, animated: true, completion: nil)
    }
}
