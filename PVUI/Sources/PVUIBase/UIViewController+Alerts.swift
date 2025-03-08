//
//  UIViewController+Alerts.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import PVLogging

public extension UIViewController {
    
    func presentDeleteMessage(_ message: String, title: String, source: UIView, completion: (() -> Void)? = nil) {
        presentMessage(message, title: title,
                       source: source,
                       secondaryActionTitle: Bundle.module.localized("Cancel"),
                       secondaryActionStyle: .cancel,
                       secondaryCompletion: nil,
                       defaultActionTitle: Bundle.module.localized("Delete"),
                       defaultActionStyle: .destructive,
                       completion: completion)
    }
    
    func presentMessage(_ message: String,
                        title: String,
                        source: UIView,
                        secondaryActionTitle: String? = nil,
                        secondaryActionStyle: UIAlertAction.Style = .cancel,
                        secondaryCompletion: (() -> Void)? = nil,
                        defaultActionTitle: String? = nil,
                        defaultActionStyle: UIAlertAction.Style = .default,
                        completion: (() -> Void)? = nil) {
        DLOG("Title: \(title) Message: \(message) secondaryActionTitle: \(secondaryActionTitle) defaultActionTitle: \(defaultActionTitle)")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.preferredContentSize = CGSize(width: 300, height: 300)
        
        alert.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
        alert.popoverPresentationController?.sourceView = source
        alert.popoverPresentationController?.sourceRect = UIScreen.main.bounds
        let actualDefaultActionTitle = defaultActionTitle ?? Bundle.module.localized("OK")
        alert.addAction(UIAlertAction(title: actualDefaultActionTitle, style: defaultActionStyle) { _ in
            completion?()
        })
        if let actualSecondaryActionTitle = secondaryActionTitle {
            alert.addAction(UIAlertAction(title: actualSecondaryActionTitle, style: secondaryActionStyle) { _ in
                secondaryCompletion?()
            })
        }
        
        let presentingVC = presentedViewController ?? self
        
        if presentingVC.isBeingDismissed || presentingVC.isBeingPresented {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                presentingVC.present(alert, animated: true, completion: nil)
            }
        } else {
            presentingVC.present(alert, animated: true, completion: nil)
        }
    }

    func presentError(_ message: String, source: UIView, completion: (() -> Void)? = nil) {
        ELOG("\(message)")
        presentMessage(message, title: Bundle.module.localized("Error"), source: source, completion: completion)
    }

    func presentWarning(_ message: String, source: UIView, completion: (() -> Void)? = nil) {
        WLOG("\(message)")
        presentMessage(message, title: Bundle.module.localized("Warning"), source: source, completion: completion)
    }
}

public extension Bundle {
    func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: self, comment: "")
    }
    
    func localized(_ key: String,  _ arguments: any CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: self, comment: ""), arguments)
    }
}
