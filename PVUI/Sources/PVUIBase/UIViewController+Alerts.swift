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
#if canImport(GameController)
import GameController
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
        alert.addAction(UIAlertAction(title: actualDefaultActionTitle, style: defaultActionStyle) { [weak self] _ in
            self?.restoreGameControllerFocusHandlingAfterAlert()
            completion?()
        })
        if let actualSecondaryActionTitle = secondaryActionTitle {
            alert.addAction(UIAlertAction(title: actualSecondaryActionTitle, style: secondaryActionStyle) { [weak self] _ in
                self?.restoreGameControllerFocusHandlingAfterAlert()
                secondaryCompletion?()
            })
        }

        let presentingVC = presentedViewController ?? self

        enableGameControllerFocusHandlingForAlert()

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

// MARK: - Game controller focus while an alert is presented

/// On tvOS (and when a game controller is driving input on iOS), alerts presented from the
/// emulator can appear unresponsive because `PVControllerManager` has routed gamepad events
/// to the game instead of UIKit's focus engine. These helpers flip the relevant flags while
/// the alert is on-screen and restore the prior state once the user taps an action.
private final class AlertFocusKeys {
    /// Unique instances whose object identities act as stable associated-object keys.
    static let savedManagerFlag = AlertFocusKeys()
    #if os(tvOS)
    static let savedEventVCFlag = AlertFocusKeys()
    #endif
}

private func alertFocusKey(_ marker: AlertFocusKeys) -> UnsafeRawPointer {
    UnsafeRawPointer(Unmanaged.passUnretained(marker).toOpaque())
}

extension UIViewController {

    fileprivate func enableGameControllerFocusHandlingForAlert() {
        let priorManagerFlag = PVControllerManager.shared.controllerUserInteractionEnabled
        objc_setAssociatedObject(self, alertFocusKey(AlertFocusKeys.savedManagerFlag),
                                 NSNumber(value: priorManagerFlag),
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if !priorManagerFlag {
            PVControllerManager.shared.controllerUserInteractionEnabled = true
        }

        #if os(tvOS)
        if let eventVC = self as? GCEventViewController {
            objc_setAssociatedObject(self, alertFocusKey(AlertFocusKeys.savedEventVCFlag),
                                     NSNumber(value: eventVC.controllerUserInteractionEnabled),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if !eventVC.controllerUserInteractionEnabled {
                eventVC.controllerUserInteractionEnabled = true
            }
        }
        #endif
    }

    fileprivate func restoreGameControllerFocusHandlingAfterAlert() {
        if let saved = objc_getAssociatedObject(self, alertFocusKey(AlertFocusKeys.savedManagerFlag)) as? NSNumber {
            PVControllerManager.shared.controllerUserInteractionEnabled = saved.boolValue
            objc_setAssociatedObject(self, alertFocusKey(AlertFocusKeys.savedManagerFlag), nil,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        #if os(tvOS)
        if let eventVC = self as? GCEventViewController,
           let saved = objc_getAssociatedObject(self, alertFocusKey(AlertFocusKeys.savedEventVCFlag)) as? NSNumber {
            eventVC.controllerUserInteractionEnabled = saved.boolValue
            objc_setAssociatedObject(self, alertFocusKey(AlertFocusKeys.savedEventVCFlag), nil,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        #endif
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
