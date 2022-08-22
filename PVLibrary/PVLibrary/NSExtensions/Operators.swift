//
//  Operators.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    var combined = lhs

    for (k, v) in rhs {
        combined[k] = v
    }

    return combined
}
