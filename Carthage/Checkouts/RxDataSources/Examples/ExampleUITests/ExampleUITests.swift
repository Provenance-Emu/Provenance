//
//  ExampleUITests.swift
//  ExampleUITests
//
//  Created by Krunoslav Zaher on 1/1/16.
//  Copyright © 2016 kzaher. All rights reserved.
//
import XCTest
import CoreLocation

class ExampleUITests: XCTestCase {

    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        XCUIApplication().launch()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testExample() {
        XCUIApplication().tables.element(boundBy: 0).cells.staticTexts["Randomize Example"].tap()

        let time: TimeInterval = 120.0

        RunLoop.current.run(until: Date().addingTimeInterval(time))
    }
    
}
