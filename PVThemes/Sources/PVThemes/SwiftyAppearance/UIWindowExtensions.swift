//
//  UIWindowExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 5/2/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
public typealias UIWindow = NSWindow
public typealias UIView = NSView
#endif
import Foundation

public extension NSNotification.Name {
    static let SwiftyAppearanceWillRefreshWindow = NSNotification.Name(rawValue: "SwiftyAppearanceWillRefreshWindowNotification")

    static let SwiftyAppearanceDidRefreshWindow = NSNotification.Name(rawValue: "SwiftyAppearanceDidRefreshWindowNotification")
}

public extension UIWindow {
    @nonobjc private func _refreshAppearance() {
        #if canImport(UIKit)
        let constraints = self.constraints
        removeConstraints(constraints)
        for subview in subviews {
            subview.removeFromSuperview()
            addSubview(subview)
        }
        addConstraints(constraints)
        #else
        guard let contentView = self.contentView  else { return }
        let constraints = contentView.constraints
        contentView.removeConstraints(constraints)
        for subview in contentView.subviews {
            subview.removeFromSuperview()
            contentView.addSubview(subview)
        }
        contentView.addConstraints(constraints)
        #endif

    }

    /// Refreshes appearance for the window
    ///
    /// - Parameter animated: if the refresh should be animated
    func refreshAppearance(animated: Bool) {
#if canImport(UIKit)
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self._refreshAppearance()
        }, completion: { _ in
            NotificationCenter.default.post(name: .SwiftyAppearanceDidRefreshWindow, object: self)
        })
#else
        NotificationCenter.default.post(name: .SwiftyAppearanceWillRefreshWindow, object: self)
        self._refreshAppearance()
        NotificationCenter.default.post(name: .SwiftyAppearanceDidRefreshWindow, object: self)
#endif
    }
}
