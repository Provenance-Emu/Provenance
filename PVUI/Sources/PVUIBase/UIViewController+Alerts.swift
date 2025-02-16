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
    func presentMessage(_ message: String, title: String, source: UIView, completion: (() -> Swift.Void)? = nil) {
        presentMessage(message, title: title, addCancel: false, source: source, completion: completion)
    }
    
    func presentCancellableMessage(_ message: String, title: String, source: UIView, completion: (() -> Swift.Void)? = nil) {
        presentMessage(message, title: title, addCancel: true, source: source, completion: completion)
    }
    
    func presentMessage(_ message: String, title: String, addCancel: Bool, source: UIView, completion: (() -> Swift.Void)? = nil) {
        NSLog("Title: %@ Message: %@", title, message);
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.preferredContentSize = CGSize(width: 300, height: 300)
        
        alert.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
        alert.popoverPresentationController?.sourceView = source
        alert.popoverPresentationController?.sourceRect = UIScreen.main.bounds
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        if addCancel {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
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

    func presentError(_ message: String, source: UIView, completion: (() -> Swift.Void)? = nil) {
        ELOG("\(message)")
        presentMessage(message, title: "Error", source: source, completion: completion)
    }

    func presentWarning(_ message: String, source: UIView, completion: (() -> Swift.Void)? = nil) {
        WLOG("\(message)")
        presentMessage(message, title: "Warning", source: source, completion: completion)
    }
}
