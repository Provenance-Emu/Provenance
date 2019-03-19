//
//  PipeForward.swift
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

/**
* The pipe forward operator allows to inverse the order of function/parameter list.
* Eg., f(x) can be replaced with x |> f. This can increase code readability.
*/

precedencegroup PipeForwardOperator {
    associativity: left
    higherThan: AdditionPrecedence
}

infix operator |> : PipeForwardOperator

func |> <T, U>(lhs : T, rhs : (T) -> U) -> U {
    return rhs(lhs)
}

// Curried adapter function for Swift Standard Library's filter() function
func filter<S :Sequence>(_ includeElement: (S.Iterator.Element) -> Bool, _ source: S) -> [S.Iterator.Element] {
    let e: [S.Iterator.Element] = source.filter(includeElement)
    return e
}

// Curried adapter function for Swift Standard Library's sorted() function
func sorted<S : Sequence>(_ predicate: (S.Iterator.Element, S.Iterator.Element) -> Bool, _ source: S) -> [S.Iterator.Element] {
    return source.sorted(by: predicate)
}

// Curried adapter function for Swift Standard Library's map() function
func map<C : Sequence, T>(_ transform: (C.Iterator.Element) -> T, _ source: C) -> [T] {
    return source.map(transform)
}

// Curried adapter function for Swift Standard Library's reduce() function
func reduce<S: Sequence, U>(_ initial: U, combine: (U, S.Iterator.Element) -> U, _ sequence: S) -> U {
    return sequence.reduce(initial, combine)
}
