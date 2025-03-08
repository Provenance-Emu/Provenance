//
//  CoreOptional.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation


public protocol CoreOptional {//where Self: EmulatorCoreIOInterface {
    /// The options available for this core
    static var options: [CoreOption] { get }

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

    /// Reset all options for this core to their default values
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
