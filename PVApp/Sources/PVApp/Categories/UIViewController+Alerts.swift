//
//  UIViewController+Alerts.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit
import PVLogging

extension UIViewController {
    func presentMessage(_ message: String, title: String, completion _: (() -> Swift.Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        let presentingVC = presentedViewController ?? self

        if presentingVC.isBeingDismissed || presentingVC.isBeingPresented {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                presentingVC.present(alert, animated: true, completion: nil)
            }
        } else {
            presentingVC.present(alert, animated: true, completion: nil)
        }
    }

    func presentError(_ message: String, completion: (() -> Swift.Void)? = nil) {
        ELOG("\(message)")
        presentMessage(message, title: "Error", completion: completion)
    }

    func presentWarning(_ message: String, completion: (() -> Swift.Void)? = nil) {
        WLOG("\(message)")
        presentMessage(message, title: "Warning", completion: completion)
    }
}
