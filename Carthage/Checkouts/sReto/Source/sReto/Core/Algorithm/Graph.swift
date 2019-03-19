//
//  Graph.swift
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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

/**
* The protocol used with edge annotations.
* Since edges are weighted, each edge needs to store it's weight as a minimum, but may store any additional information.
*/
protocol WeightedEdgeAnnotation {
    /** Contains this edge's weight. */
    var weight: Double { get }
}

/** 
* A DefaultEdge is a WeightedEdgeAnnotation that stores a weight only.
*/
public struct DefaultEdge: WeightedEdgeAnnotation {
    var weight: Double = 1
}

/** An Edge stores a start and end vertex, plus an edge annotation. */
struct Edge<V, E> {
    /** The edge's start vertex. */
    let startVertex: V
    /** The edge's end vertex. */
    let endVertex: V
    /** The edge's annotation. */
    let annotation: E
}

/**
* The Graph class represents a weighted, directed graph using an adjacency list.
* Any Hashable type can be used as vertices. Edges are annotated with WeightedEdgeAnnotations.
*/
struct Graph<V: Hashable, E: WeightedEdgeAnnotation> {
    /** The adjacency list used to represent the graph. Is actually a dictionary, mapping from vertices to a list of a vertex, annotation tuple. */
    var adjacencyList: [V: [(vertex: V, annotation: E)]] = [:]
    /** All vertices contained in this graph. */
    var allVertices: Set<V> { get { return Set(self.adjacencyList.keys) } }
    /** All edges contained in this graph. */
    var allEdges: [Edge<V, E>] { get { return self.allVertices.map({ self.getEdges(startingAtVertex: $0) ?? [] }).reduce([], +) } }

    /** Constructs a new graph given the list of adjacencies for each node. */
    init(_ adjacencyList: [V: [(vertex: V, annotation: E)]] = [:]) {
        self.adjacencyList = adjacencyList
        // Make sure that vertices occuring in the edge lists are vertices of the graph.
        for (_, edges) in adjacencyList {
            for (vertex, _) in edges {
                self.addVertex(vertex)
            }
        }
    }

