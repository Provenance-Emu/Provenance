//
//  GraphTests.swift
//  sReto
//
//  Created by Julian Asamer on 20/08/14.
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

import UIKit
import XCTest

import Foundation

class GraphTests: XCTestCase {
    func testBasicGraphOperations() {
        var graph = Graph<String, DefaultEdge>()
        graph.addVertex("A")

        XCTAssert(graph.allVertices.contains("A"), "Vertex not added")

        graph.addEdge("A", "B", DefaultEdge(weight: 1))

        XCTAssert(graph.allVertices.contains(["A", "B"]), "Edges end not added")

        graph.removeVertex("B")
        let a = "A"

        XCTAssert(graph.allVertices.contains(["A"]), "Vertex removed")
        XCTAssert(!graph.allVertices.contains(["B"]), "Vertex not removed")
        XCTAssert((graph.getEdges(startingAtVertex: "A")?.count ?? 0) == 0, "Edge not removed: edges \(String(describing: graph.getEdges(startingAtVertex: a)))")
        XCTAssert(graph.getEdges(startingAtVertex: "B") == nil, "Edges not nil")

        graph.addEdge("A", "B", DefaultEdge(weight: 1))
        graph.removeEdges(startingAtVertex: "A", endingAtVertex: "B")

        XCTAssert(graph.getEdges(startingAtVertex: "A")?.count == .some(0), "Edge not removed")

        graph.addEdge("A", "B", DefaultEdge(weight: 1))
        graph.addEdge("A", "C", DefaultEdge(weight: 1))
        graph.removeEdges(startingAtVertex: "A")
        XCTAssert(graph.allVertices.contains(["A", "B", "C"]), "Vertex removed")
        XCTAssert(graph.getEdges(startingAtVertex: "A")?.count == .some(0), "Edges not removed")
    }

    func testDijkstraTrivial() {
        let graph = Graph<String, DefaultEdge>(["A": []])
        if let (path, length) = graph.shortestPath("A", end: "A") {
            XCTAssert(length == 0, "Length is not 0")
            XCTAssert(path == ["A"], "Path incorrect")
        } else {
            XCTAssert(false, "No path found.")
        }
    }

    func testDijkstraTrivial2() {
        let graph = Graph<String, DefaultEdge>(["A": [("B", DefaultEdge(weight: 1))]])
        print(graph.allVertices)
        if let (path, length) = graph.shortestPath("A", end: "B") {
            XCTAssert(length == 1, "Length is not 1")
            XCTAssert(path == ["A", "B"], "Path incorrect")
        } else {
            XCTAssert(false, "No path found.")
        }
    }

    func testDijkstraSimpleGraph() {
        let graph = Graph<String, DefaultEdge>([
                "A": [("B", DefaultEdge(weight: 1))],
                "B": [("C", DefaultEdge(weight: 1))],
                "C": [("A", DefaultEdge(weight: 1))],
                "D": []
            ]
        )

        if let (path, length) = graph.shortestPath("A", end: "C") {
            XCTAssert(length == 2, "Length is not 2")
            XCTAssert(path == ["A", "B", "C"], "Path incorrect")
        } else {
            XCTAssert(false, "No path found.")
        }

        XCTAssert(graph.shortestPath("A", end: "D") == nil, "Found non-existant path")

        let (predecessors, distances) = graph.shortestPaths("A")
        XCTAssert(predecessors == ["B": "A", "C": "B"], "Incorrect predecessors")
        XCTAssert(distances == ["A": 0, "B": 1.0, "C": 2.0], "Incorrect distances (\(distances))")
    }
}
