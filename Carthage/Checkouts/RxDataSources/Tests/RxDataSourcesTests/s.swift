//
//  s.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 11/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import Foundation
import Differentiator
import RxDataSources

/**
 Test section. Name is so short for readability sake.
 */
struct s {
    let identity: Int
    let items: [i]
}

extension s {
    init(_ identity: Int, _ items: [i]) {
        self.identity = identity
        self.items = items
    }
}

extension s: AnimatableSectionModelType {
    typealias Item = i

    init(original: s, items: [Item]) {
        self.identity = original.identity
        self.items = items
    }
}

extension s: Equatable {
    
}

func == (lhs: s, rhs: s) -> Bool {
    return lhs.identity == rhs.identity && lhs.items == rhs.items
}

extension s: CustomDebugStringConvertible {
    var debugDescription: String {
        let itemDescriptions = items.map { "\n    \($0)," }.joined(separator: "")
        return "s(\(identity),\(itemDescriptions)\n)"
    }
}

struct sInvalidInitializerImplementation1 {
    let identity: Int
    let items: [i]

    init(_ identity: Int, _ items: [i]) {
        self.identity = identity
        self.items = items
    }
}

func == (lhs: sInvalidInitializerImplementation1, rhs: sInvalidInitializerImplementation1) -> Bool {
    return lhs.identity == rhs.identity && lhs.items == rhs.items
}

extension sInvalidInitializerImplementation1: AnimatableSectionModelType, Equatable {
    typealias Item = i

    init(original: sInvalidInitializerImplementation1, items: [Item]) {
        self.identity = original.identity
        self.items = items + items
    }
}

struct sInvalidInitializerImplementation2 {
    let identity: Int
    let items: [i]

    init(_ identity: Int, _ items: [i]) {
        self.identity = identity
        self.items = items
    }
}

extension sInvalidInitializerImplementation2: AnimatableSectionModelType, Equatable {
    typealias Item = i

    init(original: sInvalidInitializerImplementation2, items: [Item]) {
        self.identity = -1
        self.items = items
    }
}

func == (lhs: sInvalidInitializerImplementation2, rhs: sInvalidInitializerImplementation2) -> Bool {
    return lhs.identity == rhs.identity && lhs.items == rhs.items
}
