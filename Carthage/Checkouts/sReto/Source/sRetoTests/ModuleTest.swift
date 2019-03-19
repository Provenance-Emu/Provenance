//
//  DummyModuleTest.swift
//  sReto
//
//  Created by Julian Asamer on 18/09/14.
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

class ModuleTest: XCTestCase {

    func testDummyModule() {
        let testInterface = DummyNetworkInterface(interfaceName: "test", cost: 1)
        let module1 = DummyModule(networkInterface: testInterface)
        let module2 = DummyModule(networkInterface: testInterface)
        self.testWithModules(module1: module1, module1Identifier: randomUUID(), module2: module2)
    }

    // Tests the WlanModule. Wlan needs to be active.
    func testWlanModule() {
        let module1 = WlanModule(type: "sRetoIntegrationTest", dispatchQueue: DispatchQueue.main)
        let module2 = WlanModule(type: "sRetoIntegrationTest", dispatchQueue: DispatchQueue.main)
        self.testWithModules(module1: module1, module1Identifier: randomUUID(), module2: module2)
    }

    // Tests the BluetoothModule. Bluetooth needs to be active.
    func testBluetoothModule() {
        let module1 = BluetoothModule(type: "sRetoIntegrationTest", dispatchQueue: DispatchQueue.main)
        let module2 = BluetoothModule(type: "sRetoIntegrationTest", dispatchQueue: DispatchQueue.main)
        self.testWithModules(module1: module1, module1Identifier: randomUUID(), module2: module2)
    }

    // For obvious reasons, this test can only succeed when the RemoteP2P server instance is freshly deployed locally (ie. it may not discover any other peers).
    func testRemoteModule() {
        let module1 = RemoteP2PModule(baseUrl: NSURL(string: "ws://localhost:8080")! as URL, dispatchQueue: DispatchQueue.main)
        let module2 = RemoteP2PModule(baseUrl: NSURL(string: "ws://localhost:8080")! as URL, dispatchQueue: DispatchQueue.main)
        self.testWithModules(module1: module1, module1Identifier: randomUUID(), module2: module2)
    }

    var refs: [AnyObject] = []

