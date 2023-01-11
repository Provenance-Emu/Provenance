//
//  Identifiable.swift
//  
//
//  Created by Joseph Mattiello on 1/10/23.
//

import Foundation

public protocol Identifiable {
    var identifier: String { get }
}

public extension Equatable where Self: Identifiable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
