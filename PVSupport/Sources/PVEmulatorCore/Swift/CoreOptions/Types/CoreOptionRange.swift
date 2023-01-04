//
//  CoreOptionRange.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct CoreOptionRange<T:Numeric> {
    public let defaultValue: T
    public let min: T
    public let max: T

    public init(defaultValue: T, min: T, max: T) {
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
    }
}

extension CoreOptionRange: Codable where T:Codable {}
extension CoreOptionRange: Equatable where T:Equatable {}
extension CoreOptionRange: Hashable where T:Hashable {}

// public protocol Rangable {
//    var defaultValue : Codable {get}
//    var min : Codable {get}
//    var max : Codable {get}
// }
//
// public struct CoreOptionRange<T:Codable> : Rangable {
//    public let defaultValue : T
//    public let min : T
//    public let max : T
// }