    func testWithModules(module1: Module, module1Identifier: UUID, module2: Module) {
        let startedAdvertisingExpectation = self.expectation(description: "advertising started")
        let startedBrowsingExpectation = self.expectation(description: "browsing started")
        let discoveredAddressExpectation = self.expectation(description: "address discovered")
        let connectionHandledExpectation = self.expectation(description: "connection handled")
        let connectionEstablishedExpectation = self.expectation(description: "connection established")
        let dataSentExpectation = self.expectation(description: "data sent")
        let dataReceivedExpectation = self.expectation(description: "data received")
        let connectionClosedExpectation = self.expectation(description: "connection closed")

        class OutConnectionDelegate: UnderlyingConnectionDelegate {
            let connectionEstablishedExpectation: XCTestExpectation
            let connectionClosedExpectation: XCTestExpectation
            let dataSentExpectation: XCTestExpectation

            init(connectionEstablishedExpectation: XCTestExpectation, connectionClosedExpectation: XCTestExpectation, dataSentExpectation: XCTestExpectation) {
                self.connectionEstablishedExpectation = connectionEstablishedExpectation
                self.connectionClosedExpectation = connectionClosedExpectation
                self.dataSentExpectation = dataSentExpectation
            }

            func didConnect(_ connection: UnderlyingConnection) {
                connectionEstablishedExpectation.fulfill()
                connection.writeData(TestData.generate(length: 100))
            }
            func didClose(_ connection: UnderlyingConnection, error: AnyObject?) {
                print("error: \(String(describing: error))")
                connectionClosedExpectation.fulfill()
            }
            func didReceiveData(_ connection: UnderlyingConnection, data: Data) {}
            func didSendData(_ connection: UnderlyingConnection) {
                dataSentExpectation.fulfill()
            }
        }

        class InConnectionDelegate: UnderlyingConnectionDelegate {
            let dataReceivedExpectation: XCTestExpectation

            init(dataReceivedExpectation: XCTestExpectation) {
                self.dataReceivedExpectation = dataReceivedExpectation
            }

            func didConnect(_ connection: UnderlyingConnection) {}
            func didClose(_ connection: UnderlyingConnection, error: AnyObject?) {}
            func didReceiveData(_ connection: UnderlyingConnection, data: Data) {
                XCTAssertTrue(TestData.verify(data: data, expectedLength: 100), "Incorrect data received.")
                dataReceivedExpectation.fulfill()
                connection.close()
            }
            func didSendData(_ connection: UnderlyingConnection) {}
        }

        class Module1Delegate: AdvertiserDelegate, BrowserDelegate {
            let connectionEstablishedExpectation: XCTestExpectation
            let startedAdvertisingExpectation: XCTestExpectation
            let startedBrowsingExpectation: XCTestExpectation
            let discoveredAddressExpectation: XCTestExpectation
            let outConnectionDelegate: OutConnectionDelegate
            let localIdentifier: UUID
            var connection: UnderlyingConnection?

            init(connectionEstablishedExpectation: XCTestExpectation, startedAdvertisingExpectation: XCTestExpectation, startedBrowsingExpectation: XCTestExpectation, discoveredAddressExpectation: XCTestExpectation, outConnectionDelegate: OutConnectionDelegate, localIdentifier: UUID) {
                self.connectionEstablishedExpectation = connectionEstablishedExpectation
                self.startedAdvertisingExpectation = startedAdvertisingExpectation
                self.startedBrowsingExpectation = startedBrowsingExpectation
                self.discoveredAddressExpectation = discoveredAddressExpectation
                self.outConnectionDelegate = outConnectionDelegate
                self.localIdentifier = localIdentifier
            }

            func didStartAdvertising(_ advertiser: Advertiser) {
                self.startedAdvertisingExpectation.fulfill()
            }
            func didStopAdvertising(_ advertiser: Advertiser) {}
            func handleConnection(_ advertiser: Advertiser, connection: UnderlyingConnection) {}

            func didStartBrowsing(_ browser: Browser) {
                self.startedBrowsingExpectation.fulfill()
            }
            func didStopBrowsing(_ browser: Browser) {}
            func didDiscoverAddress(_ browser: Browser, address: Address, identifier: UUID) {
                if localIdentifier == identifier { return }

                self.discoveredAddressExpectation.fulfill()

                let connection = address.createConnection()
                connection.delegate = outConnectionDelegate
                connection.connect()
                self.connection = connection
            }
            func didRemoveAddress(_ browser: Browser, address: Address, identifier: UUID) {}
        }

        class Module2Delegate: AdvertiserDelegate, BrowserDelegate {
            let connectionHandledExpectation: XCTestExpectation
            let inConnectionDelegate: InConnectionDelegate
            var connection: UnderlyingConnection?

            init(connectionHandledExpectation: XCTestExpectation, inConnectionDelegate: InConnectionDelegate) {
                self.connectionHandledExpectation = connectionHandledExpectation
                self.inConnectionDelegate = inConnectionDelegate
            }

            func didStartAdvertising(_ advertiser: Advertiser) {}
            func didStopAdvertising(_ advertiser: Advertiser) {}
            func handleConnection(_ advertiser: Advertiser, connection: UnderlyingConnection) {
                connectionHandledExpectation.fulfill()
                self.connection = connection
                connection.delegate = inConnectionDelegate
            }

            func didStartBrowsing(_ browser: Browser) {}
            func didStopBrowsing(_ browser: Browser) {}
            func didDiscoverAddress(_ browser: Browser, address: Address, identifier: UUID) {}
            func didRemoveAddress(_ browser: Browser, address: Address, identifier: UUID) {}
        }

        let outConnectionDelegate = OutConnectionDelegate(connectionEstablishedExpectation: connectionEstablishedExpectation, connectionClosedExpectation: connectionClosedExpectation, dataSentExpectation: dataSentExpectation)
        let module1Delegate = Module1Delegate(connectionEstablishedExpectation: connectionEstablishedExpectation, startedAdvertisingExpectation: startedAdvertisingExpectation, startedBrowsingExpectation: startedBrowsingExpectation, discoveredAddressExpectation: discoveredAddressExpectation, outConnectionDelegate: outConnectionDelegate, localIdentifier: module1Identifier)
        let module2Delegate = Module2Delegate(connectionHandledExpectation: connectionHandledExpectation, inConnectionDelegate: InConnectionDelegate(dataReceivedExpectation: dataReceivedExpectation))

        refs.append(module1)
        refs.append(module2)
        refs.append(module1Delegate)
        refs.append(module2Delegate)

        module1.advertiser.advertiserDelegate = module1Delegate
        module1.browser.browserDelegate = module1Delegate
        module2.advertiser.advertiserDelegate = module2Delegate
        module2.browser.browserDelegate = module2Delegate

        module1.advertiser.startAdvertising(module1Identifier)
        module1.browser.startBrowsing()
        module2.advertiser.startAdvertising(randomUUID())
        module2.browser.startBrowsing()

        self.waitForExpectations(timeout: 20, handler: {
            error in
            print("Finished waiting, error: \(String(describing: error))")
        })
    }
}
