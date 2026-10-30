//
//  PVUI_IOS.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import Foundation

public let PVUI_IOSVersion = "1.0.0"

public class BundleLoader {
    /// PVUI_IOS has no resources of its own any more; this is the code bundle that holds it.
    public static let bundle = Bundle(for: BundleLoader.self)
}
