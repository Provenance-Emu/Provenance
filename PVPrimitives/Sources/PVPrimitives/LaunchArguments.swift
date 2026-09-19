//
//  LaunchArguments.swift
//  PVPrimitives
//
//  Created for Provenance Emulator
//

import Foundation

/// Launch arguments for debugging and testing.
/// Set these in Xcode Scheme: Edit Scheme > Run > Arguments > Arguments Passed On Launch
public enum LaunchArgument: String, CaseIterable {
    /// Forces the empty library state in tvOS Media UI for testing onboarding UX
    case forceEmptyLibrary = "-forceEmptyLibrary"
    
    /// Disables CloudKit sync on launch
    case disableCloudKit = "-disableCloudKit"
    
    /// Enables verbose logging
    case verboseLogging = "-verboseLogging"
    
    /// Skips the bootup/splash screen
    case skipBootup = "-skipBootup"
    
    /// Resets all user defaults on launch
    case resetDefaults = "-resetDefaults"
    
    /// Forces offline mode (no network requests)
    case forceOffline = "-forceOffline"

    /// Populates the library with mock games when empty (simulator/UITesting)
    case useMockLibrary = "-useMockLibrary"

    /// App Store screenshot capture mode (UITesting / fastlane snapshot).
    /// Implies `useMockLibrary`, skips splash hold and background importer work.
    case screenshotMode = "-SCREENSHOT_MODE"

    /// Deep link to open once the app has finished booting, e.g.
    /// `-deepLink provenance://screen/settings/video`. Read via `LaunchArgument.deepLinkURL`.
    case deepLink = "-deepLink"
    
    /// The raw argument string including the dash prefix
    public var argument: String { rawValue }
    
    /// Check if this launch argument is currently active
    public var isEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(rawValue)
        #else
        return false
        #endif
    }
    
    /// Check if any of the provided launch arguments are enabled
    public static func isAnyEnabled(_ arguments: LaunchArgument...) -> Bool {
        arguments.contains { $0.isEnabled }
    }
    
    /// Returns all currently enabled launch arguments
    public static var enabledArguments: [LaunchArgument] {
        allCases.filter { $0.isEnabled }
    }

    /// The argument immediately following this flag, if present (e.g. `-deepLink <url>`).
    public var value: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: rawValue), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
        #else
        return nil
        #endif
    }

    /// URL passed via `-deepLink <url>`, if any.
    public static var deepLinkURL: URL? {
        guard let raw = LaunchArgument.deepLink.value else { return nil }
        return URL(string: raw)
    }
}
