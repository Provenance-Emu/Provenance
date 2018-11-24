import XCTest

class UIImagePickerControllerTests: XCTestCase {
    func test_fulfills_with_data() {
        let app = XCUIApplication()
        let tablesQuery = app.tables
        tablesQuery.staticTexts["1"].tap()
        tablesQuery.children(matching: .cell).element(boundBy: 1).tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 0).tap()

        XCTAssertTrue(value)
    }

    var toggle: XCUIElement {
        // calling this ensures that any other ViewController has dismissed
        // as a side-effect since otherwise the switch won't be found
        return XCUIApplication().tables.switches.element
    }

    var value: Bool {
        return (toggle.value as! String) == "1"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
        XCTAssertFalse(value)
    }

}
