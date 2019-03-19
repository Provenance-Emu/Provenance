//
//  Set.swift
//  sReto
//
//  Created by Julian Asamer on 15/08/14.
//  Copyright (c) 2014 - 2016 Chair for Applied Software Engineering
//
//  Licensed under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness
//  for a particular purpose and noninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, 
//  whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
//

import Foundation

extension Set {

    /** Tests whether a all elements in a given array are all members of this set. */
    func contains(_ elements: [Element]) -> Bool {
        return elements.map { self.contains($0) }.reduce(true, { a, b in return a && b })
    }
}

/** Adds an element to a set. */
func +=<Element>(set: inout Set<Element>, element: Element) {
    set.insert(element)
}
/** Removes an element from a set. */
func -=<T>(set: inout Set<T>, i: T) {
    set.remove(i)
}
/** Adds a sequence of elements to a set. */
func +=<Element, S : Sequence>(lhs: inout Set<Element>, rhs: S) where S.Iterator.Element == Element {
    lhs = lhs.union(rhs)
}
/** Adds a set to a set. */
func +<Element>(lhs: Set<Element>, rhs: Set<Element>) -> Set<Element> {
    return lhs.union(rhs)
}
/** Removes a Set from a Set. */
func -<Element>(lhs: Set<Element>, rhs: Set<Element>) -> Set<Element> {
    return lhs.subtracting(rhs)
}
