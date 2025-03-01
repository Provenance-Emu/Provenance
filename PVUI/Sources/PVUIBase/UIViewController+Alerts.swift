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

public
extension UIViewController {
    func presentMessage(_ message: String, title: String, source: UIView, completion: (() -> Void)? = nil) {
        presentMessage(message,
                       title: title,
                       source: source,
                       completion: completion)
    }
    
    func presentDeleteMessage(_ message: String, title: String, source: UIView, completion: (() -> Void)? = nil) {
        presentMessage(message, title: title,
                       source: source,
                       secondaryActionTitle: NSLocalizedString("Cancel", bundle: Bundle.module, comment: ""),
                       secondaryActionStyle: .cancel,
                       secondaryCompletion: nil,
                       defaultActionTitle: NSLocalizedString("Delete", bundle: Bundle.module, comment: ""),
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
        let actualDefaultActionTitle = defaultActionTitle ?? NSLocalizedString("OK", bundle: Bundle.module, comment: "")
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
        presentMessage(message, title: NSLocalizedString("Error", bundle: Bundle.module, comment: ""), source: source, completion: completion)
    }

    func presentWarning(_ message: String, source: UIView, completion: (() -> Void)? = nil) {
        WLOG("\(message)")
        presentMessage(message, title: NSLocalizedString("Warning", bundle: Bundle.module, comment: ""), source: source, completion: completion)
    }
}
