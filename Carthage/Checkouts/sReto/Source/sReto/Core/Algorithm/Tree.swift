//
//  Tree.swift
//  sReto
//
//  Created by Julian Asamer on 15/09/14.
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
* This class represents a general tree. Each tree has any number of subtrees.
* A tree that has no subtrees is a leaf. The size of a tree is the size of all of its children plus one. 
* Each tree has an associated value. */
class Tree<T: Hashable> {
    /** The tree's associated value */
    let value: T
    /** The tree's subtrees */
    var subtrees: Set<Tree<T>> = []
    /** The tree's size */
    var size: Int { get { return subtrees.map({ $0.size }).reduce(1, +) } }
    /** Whether the tree is a leaf */
    var isLeaf: Bool { get { return subtrees.count == 0 } }

    /** Constructs a new tree given a value and a set of subtrees. */
    init(value: T, subtrees: Set<Tree<T>>) {
        self.value = value
        self.subtrees = subtrees
    }
}

extension Tree: Hashable {
    var hashValue: Int { get { return self.value.hashValue } }
}

/** Two trees are equal if their values and subtrees are equal.*/
func ==<T: Equatable>(tree1: Tree<T>, tree2: Tree<T>) -> Bool {
    return tree1.value == tree2.value && tree1.subtrees == tree2.subtrees
}

extension Tree: CustomStringConvertible {
    var description: String {
        return "{value: \(value), children: \(subtrees)}"
    }
}
