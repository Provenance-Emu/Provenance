//
//  CoreOptional.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public protocol CoreOptional where Self: PVEmulatorCore {
    @nonobjc
    static var options: [CoreOption] { get }

//    static func bool(forOption option: String) -> Bool
//    static func int(forOption option: String) -> Int
//    static func float(forOption option: String) -> Float
//    static func string(forOption option: String) -> String?
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
