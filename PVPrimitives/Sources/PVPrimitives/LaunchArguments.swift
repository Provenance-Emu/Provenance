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
}
