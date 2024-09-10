//
//  PVLibraryTests.swift
//  PVLibraryTests
//
//  Created by Joseph Mattiello on 7/24/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

@testable import PVLibrary
import XCTest

class PVLibraryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try! RomDatabase.initDefaultDatabase()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}
