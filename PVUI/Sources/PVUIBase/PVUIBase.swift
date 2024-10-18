//
//  PVUIBase.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

#if os(macOS)
@_exported import AppKit
@_exported import PVUI_AppKit
#elseif os(tvOS)
@_exported import UIKit
@_exported import PVUI_TV
#elseif os(iOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
@_exported import UIKit
@_exported import PVUI_IOS
#else
#error("Unsupported platform")
#endif

import Foundation

public let PVUIVersion = "1.0.0"

public class BundleLoader {
    public static let myBundle: Bundle = Bundle.module
    public static let module: Bundle = bundle
#if os(macOS)
    public static let bundle: Bundle = PVUI_AppKit.BundleLoader.bundle
#elseif os(tvOS)
    public static let bundle: Bundle = PVUI_TV.BundleLoader.bundle
#elseif os(iOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
    public static let bundle: Bundle = PVUI_IOS.BundleLoader.bundle
#else
#error("Unsupported platform")
#endif
}
