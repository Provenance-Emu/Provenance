//
//  i.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 11/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import Foundation
import Differentiator
import RxDataSources

struct i {
    let identity: Int
    let value: String

    init(_ identity: Int, _ value: String) {
        self.identity = identity
        self.value = value
    }
}

extension i: IdentifiableType, Equatable {
}

func == (lhs: i, rhs: i) -> Bool {
    return lhs.identity == rhs.identity && lhs.value == rhs.value
}

extension i: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "i(\(identity), \(value))"
    }
}
