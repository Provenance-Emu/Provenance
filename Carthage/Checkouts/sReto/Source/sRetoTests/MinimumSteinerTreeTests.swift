//
//  MinimumSteinerTreeTests.swift
//  sReto
//
//  Created by Julian Asamer on 16/09/14.
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
import UIKit
import XCTest

extension Graph {
    func makeSymmetric() -> Graph<V, E> {
        var result = Graph<V, E>()

        for vertex in self.allVertices {
            result.addVertex(vertex)
        }

        for edge in self.allEdges {
            result.addEdge(edge.startVertex, edge.endVertex, edge.annotation)
            result.addEdge(edge.endVertex, edge.startVertex, edge.annotation)
        }

        return result
    }
}

class MinimumSteinerTreeTests: XCTestCase {
    func testTrivial() {
        let graph = Graph(
            [
                1: [(2, DefaultEdge(weight: 10))],
                2: [(3, DefaultEdge(weight: 10))]
            ]
        )

        let result1 = graph.getSteinerTreeApproximation(rootVertex: 1, includedVertices: [1, 2, 3])
        let result2 = graph.getSteinerTreeApproximation(rootVertex: 1, includedVertices: [1, 3])
        let expectedResult = Tree(value: 1, subtrees: [Tree(value: 2, subtrees: [Tree(value: 3, subtrees: [])])])

        XCTAssert(result1 == expectedResult, "Did not compute expected result.")
        XCTAssert(result2 == expectedResult, "Did not compute expected result.")
    }

    func testSingleSteinerVertex() {
        let graph = Graph(
            [
                1: [(2, DefaultEdge(weight: 10))],
                2: [(3, DefaultEdge(weight: 10))],
                3: [(1, DefaultEdge(weight: 10))],
                4: [(1, DefaultEdge(weight: 1)), (2, DefaultEdge(weight: 1)), (3, DefaultEdge(weight: 1))]
            ]
        ).makeSymmetric()

        let result = graph.getSteinerTreeApproximation(rootVertex: 1, includedVertices: [1, 2, 3])
        let expectedResult = Tree(value: 1, subtrees: [
                Tree(value: 4, subtrees: [
                        Tree(value: 2, subtrees: []),
                        Tree(value: 3, subtrees: [])
                ])
        ])

        XCTAssert(result == expectedResult, "Did not compute expected result.")
    }

    func createTwoClusterGraph() -> Graph<Int, DefaultEdge> {
        return Graph(
            [
                1: [(2, DefaultEdge(weight: 1)), (5, DefaultEdge(weight: 10))],
                2: [(3, DefaultEdge(weight: 1)), (5, DefaultEdge(weight: 10))],
                3: [(1, DefaultEdge(weight: 1))],
                4: [(5, DefaultEdge(weight: 1))],
                5: [(6, DefaultEdge(weight: 1))],
                6: [(4, DefaultEdge(weight: 1))]
            ]
        ).makeSymmetric()
    }

    func testTwoClusterBroadcast() {
        let result = createTwoClusterGraph().getSteinerTreeApproximation(rootVertex: 1, includedVertices: [1, 2, 3, 4, 5, 6])
        let expectedResult = Tree(value: 1, subtrees: [
            Tree(value: 2, subtrees: []),
            Tree(value: 3, subtrees: []),
            Tree(value: 5, subtrees: [
                Tree(value: 4, subtrees: []),
                Tree(value: 6, subtrees: [])
            ])
        ])

        print("result: \(result)")

        XCTAssert(result == expectedResult, "Did not compute expected result.")
    }

    func testTwoClusterMulticast() {
        let result = createTwoClusterGraph().getSteinerTreeApproximation(rootVertex: 1, includedVertices: [1, 5, 6])
        let expectedResult = Tree(value: 1, subtrees: [
            Tree(value: 5, subtrees: [
                Tree(value: 6, subtrees: [])
            ])
        ])

        XCTAssert(result == expectedResult, "Did not compute expected result.")
    }
}
