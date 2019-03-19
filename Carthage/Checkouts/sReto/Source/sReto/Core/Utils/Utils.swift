//
//  Utils.swift
//  sReto
//
//  Created by Julian Asamer on 07/07/14.
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

// Returns the first element of a sequence
func first<S: Sequence, E>(_ sequence: S) -> E? where E == S.Iterator.Element {
    for element in sequence { return element }
    return nil
}

// Returns the second element of a sequence
func second<S: Sequence, E>(_ sequence: S) -> E? where E == S.Iterator.Element {
    var first = true
    for element in sequence { if first { first = false } else { return element } }
    return nil
}

func reduce<S: Sequence, E>(_ sequence: S, combine: (E, E) -> E) -> E? where S.Iterator.Element == E {
    if let first = first(sequence) {
        return sequence.reduce(first, combine)
    } else {
        return nil
    }
}

func pairwise<T>(_ elements: [T]) -> [(T, T)] {
    var elementCopy = elements
    elementCopy.remove(at: 0)
    return Array(zip(elements, elementCopy))
}

func sum<S: Sequence>(_ sequence: S) -> Int where S.Iterator.Element == Int {
    return sequence.reduce(0, +)
}
func sum<S: Sequence>(_ sequence: S) -> Float where S.Iterator.Element == Float {
    return sequence.reduce(0, +)
}
// Takes a key extractor that maps an element to a comparable value, and returns a function that compares to objects of type T via the extracted key.
func comparing<T, U: Comparable>(withKeyExtractor keyExtractor: @escaping (T) -> U) -> ((T, T) -> Bool) {
    return { a, b in keyExtractor(a) < keyExtractor(b) }
}

func equal<S: Collection, T>(_ comparator: (T, T) -> Bool, s1: S, s2: S) -> Bool where S.Iterator.Element == T {
    return (s1.count == s2.count) && zip(s1, s2).reduce(true, { value, pair in value && comparator( pair.0, pair.1) })
}

// Returns the non-nil parameter if only one of them is nil, nil if both parameters are nil, otherwise the minimum.
func min<T: Comparable>(_ a: T?, b: T?) -> T? {
    switch (a, b) {
    case (.none, .none): return nil
    case (.none, .some(let value)): return value
    case (.some(let value), .none): return value
    case (.some(let value1), .some(let value2)): return min(value1, value2)
    }
}

func minimum<T>(_ a: T, b: T, comparator: (T, T) -> Bool) -> T { return comparator(a, b) ? a : b }
func minimum<T, S: Sequence>(_ sequence: S, comparator: (T, T) -> Bool) -> T? where S.Iterator.Element == T {
    if let first = first(sequence) {
        return sequence.reduce(first, { (a, b) -> T in return minimum(a, b: b, comparator: comparator) })
    }
    return nil
}

// Compares two sequences with comparable elements. 
// The first non-equal element that exists in both sequences determines the result.
// If no non-equal element exists (either because one sequence is longer than the other, or they are equal) false is returned.
func < <S: Sequence, T: Sequence>(a: S, b: T) -> Bool where S.Iterator.Element: Comparable, S.Iterator.Element == T.Iterator.Element {
    if let (a, b) = first((zip(a, b).lazy).filter({ pair in pair.0 != pair.1 })) {
        return a < b
    }

    return false
}

extension Dictionary {
    mutating func getOrDefault(_ key: Key, defaultValue: @autoclosure () -> Value) -> Value {
        if let value = self[key] {
            return value
        } else {
            let value = defaultValue()
            self[key] = value
            return value
        }
    }
}

struct Queue<T: AnyObject> {
    typealias Element = T
    var array: [T] = []

    var count: Int { get { return array.count } }

    mutating func enqueue(_ element: Element) {
       array.append(element)
    }

    mutating func dequeue() -> Element? {
        if array.count == 0 { return nil }
        return array.remove(at: 0)
    }

    func anyMatch(_ predicate: (Element) -> Bool) -> Bool {
        for element in array { if predicate(element) { return true } }

        return false
    }

    mutating func filter(_ predicate: (Element) -> Bool) {
        self.array = array.filter({ element in predicate(element) })
    }
}

extension Dictionary {
    func map<NewKey: Hashable, NewValue>(_ mapping: (Key, Value) -> (NewKey, NewValue)) -> [NewKey: NewValue] {
        var dictionary: [NewKey: NewValue] = [:]

        for (key, value) in self {
            let (newKey, newValue) = mapping(key, value)
            dictionary[newKey] = newValue
        }

        return dictionary
    }

    func mapValues<NewValue>(_ mapping: (Key, Value) -> NewValue) -> [Key: NewValue] {
        return self.map { return ($0, mapping($0, $1)) }
    }
}
