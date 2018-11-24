import XCTest

class UIImagePickerControllerTests: XCTestCase {
    var button: XCUIElement {
        // calling this ensures that any other ViewController has dismissed
        // as a side-effect since otherwise the switch won't be found
        return XCUIApplication().tables.buttons.element
    }

    var value: Bool {
        return button.isEnabled
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
        XCTAssertFalse(value)
    }

#if !os(tvOS)
    // this test works locally but not on travis
    // attempting to detect Travis and early-return did not work
    func test_rejects_when_cancelled() {
        let app = XCUIApplication()
        let table = app.tables
        table.cells.staticTexts["1"].tap()
        table.cells.element(boundBy: 0).tap()
        app.navigationBars.buttons["Cancel"].tap()

        XCTAssertTrue(value)
    }

    // following two don't seem to work since Xcode 8.1
    // The UI-Testing infrastructure cannot “see” the image picking UI
    // And… trying to re-record by hand fails.

    func test_fulfills_with_edited_image() {
        let app = XCUIApplication()
        app.tables.cells.staticTexts["2"].tap()
        app.tables.children(matching: .cell).element(boundBy: 1).tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 0).tap()

        // XCUITesting fails to tap this button, hence this test disabled
        app.buttons["Choose"].tap()

        XCTAssertTrue(value)
    }

    func test_fulfills_with_image() {
        let app = XCUIApplication()
        let tablesQuery = app.tables
        tablesQuery.staticTexts["3"].tap()
        tablesQuery.children(matching: .cell).element(boundBy: 1).tap()

        app.collectionViews.children(matching: .cell).element(boundBy: 0).tap()

        XCTAssertTrue(value)
    }
#endif
}