    /**  
    * Reverses the graph. I.e. in the resulting graph, the directions of all edges are reversed.
    */
    func reverse() -> Graph<V, E> {
        var graph = Graph<V, E>()

        for (startVertex, edges) in self.adjacencyList {
            for (endVertex, edge) in edges {
                graph.addEdge(endVertex, startVertex, edge)
            }
        }

        return graph
    }
    /**
    * Returns a new graph corresponding to this graph, with the edge annotations mapped to new ones.
    */
    func mapEdges<F: WeightedEdgeAnnotation>(_ mapping: (E) -> F) -> Graph<V, F> {
        return Graph<V, F>(self.adjacencyList.mapValues { vertex, adjacencies in
            adjacencies.map { (vertex: $0.vertex, edge: mapping($0.annotation)) }
        })
    }
    /**
    * Returns a new graph corresponding to this graph, with the vertices mapped to new ones.
    */
    func mapVertices<W>(_ mapping: @escaping (V) -> W) -> Graph<W, E> {
        return Graph<W, E>(self.adjacencyList.map({ vertex, adjacencies in
            (mapping(vertex), adjacencies.map { (vertex: mapping($0.vertex), annotation: $0.annotation) })
        }))
    }
    /** 
    * Returns all edges starting at a given vertex.
    * @param vertex The vertex at which the edges in question start
    * @return A list of edges starting at the specified vertex.
    */
    func getEdges(startingAtVertex vertex: V) -> [Edge<V, E>]? {
        if let adjacencies = self.adjacencyList[vertex] {
            return adjacencies.map { Edge(startVertex: vertex, endVertex: $0.vertex, annotation: $0.annotation) }
        } else {
            return nil
        }
    }
    /**
    * Returns all edges ending at a given vertex.
    * @param vertex The vertex at which the edges in question end
    * @return A list of edges ending at the specified vertex.
    */
    func getEdges(endingAtVertex vertex: V) -> [Edge<V, E>]? {
        return self
            .reverse()
            .getEdges(startingAtVertex: vertex)
            .map({
                $0.map {
                    Edge(startVertex: $0.endVertex, endVertex: $0.startVertex, annotation: $0.annotation)
                }
            })
    }
    /**
    * Returns all edges starting at a start vertex and ending at an end vertex.
    * @param startVertex The vertex at which the edges in question start
    * @param endVertex The vertex at which the edges in question end
    * @return A list of edges starting and ending at the specified vertices. Nil if the start vertex is not in the graph.
    */
    func getEdges(startingAtVertex startVertex: V, endingAtVertex endVertex: V) -> [Edge<V, E>]? {
        return self
            .adjacencyList[startVertex]
            .map {
                $0
                .filter { $0.vertex == endVertex }
                .map {
                    Edge(startVertex: startVertex, endVertex: endVertex, annotation: $0.annotation)
                }
            }
    }
    /**
    * Returns the shortest edges starting at a start vertex and ending at an end vertex.
    * @param startVertex The vertex at which the edges in question start
    * @param endVertex The vertex at which the edges in question end
    * @return The shortest edge starting and ending at the specified vertices.
    */
    func getShortestEdge(startingAtVertex startVertex: V, endingAtVertex endVertex: V) -> Edge<V, E>? {
        return minimum(self.getEdges(startingAtVertex: startVertex, endingAtVertex: endVertex) ?? [], comparator: comparing { $0.annotation.weight })
    }
    /** 
    * Tests whether the graph contains a given vertex.
    * @param vertex The vertex in question.
    * @return True if the graph contains that vertex. False otherwise.
    */
    func contains(vertex: V) -> Bool {
        return self.adjacencyList[vertex] != nil
    }
    /**
    * Tests whether the graph contains one or more edges between two given vertices.
    * @param startVertex The start vertex of the edge thats existence should be tested.
    * @param endVertex The end vertex of the edge thats existence should be tested.
    * @param True if one or more such edges exist. False otherwise.
    */
    func containsEdge(startingAtVertex startVertex: V, endingAtVertex endVertex: V) -> Bool {
        return self
            .getEdges(startingAtVertex: startVertex, endingAtVertex: endVertex)
            .map { $0.count != 0 } ?? false
    }
    /** 
    * Adds a vertex to the graph.
    */
    mutating func addVertex(_ vertex: V) {
        if adjacencyList[vertex] == nil {
            self.adjacencyList[vertex] = []
        }
    }
    /**
    * Removes a vertex. All edges starting or ending at this vertex will be removed.
    */
    mutating func removeVertex(_ vertex: V) {
        self.adjacencyList[vertex] = nil

        for otherVertex in self.allVertices {
            self.removeEdges(startingAtVertex: otherVertex, endingAtVertex: vertex)
        }
    }
    /**
    * Adds an edge to the graph. If either vertex of the edge is not in the graph, it is added.
    * @param vertex1 The start vertex of the edge.
    * @param vertex2 The end vertex of the edge.
    * @param edgeAnnotation The edgeAnnotation of the edge.
    */
    mutating func addEdge(_ vertex1: V, _ vertex2: V, _ edgeAnnotation: E) {
        self.addVertex(vertex1)
        self.addVertex(vertex2)
        self.adjacencyList[vertex1]?.append( (vertex: vertex2, annotation: edgeAnnotation) )
    }
    /**
    * Adds an edge to the graph. @see addEdge(V, V, E)
    */
    mutating func addEdge(_ edge: Edge<V, E>) {
        self.addEdge(edge.startVertex, edge.endVertex, edge.annotation)
    }
    /**
    * Removes all edges connecting a start and endVertex.
    * @param startVertex The startVertex of the edges in question.
    * @param endVertex The endVertex of the edges in question.
    */
    mutating func removeEdges(startingAtVertex startVertex: V, endingAtVertex endVertex: V) {
        adjacencyList[startVertex] = adjacencyList[startVertex]?.filter { (vertex, cost) in vertex != endVertex }
    }
    /**
    * Removes all edges starting at a given vertex.
    * @param vertex The start vertex of the edges that should be removed.
    */
    mutating func removeEdges(startingAtVertex vertex: V) {
        adjacencyList[vertex] = []
    }

    /**
    * Computes all vertices that are reachable from a gaven start vertex.
    * @param start The start vertex for which all reachable nodes should be computed.
    * @return A set of nodes that are reachable from the start vertex.
    */
    func reachableVertices(_ start: V) -> Set<V> {
        return Set(depthFirstSearch(start, visitedVertices: Set()))
    }
    /** 
    * Explores the graph using DFS.
    */
    private func depthFirstSearch(_ vertex: V, visitedVertices: Set<V>) -> [V] {
        var visitedVertices = visitedVertices
        visitedVertices += vertex

        if let edges = self.getEdges(startingAtVertex: vertex) {
            let recursiveResults = edges
                .map { $0.endVertex }
                .map {
                    vertex -> [V] in
                    if visitedVertices.contains(vertex) { return [] } else {
                        let result = self.depthFirstSearch(vertex, visitedVertices: visitedVertices)
                        visitedVertices += result
                        return result
                    }
                }
                .reduce([], +)

            return [vertex] + recursiveResults
        }

        return [vertex]
    }

