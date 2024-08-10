import Foundation

#if canImport(UIKit)

import UIKit

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
