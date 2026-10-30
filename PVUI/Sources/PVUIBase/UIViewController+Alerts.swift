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

/// Message helpers for UIKit callers. They show a `PVAlert` through `PVAlertCenter`.
public extension UIViewController {

    /// `source` is unused: alerts are centered dialogs, never popovers. Kept so call sites read the same.
    func presentMessage(_ message: String,
                        title: String,
                        source: UIView? = nil,
                        secondaryActionTitle: String? = nil,
                        secondaryActionStyle: UIAlertAction.Style = .cancel,
                        secondaryCompletion: (() -> Void)? = nil,
                        defaultActionTitle: String? = nil,
                        defaultActionStyle: UIAlertAction.Style = .default,
                        completion: (() -> Void)? = nil) {
        DLOG("Title: \(title) Message: \(message)")
        var actions = [
            PVAlertAction(defaultActionTitle ?? Bundle.module.localized("OK"),
                          role: PVAlertAction.Role(defaultActionStyle),
                          handler: completion)
        ]
        if let secondaryActionTitle {
            actions.append(PVAlertAction(secondaryActionTitle,
                                         role: PVAlertAction.Role(secondaryActionStyle),
                                         handler: secondaryCompletion))
        }
        present(PVAlert(title: title, message: message, actions: actions))
    }

    func presentError(_ message: String, source: UIView? = nil, completion: (() -> Void)? = nil) {
        ELOG("\(message)")
        present(PVAlert(title: Bundle.module.localized("Error"), message: message, type: .error,
                        actions: [.ok(completion)]))
    }

    func presentWarning(_ message: String, source: UIView? = nil, completion: (() -> Void)? = nil) {
        WLOG("\(message)")
        present(PVAlert(title: Bundle.module.localized("Warning"), message: message, type: .warning,
                        actions: [.ok(completion)]))
    }
}

public extension PVAlertAction.Role {
    init(_ style: UIAlertAction.Style) {
        switch style {
        case .cancel: self = .cancel
        case .destructive: self = .destructive
        default: self = .default
        }
    }
}
