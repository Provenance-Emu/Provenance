//
//  ExampleUITests.swift
//  ExampleUITests
//
//  Created by Ben on 14/08/2017.
//  Copyright © 2017 bcylin.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest

internal final class ExampleUITests: XCTestCase {

  private lazy var app: XCUIApplication = XCUIApplication()

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app.launch()
  }

  func testInteractions() {
    app.tables.staticTexts["Use default cell types"].tap()

    let tables = XCUIApplication().tables
    let existance = NSPredicate(format: "exists == true")

    tables.switches["Setting 1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Setting 1 = false"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.switches["Setting 1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Setting 1 = true"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.switches["Setting 2"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Setting 2 = true"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.switches["Setting 2"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Setting 2 = false"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.staticTexts["Tap action"].tap()
    addUIInterruptionMonitor(withDescription: "Action Triggered") {
      let button = $0.buttons["OK"]
      if button.exists {
        button.tap()
        return true
      }
      return false
    }

    tables.staticTexts[".value1"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["CellStyle.value1 is selected"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.staticTexts["Option 1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Option 1 is deselected"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)
    tables.staticTexts["Option 2"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Option 2 is selected"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)
    tables.staticTexts["Option 3"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["Option 3 is selected"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)
  }

  func testCustomization() {
    app.tables.staticTexts["Use custom cell types"].tap()

    let tables = XCUIApplication().tables
    let existance = NSPredicate(format: "exists == true")

    tables.switches["0-0"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["CustomSwitchCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.switches["0-1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["SwitchCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["1-0"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["CustomTapActionCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["1-1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["TapActionCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["2-0"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["UITableViewCell.default"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["2-1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["CustomCell.subtitle"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["2-2"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["UITableViewCell.value1"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["2-3"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["CustomCell.value2"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["3-0"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["UITableViewCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["3-1"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["UITableViewCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    tables.cells["3-2"].tap()
    expectation(for: existance, evaluatedWith: tables.staticTexts["CustomOptionCell"], handler: nil)
    waitForExpectations(timeout: 5, handler: nil)
  }

}
