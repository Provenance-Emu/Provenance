//
//  UIWindowExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 5/2/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

import UIKit

public extension NSNotification.Name {
    
    public static let SwiftyAppearanceWillRefreshWindow = NSNotification.Name(rawValue: "SwiftyAppearanceWillRefreshWindowNotification")
 
    public static let SwiftyAppearanceDidRefreshWindow = NSNotification.Name(rawValue: "SwiftyAppearanceDidRefreshWindowNotification")
}

public extension UIWindow {
    
    @nonobjc private func _refreshAppearance() {
        let constraints = self.constraints
        removeConstraints(constraints)
        for subview in subviews {
            subview.removeFromSuperview()
            addSubview(subview)
        }
        addConstraints(constraints)
    }

    /// Refreshes appearance for the window
    ///
    /// - Parameter animated: if the refresh should be animated
    public func refreshAppearance(animated: Bool) {
        NotificationCenter.default.post(name: .SwiftyAppearanceWillRefreshWindow, object: self)
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self._refreshAppearance()
        }, completion: { _ in
            NotificationCenter.default.post(name: .SwiftyAppearanceDidRefreshWindow, object: self)
        })
    }
}