    /**
    * Performs Dijkstras algorithm on the full graph to find all shortest paths in the graph from a given start vertex.
    * @param start The start vertex from which the paths should be found.
    * @param endVertex An optional end vertex. If specified, the algorithm ends when the shortest path to this vertex is found.
    * @return A tuple of predecessorRelationships which represent the shortest paths, and the shortest distances for all reachable vertices.
    */
    func shortestPaths(_ start: V, endVertex: V? = nil) -> (predecessorRelationships: [V: V], distances: [V: Double]) {
        var shortestKnownDistancesByVertex: [V: Double] = [start: 0]
        var predecessorVertices: [V: V] = [:]
        // The working set contains the vertices that will be inspected next.
        var workingSet: SortedListPriorityQueue<V> = SortedListPriorityQueue()
        workingSet.insert(start, priority: 0)
        var unvisitedVertices = self.allVertices

        while !unvisitedVertices.isEmpty {
            if let closestVertex = workingSet.removeMinimum() {
                if let _ = endVertex { if closestVertex == endVertex { break } }

                let closestVertexDistance = shortestKnownDistancesByVertex[closestVertex]!
                unvisitedVertices -= closestVertex
                // All outgoing edges from the closest vertex that were not visited yet.
                for edge in self.getEdges(startingAtVertex: closestVertex)!.filter({ unvisitedVertices.contains($0.endVertex) }) {
                    let alternatePathLength = closestVertexDistance + edge.annotation.weight

                    let distanceUnknown = shortestKnownDistancesByVertex[edge.endVertex] == nil
                    let betterAlternativeFound = distanceUnknown || shortestKnownDistancesByVertex[edge.endVertex] > alternatePathLength

                    if betterAlternativeFound {
                        if distanceUnknown {
                            workingSet.insert(edge.endVertex, priority: alternatePathLength)
                        } else {
                            workingSet.updatePriority(edge.endVertex, priority: alternatePathLength)
                        }

                        shortestKnownDistancesByVertex[edge.endVertex] = alternatePathLength
                        predecessorVertices[edge.endVertex] = closestVertex
                    }
                }
            } else {
                // If we end up here, there was no path to the end node
                break
            }
        }

        return (predecessorRelationships: predecessorVertices, distances: shortestKnownDistancesByVertex)
    }

    /**
    * Finds the shortest path from a given start vertex to an end vertex.
    * @param start The start vertex
    * @param end The end vertex
    * @return The path from the start to the end vertex, and the length of the path.
    */
    func shortestPath(_ start: V, end: V) -> (path: [V], length: Double)? {
        let (predecessorVertices, distances) = self.shortestPaths(start, endVertex: end)

        // The predecessor dictionary allows us to construct the path in reverse order.
        if let _ = predecessorVertices[end] {
            var current: V? = end

            // Essentially, this creates the sequence [predecessorVertices[end], predecessorVertices[predecessorVertices[end]], ...]
            let reversePathSequence = AnySequence (
                AnyIterator({
                    () -> V? in
                    current = predecessorVertices[current!]
                    return current
                })
            )

            return (path: Array(Array(reversePathSequence).reversed()) + [end], length: distances[end]!)
        } else {
            if start == end {
                return (path: [end], length: 0)
            } else {
                return nil
            }
        }
    }

    /**
    * Computes the minimum aborescence graph (i.e. the "minimum spanning tree of a directed graph") using a given start vertex.
    * @param startVertex The start vertex (i.e. root node)
    * @return The minimum aborescence
    */
    func getMinimumAborescenceGraph(_ startVertex: V) -> Graph<V, E> {
        let (predecessorRelationships, _) = self.shortestPaths(startVertex)

        var result = Graph<V, E>()

        for (node, predecessor) in predecessorRelationships {
            if let edges = self.getEdges(startingAtVertex: predecessor, endingAtVertex: node) {
                if let edge = minimum(edges, comparator: comparing { $0.annotation.weight }) {
                    result.addEdge(edge)
                }
            }
        }

        return result
    }
}

extension Graph: CustomStringConvertible {
    var description: String {
        return adjacencyList.description
    }
}
