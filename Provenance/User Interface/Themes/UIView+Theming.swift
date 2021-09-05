//
//  UIViewExtensions.swift
//  Provenance
//
//  Created by Sev Gerk on 3/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

public extension UIView {
    @IBInspectable var ignoresInvertColors: Bool {
        get {
            return accessibilityIgnoresInvertColors
        }
        set {
            accessibilityIgnoresInvertColors = newValue
        }
    }
}
