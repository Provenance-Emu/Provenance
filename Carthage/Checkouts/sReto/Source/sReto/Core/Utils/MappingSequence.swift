//
//  StateSequence.swift
//  sReto
//
//  Created by Julian Asamer on 21/08/14.
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
* The iterateMapping function creates a sequence by applying a mapping to a state an arbitrary number of times.
* For example, iterateMapping(initialState: 0, { $0 + 1 }) constructs an infinite list of the numbers 0, 1, 2, ...
*/
func iterateMapping<E>(initialState: E, mapping: @escaping (E) -> E?) -> MappingSequence<E> {
    return MappingSequence(initialState: initialState, mapping: mapping)
}
struct MappingGenerator<E>: IteratorProtocol {
    typealias Element = E
    var state: E?
    let mapping: (E) -> E?

    init(initialState: E, mapping: @escaping (E) -> E?) {
        self.state = initialState
        self.mapping = mapping
    }

    mutating func next() -> Element? {
        let result = self.state
        if let state = self.state { self.state = self.mapping(state) }
        return result
    }
}

struct MappingSequence<E>: Sequence {
    let initialState: E
    let mapping: (E) -> E?

    func makeIterator() -> MappingGenerator<E> {
        return MappingGenerator(initialState: self.initialState, mapping: self.mapping)
    }
}
