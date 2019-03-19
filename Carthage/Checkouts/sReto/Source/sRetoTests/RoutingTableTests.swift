//
//  RoutingTableTests.swift
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

func == (a: (String, Double)?, b: (String, Double)?) -> Bool {
    return a?.0 == b?.0 && a?.1 == b?.1
}

class RoutingTableTests: XCTestCase {

    func testRoutingTableWithNeighbor() {
        let routingTable = LinkStateRoutingTable(localNode: "Local")
        let routeChange = routingTable.getRoutingTableChangeForNeighborUpdate("A", cost: 10)

        XCTAssert(routeChange.nowReachable.count == 1, "New node reachable")
        XCTAssert(routeChange.nowUnreachable.count == 0, "Node unreachable")
        XCTAssert(routeChange.routeChanged.count == 0, "Node unreachable")

        XCTAssert(routeChange.nowReachable[0].nextHop == "A")
        XCTAssert(routeChange.nowReachable[0].cost == 10)
    }

    func testRoutingTableWithIneffectualLinkStateInformation() {
        let routingTable = LinkStateRoutingTable(localNode: "Local")
        _ = routingTable.getRoutingTableChangeForNeighborUpdate("A", cost: 10)

        let routeChange = routingTable.getRoutingTableChangeForLinkStateInformationUpdate("B", neighbors: [(neighborId: "C", cost: 1), (neighborId: "D", cost: 1)])

        XCTAssert(routeChange.nowReachable.count == 0, "New node reachable")
        XCTAssert(routeChange.nowUnreachable.count == 0, "Node unreachable")
        XCTAssert(routeChange.routeChanged.count == 0, "Node unreachable")
    }

    func testRoutingTableWithEffectualLinkStateInformation() {
        let routingTable = LinkStateRoutingTable(localNode: "Local")
        _ = routingTable.getRoutingTableChangeForNeighborUpdate("A", cost: 10)
        _ = routingTable.getRoutingTableChangeForLinkStateInformationUpdate("B", neighbors: [(neighborId: "C", cost: 1), (neighborId: "D", cost: 1)])

        let routeChange = routingTable.getRoutingTableChangeForLinkStateInformationUpdate("A", neighbors: [(neighborId: "B", cost: 1)])

        XCTAssert(routeChange.nowReachable.count == 3, "New node reachable")
        XCTAssert(routeChange.nowUnreachable.count == 0, "Node unreachable")
        XCTAssert(routeChange.routeChanged.count == 0, "Node unreachable")

        var reachableDictionary: [String: (String, Double)] = [:]
        for (node, nextHop, cost) in routeChange.nowReachable { reachableDictionary[node] = (nextHop, cost) }
        XCTAssert(reachableDictionary["B"] == ("A", 11))
        XCTAssert(reachableDictionary["C"] == ("A", 12))
        XCTAssert(reachableDictionary["D"] == ("A", 12))
    }

    func testRoutingTableForRouteChanges() {
        let routingTable = LinkStateRoutingTable(localNode: "Local")
        _ = routingTable.getRoutingTableChangeForNeighborUpdate("A", cost: 10)
        _ = routingTable.getRoutingTableChangeForLinkStateInformationUpdate("B", neighbors: [(neighborId: "C", cost: 1), (neighborId: "D", cost: 1)])
        _ = routingTable.getRoutingTableChangeForLinkStateInformationUpdate("A", neighbors: [(neighborId: "B", cost: 1)])

        let routeChange = routingTable.getRoutingTableChangeForNeighborUpdate("A", cost: 5)

        XCTAssert(routeChange.nowReachable.count == 0, "New node reachable")
        XCTAssert(routeChange.nowUnreachable.count == 0, "Node unreachable")
        XCTAssert(routeChange.routeChanged.count == 4, "Node unreachable")
    }

    func testRoutingTableUnreachability() {
        let routingTable = LinkStateRoutingTable(localNode: "Local")
        _ = routingTable.getRoutingTableChangeForNeighborUpdate("A", cost: 10)
        _ = routingTable.getRoutingTableChangeForLinkStateInformationUpdate("A", neighbors: [(neighborId: "B", cost: 1)])

        let routeChange = routingTable.getRoutingTableChangeForNeighborRemoval("A")

        XCTAssert(routeChange.nowReachable.count == 0, "New node reachable")
        XCTAssert(routeChange.nowUnreachable.count == 2, "Node unreachable")
        XCTAssert(routeChange.routeChanged.count == 0, "Node unreachable")
    }
}
