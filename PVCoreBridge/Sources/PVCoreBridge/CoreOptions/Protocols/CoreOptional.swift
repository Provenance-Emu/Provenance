//
//  CoreOptional.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVPrimitives


public protocol CoreOptional {//where Self: EmulatorCoreIOInterface {
    /// The options available for this core
    static var options: [CoreOption] { get }

    /// The MD5 hash of the currently loaded game.
    /// When non-nil, `valueForOption` reads the per-game key
    /// (`<ClassName>.<md5>.<optionKey>`) before falling back to the
    /// per-core global key (`<ClassName>.<optionKey>`).
    /// Set this when a game is loaded and clear it on unload.
    static var currentGameMD5: String? { get }

    /// The set of aspect ratio overrides this core supports.
    ///
    /// Cores that support widescreen hacks, aspect ratio selection, or other
    /// display geometry modifications should return the relevant cases here.
    /// The UI uses this list to show only the options the core actually supports.
    ///
    /// The default implementation returns `[.auto]` (no overrides available).
    static var supportedAspectRatioOverrides: [AspectRatioOverride] { get }

    /// The aspect ratio override currently selected for this core.
    ///
    /// The renderer reads this property when compositing the frame. Returning
    /// `.auto` (the default) means the core's native reported aspect ratio is used.
    ///
    /// Cores that store this preference in their own `CoreOption` key should
    /// override this property to read from `UserDefaults` via `string(forOption:)`.
    static var preferredAspectRatioOverride: AspectRatioOverride { get }

//    static func bool(forOption option: String) -> Bool
//    static func int(forOption option: String) -> Int
//    static func float(forOption option: String) -> Float
//    static func string(forOption option: String) -> String?
}

public protocol SubCoreOptional: CoreOptional {
//    associatedtype Parent: CoreOptional
    /// Get options for a specific subcore
    /// - Parameters:
    ///   - forSubcoreIdentifier: The identifier of the subcore
    ///   - systemName: The name of the system
    /// - Returns: The options for the subcore, or nil if none are available
    static func options(forSubcoreIdentifier: String, systemName: String) -> [CoreOption]?
}

public extension CoreOptional {
    /// Default implementation: no per-game MD5 override.
    static var currentGameMD5: String? { nil }

    /// Default: only `.auto` is available (no override supported).
    static var supportedAspectRatioOverrides: [AspectRatioOverride] { [.auto] }

    /// Default: use the core's natural aspect ratio.
    static var preferredAspectRatioOverride: AspectRatioOverride { .auto }

    /// Reset a specific set of options to their default values
    /// - Parameter options: The options to reset
    static func resetOptions(_ options: [CoreOption]) {
        options.forEach { option in
            if let defaultValue = option.defaultValue {
                setValue(defaultValue, forOption: option)
            }

            // If it's a group, recursively reset all sub-options
            if case let .group(_, subOptions) = option {
                resetOptions(subOptions)
            }
        }
    }

    /// Reset all options for this core to their default values (core-global scope only).
    ///
    /// This only writes to `<ClassName>.<key>` keys.  Per-game override keys
    /// (`<ClassName>.<md5>.<key>`) are **not** modified — use `resetAllOptions(forMD5:)`
    /// to clear per-game overrides for a specific game.
    static func resetAllOptions() {
        resetOptions(options)
    }
}

// public extension CoreOptional {
//    static func bool(forOption option: String) -> Bool {
//        return valueForOption(Bool.self, option) ?? false
//    }
//
//    static func int(forOption option: String) -> Int {
//        let value = valueForOption(Int.self, option)
//        return value ?? 0
//    }
//
//    static func float(forOption option: String) -> Float {
//        let value = valueForOption(Float.self, option)
//        return value ?? 0
//    }
//
//    static func string(forOption option: String) -> String? {
//        let value = valueForOption(String.self, option)
//        return value
//    }
// }
