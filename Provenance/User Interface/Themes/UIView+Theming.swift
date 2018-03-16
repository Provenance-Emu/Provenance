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
			if #available(iOS 11.0, *) {
				return accessibilityIgnoresInvertColors
			}
			return false
		}
		set {
			if #available(iOS 11.0, *) {
				accessibilityIgnoresInvertColors = newValue
			}
		}
	}
}
