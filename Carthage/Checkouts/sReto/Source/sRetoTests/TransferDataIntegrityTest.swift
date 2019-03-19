//
//  TransferDataIntegrityTest.swift
//  sReto
//
//  Created by Julian Asamer on 21/09/14.
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
* Note: These tests are currently very slow to Swift Dictionary's terrible performance when using debug settings.
*/
class TransferDataIntegrityTest: XCTestCase {

    override func setUp() {
        super.setUp()
        broadcastDelaySettings = (0.01, 0.05)
        reliabilityManagerDelays = (50, 50)
    }

    var connection: Connection?

    func testTransferDataIntegrityWithDirectConfiguration() {
        self.testTransferDataIntegrity(configuration: PeerConfiguration.directNeighborConfiguration())
    }

    func testTransferDataIntegrityWith2HopConfiguration() {
        self.testTransferDataIntegrity(configuration: PeerConfiguration.twoHopRoutedConfiguration())
    }

    func testTransferDataIntegrityWith2HopMulticastConfiguration() {
        self.testTransferDataIntegrity(configuration: PeerConfiguration.twoHopRoutedMulticastConfiguration())
    }

    func testTransferDataIntegrityWith2HopMulticastConfiguration2() {
        self.testTransferDataIntegrity(configuration: PeerConfiguration.twoHopRoutedMulticastConfiguration2())
    }

    func testTransferDataIntegrityWith4HopConfiguration() {
        self.testTransferDataIntegrity(configuration: PeerConfiguration.fourHopRoutedConfiguration())
    }

    func testTransferDataIntegrity(configuration: PeerConfiguration) {
        let dataLength = 10000

        var receivedDataExpectations: [UUID: XCTestExpectation] = [:]
        for peer in configuration.destinations {
            receivedDataExpectations[peer.identifier] = self.expectation(description: "\(peer.identifier) received correct data")
        }

        configuration.executeAfterDiscovery {
            for peer in configuration.destinations {
                peer.onConnection = {
                    (remotePeer: RemotePeer, connection: Connection) -> Void in
                    connection.onTransfer = {
                        connection, transfer in
                        transfer.onCompleteData = {
                            transfer, data in
                            if TestData.verify(data: data, expectedLength: dataLength) {
                                receivedDataExpectations[peer.identifier]!.fulfill()
                            }
                        }
                    }

                    return ()
                }
            }

            let destinations = Set(configuration.primaryPeer.peers.filter({ configuration.destinationIdentifiers.contains($0.identifier) }))
            self.connection = configuration.primaryPeer.connect(destinations)
            let data = TestData.generate(length: dataLength)
            self.connection!.send(data)
        }

        self.waitForExpectations(timeout: 60, handler: { (error) -> Void in
            print("success!")
        })
    }
}
