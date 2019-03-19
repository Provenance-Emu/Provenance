//
//  RoutingTable.swift
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
* A Change object contains changes that occurred in the routing table caused by some operation.
* */
struct RoutingTableChange<T> {
    /**
    * Contains information about nodes that became reachable.
    * */
    let nowReachable: [(node: T, nextHop: T, cost: Double)]
    /** Contains all nodes that are now unreachable. */
    let nowUnreachable: [T]
    /**
    * Contains informatiown about nodes that have changed routes.
    * */
    let routeChanged: [(node: T, nextHop: T, oldCost: Double, newCost: Double)]

    /** Returns whether this Change object is actually empty. */
    var isEmpty: Bool { get { return nowReachable.isEmpty && nowUnreachable.isEmpty && routeChanged.isEmpty } }
}

/** Finds the next hop to a given destination node based on the predecessor relationships of the nodes. */
private func findNextHop<T>(_ predecessorRelationships: [T: T], destination: T) -> T {
    let path = Array(Array(
        iterateMapping(
            initialState: destination,
            mapping: { predecessorRelationships[$0] }
        )
    ).reversed())

    return path[1]
}

/**
* A LinkStateRoutingTable manages a graph of nodes in the network with type T.
*
* Link state routing works by gathering information about the full network topology, i.e. for each node in the network,
* all of its neighbors are known eventually. Based on this information, the next hop to a node can be computed using a shortest path algorithm.
*
* Advantages of link state routing (as opposed to distance vector routing) include that link state routing converges rather quickly and
* is not subject to the count-to-infinity problem, hence, no measures to combat this problem need to be taken. As the full network topology
* is known to every node, rather advanced routing techniques can be implemented.
*
* Disadvantages include that the link state information needs to be flooded through the network, causing higher overhead than link state protocols.
* The memory and computational requirements are also higher.
*
* The LinkStateRoutingTable class is not responsible for distributing link state information across the network,
* however, it processes received link state information and can provide link state information for the local peer.
*
* This routing table is designed to compute all next hops and path costs for all known nodes every time when new
* network topology information becomes available (e.g. neighbors added, updated or lost, and link state information received from
* any peer).
*
* These changes in the routing table are returned as a LinkStateRoutingTable.Change object. This object includes information about
* nodes that became reachable or unreachable, or information about route changes to nodes that were reachable before.
* */
class LinkStateRoutingTable<T: Hashable> {
    /** A directed, weighted graph used to represent the network of nodes and their link states. */
    var graph: Graph<T, DefaultEdge> = Graph()
    /** The local node. In all neighbor related operations, the neighbor is considered a neighbor of this node. */
    var localNode: T

    /** Constructs a new LinkStateRoutingTable. */
    init(localNode: T) {
        self.localNode = localNode
        self.graph.addVertex(self.localNode)
    }

    /**
    * Computes the changes to the routing table when updating or adding a new neighbor.
    * If the neighbor is not yet known to the routing table, it is added.
    *
    * @param neighbor The neighbor to update or add.
    * @param cost The cost to reach that neighbor.
    * @return A LinkStateRoutingTable.Change object representing the changes that occurred in the routing table.
    * */
    func getRoutingTableChangeForNeighborUpdate(_ neighbor: T, cost: Double) -> RoutingTableChange<T> {
        return self.trackGraphChanges { self.updateNeighbor(neighbor, cost: cost) }
    }
    /**
    * Computes the changes to the routing table when removing a neighbor.
    *
    * @param neighbor The neighbor to remove
    * @return A LinkStateRoutingTable.Change object representing the changes that occurred in the routing table.
    * */
    func getRoutingTableChangeForNeighborRemoval(_ neighbor: T) -> RoutingTableChange<T> {
        return self.trackGraphChanges { self.removeNeighbor(neighbor) }
    }
    /**
    * Computes the changes to the routing table when link state information is received for a given node.
    *
    * @param node The node for which a list of neighbors (ie. link state information) was received.
    * @param neighbors The node's neighbors.
    * @return A LinkStateRoutingTable.Change object representing the changes that occurred in the routing table.
    * */
    func getRoutingTableChangeForLinkStateInformationUpdate(_ node: T, neighbors: [(neighborId: T, cost: Double)]) -> RoutingTableChange<T> {
        return self.trackGraphChanges { self.updateLinkStateInformation(node, neighbors: neighbors) }
    }

