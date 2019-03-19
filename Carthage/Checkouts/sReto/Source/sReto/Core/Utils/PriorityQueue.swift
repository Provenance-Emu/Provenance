//
//  PriorityQueue.swift
//  sReto
//
//  Created by Julian Asamer on 19/08/14.
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
A naive implementation of a PriorityQueue.
Keeps an array of elements that are is sorted by priority.
The only fast operation is removeMinimum.
Insert and update updatePriority are both O(n).
*/
struct SortedListPriorityQueue<T: Hashable> {
    var elements: [(Double, T)] = []

    // Binary search for the appropiate index for the value
    fileprivate func searchIndex(_ start: Int, end: Int, value: Double) -> Int {
        if start == end {
            return start
        } else {
            let middle = start + (end - start)/2

            if value >= elements[middle].0 {
                return searchIndex(start, end: middle, value: value)
            } else {
                return searchIndex(middle+1, end: end, value: value)
            }
        }
    }

    mutating func insert(_ element: T, priority: Double) {
        let index = searchIndex(0, end: self.elements.count, value: priority)
        elements.insert( (priority, element), at: index)
    }
    mutating func removeMinimum() -> T? {
        if let result = elements.last {
            elements.removeLast()
            return result.1
        }

        return nil
    }
    // There's no faster way to do remove with this kind of implementation.
    mutating func remove(_ element: T) {
        elements = elements.filter({ $0.1 != element })
    }
    mutating func updatePriority(_ element: T, priority: Double) {
        self.remove(element) // Oh noes.
        self.insert(element, priority: priority)
    }
}
