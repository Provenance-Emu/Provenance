//
//  UIApplicationExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 5/2/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
public typealias UIApplication = NSApplication
#endif

import Foundation

public extension NSNotification.Name {
    static let SwiftyAppearanceWillRefreshApplication = NSNotification.Name(rawValue: "SwiftyAppearanceWillRefreshApplicationNotification")

    static let SwiftyAppearanceDidRefreshApplication = NSNotification.Name(rawValue: "SwiftyAppearanceDidRefreshApplicationNotification")
}

public extension UIApplication {
    @nonobjc private func _refreshAppearance(animated: Bool) {
        for window in windows {
            window.refreshAppearance(animated: animated)
        }
    }

    /// Refreshes appearance for all windows in the application
    ///
    /// - Parameter animated: if the refresh should be animated
    func refreshAppearance(animated: Bool) {
#if canImport(UIKit)
        NotificationCenter.default.post(name: .SwiftyAppearanceWillRefreshApplication, object: self)
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self._refreshAppearance(animated: animated)
        }, completion: { _ in
            NotificationCenter.default.post(name: .SwiftyAppearanceDidRefreshApplication, object: self)
        })
        #else
        NotificationCenter.default.post(name: .SwiftyAppearanceWillRefreshApplication, object: self)
        self._refreshAppearance(animated: animated)
        NotificationCenter.default.post(name: .SwiftyAppearanceDidRefreshApplication, object: self)
        #endif
    }
}