    /** Returns a list of neighbors for the local node (ie. link state information). */
    func linkStateInformation() -> [(nodeId: T, cost: Double)] {
        if let info = self.graph.getEdges(startingAtVertex: self.localNode) {
            return info.map { (nodeId: $0.endVertex, cost: $0.annotation.weight) }
        }

        return []
    }

    /** Updates or adds a neighbor. */
    fileprivate func updateNeighbor(_ neighbor: T, cost: Double) {
        self.graph.removeEdges(startingAtVertex: self.localNode, endingAtVertex: neighbor)
        self.graph.addEdge(self.localNode, neighbor, DefaultEdge(weight: cost))
    }
    /** Removes a neighbor. */
    fileprivate func removeNeighbor(_ neighbor: T) {
        self.graph.removeEdges(startingAtVertex: self.localNode, endingAtVertex: neighbor)
    }
    /** Updates link state information for a given node. */
    fileprivate func updateLinkStateInformation(_ node: T, neighbors: [(neighborId: T, cost: Double)]) {
        self.graph.removeEdges(startingAtVertex: node)

        for (neighbor, cost) in neighbors {
            self.graph.addEdge(node, neighbor, DefaultEdge(weight: cost))
        }
    }

    func nextHop(_ destination: T) -> T? {
        if let (path, _) = graph.shortestPath(self.localNode, end: destination) {
            return path[1]
        }

        return nil
    }
    func getHopTree(_ destinations: Set<T>) -> Tree<T> {
        return self.graph.getSteinerTreeApproximation(rootVertex: self.localNode, includedVertices: destinations + [self.localNode])
    }

    /**
    * Computes a Change object for arbitrary modifications of the graph.
    *
    * This method first computes the shortest paths to all reachable nodes in the graph, then runs the graph action, and then calculates all shortest paths again.
    *
    * From changes in which nodes are reachable, and changes in the paths, a LinkStateRoutingTable.Change object is created.
    *
    * @param graphAction A Runnable that is expected to perform some changes on the graph.
    * @return A LinkStateRoutingTable.Change object representing the changes caused by the changes performed by the graphAction.
    * */
    fileprivate func trackGraphChanges(_ graphAction: () -> Void) -> RoutingTableChange<T> {
        let (previousPredecessorRelationships, previousDistances) = graph.shortestPaths(self.localNode)

        graphAction()

        let (updatedPredecessorRelationships, updatedDistances) = graph.shortestPaths(self.localNode)

        let nowReachable = (Set(updatedPredecessorRelationships.keys) - Set(previousPredecessorRelationships.keys)).map({
                (
                    node: $0,
                    nextHop: findNextHop(updatedPredecessorRelationships, destination: $0),
                    cost: updatedDistances[$0]!
                )
            }
        )
        let nowUnreachable = Set(previousPredecessorRelationships.keys) - Set(updatedPredecessorRelationships.keys)

        let changedRoutes = Set(updatedPredecessorRelationships.keys).intersection(Set(previousPredecessorRelationships.keys))
            .filter {
                previousDistances[$0] != updatedDistances[$0] ||
                    findNextHop(previousPredecessorRelationships, destination: $0) != findNextHop(updatedPredecessorRelationships, destination: $0)
            }
            .map { (
                node: $0,
                nextHop: findNextHop(updatedPredecessorRelationships, destination: $0),
                oldCost: previousDistances[$0]!,
                newCost: updatedDistances[$0]!
                )
        }

        return RoutingTableChange(
            nowReachable: Array(nowReachable),
            nowUnreachable: Array(nowUnreachable),
            routeChanged: Array(changedRoutes)
        )
    }
}
