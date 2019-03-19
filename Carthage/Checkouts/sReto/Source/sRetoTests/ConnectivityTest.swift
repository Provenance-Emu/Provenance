//
//  ConnectivityTest.swift
//  sReto
//
//  Created by Julian Asamer on 20/09/14.
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

/**
* Note: At this time, these tests are extremely slow in Debug settings due to Swift dictionary's terrible performance.
*/
class ConnectivityTest: XCTestCase {

    override func setUp() {
        super.setUp()
        broadcastDelaySettings = (0.01, 0.05)
        reliabilityManagerDelays = (50, 50)
    }

    func testDirectNeighborConnectivity() {
        testConnectivity(configuration: PeerConfiguration.directNeighborConfiguration())
    }
    func testTwoHopConnectivity() {
        testConnectivity(configuration: PeerConfiguration.twoHopRoutedConfiguration())
    }
    func testTwoHopMulticastConnectivity() {
        testConnectivity(configuration: PeerConfiguration.twoHopRoutedMulticastConfiguration())
    }
    func testTwoHopMulticastConnectivity2() {
        testConnectivity(configuration: PeerConfiguration.twoHopRoutedMulticastConfiguration2())
    }
    func testFourHopConnectivity() {
        testConnectivity(configuration: PeerConfiguration.fourHopRoutedConfiguration())
    }

    func testConnectivity(configuration: PeerConfiguration) {
        let activePeers = [configuration.primaryPeer]+configuration.destinations

        var onConnectExpectations: [UUID: XCTestExpectation] = [:]
        var onCloseExpectations: [UUID: XCTestExpectation] = [:]
        for peer in activePeers {
            onConnectExpectations[peer.identifier] = self.expectation(description: "\(peer.identifier) received on connect call")
            onCloseExpectations[peer.identifier] = self.expectation(description: "\(peer.identifier) received on close call")
        }

        configuration.executeAfterDiscovery {
            print("all reachable!")
            for peer in configuration.destinations {
                peer.onConnection = {
                    source, connection in
                    connection.onConnect = {
                        c in
                        onConnectExpectations[peer.identifier]?.fulfill()
                        onConnectExpectations[peer.identifier] = nil

                        if onConnectExpectations.count == 0 {
                            connection.close()
                        }
                    }
                    connection.onClose = {
                        _ in
                        print("on close: \(peer.identifier)")
                        onCloseExpectations[peer.identifier]?.fulfill()
                    }
                }
            }

            let connection = configuration.primaryPeer.connect(Set(configuration.primaryPeer.peers.filter({ configuration.destinationIdentifiers.contains($0.identifier) })))

            connection.onConnect = {
                connection in
                onConnectExpectations[configuration.primaryPeer.identifier]?.fulfill()
                onConnectExpectations[configuration.primaryPeer.identifier] = nil
                if onConnectExpectations.count == 0 {
                    connection.close()
                }
            }
            connection.onClose = {
                _ in
                onCloseExpectations[configuration.primaryPeer.identifier]?.fulfill()
                ()
            }
        }

        self.waitForExpectations(timeout: 60, handler: {
            error in print("success!")
        })
    }
}
