//
//  XCTest+Extensions.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 11/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import Foundation
import XCTest
import Differentiator
import RxDataSources

func XCAssertEqual<S: AnimatableSectionModelType>(_ lhs: [S], _ rhs: [S], file: StaticString = #file, line: UInt = #line)
    where S: Equatable {
    let areEqual = lhs == rhs
    if !areEqual {
        printSectionModelDifferences(lhs, rhs)
    }
    
    XCTAssertTrue(areEqual, file: file, line: line)
}

fileprivate struct EquatableArray<Element: Equatable> : Equatable {
    let elements: [Element]
    init(_ elements: [Element]) {
        self.elements = elements
    }
}

fileprivate func == <E>(lhs: EquatableArray<E>, rhs: EquatableArray<E>) -> Bool {
    return lhs.elements == rhs.elements
}

fileprivate func printSequenceDifferences<E>(_ lhs: [E], _ rhs: [E], _ equal: (E, E) -> Bool) {
    print("Differences in sequence:")
    for (index, elements) in zip(lhs, rhs).enumerated() {
        let l = elements.0
        let r = elements.1
        if !equal(l, r) {
            print("lhs[\(index)]:\n    \(l)")
            print("rhs[\(index)]:\n    \(r)")
        }
    }

    let shortest = min(lhs.count, rhs.count)
    for (index, element) in lhs[shortest ..< lhs.count].enumerated() {
        print("lhs[\(index + shortest)]:\n    \(element)")
    }
    for (index, element) in rhs[shortest ..< rhs.count].enumerated() {
        print("rhs[\(index + shortest)]:\n    \(element)")
    }
}

fileprivate func printSectionModelDifferences<S: AnimatableSectionModelType>(_ lhs: [S], _ rhs: [S])
    where S: Equatable {
    print("Differences in sections:")
    for (index, elements) in zip(lhs, rhs).enumerated() {
        let l = elements.0
        let r = elements.1
        if l != r {
            if l.identity != r.identity {
                print("lhs.identity[\(index)] (\(l.identity)) != rhs.identity[\(index)] (\(r.identity))\n")
            }
            if l.items != r.items {
                print("Difference in items for \(l.identity) and \(r.identity)")
                printSequenceDifferences(l.items, r.items, { $0 == $1 })
            }
        }
    }

    let shortest = min(lhs.count, rhs.count)
    for (index, element) in lhs[shortest ..< lhs.count].enumerated() {
        print("missing lhs[\(index + shortest)]:\n    \(element)")
    }
    for (index, element) in rhs[shortest ..< rhs.count].enumerated() {
        print("missing rhs[\(index + shortest)]:\n    \(element)")
    }
}

