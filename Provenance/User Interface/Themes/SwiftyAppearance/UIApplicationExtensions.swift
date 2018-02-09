//
//  UIApplicationExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 5/2/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

import UIKit

public extension NSNotification.Name {
    
    /// <#Description#>
    public static let SwiftyAppearanceWillRefresh = NSNotification.Name(rawValue: "SwiftyAppearanceWillRefreshNotification")
    
    /// <#Description#>
    public static let SwiftyAppearanceDidRefresh = NSNotification.Name(rawValue: "SwiftyAppearanceDidRefreshNotification")
}

public extension UIApplication {
    
    @nonobjc private func _refreshAppearance(animated: Bool) {
        for window in windows {
            window.refreshAppearance(animated: animated)
        }
    }

    /// <#Description#>
    ///
    /// - Parameter animated: <#animated description#>
    public func refreshAppearance(animated: Bool) {
        NotificationCenter.default.post(name: .SwiftyAppearanceWillRefresh, object: self)
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self._refreshAppearance(animated: animated)
        }, completion: { _ in
            NotificationCenter.default.post(name: .SwiftyAppearanceDidRefresh, object: self)
        })
    }
}
