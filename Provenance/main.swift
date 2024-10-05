import Foundation

#if canImport(UIKit)
import UIKit
import PVUIBase
import PVUIKit
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
#endif // canImport(UIKit)
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(PVApplication.self),
    NSStringFromClass(PVAppDelegate.self)
)
#else
import AppKit
NSApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(PVApplication.self),
    NSStringFromClass(PVAppDelegate.self)
)
#endif
