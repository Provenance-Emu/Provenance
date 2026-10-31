import Foundation
import XCTest
@testable import PVUIBase

final class ImportDocumentSelectionTests: XCTestCase {
    func testPickerCanOpenWithoutAnImportStatusDelegate() {
        var selection = ImportDocumentSelection()

        selection.begin()

        XCTAssertTrue(selection.isPresented)
        XCTAssertNil(selection.errorMessage)
    }

    func testSelectionReturnsEveryDocumentInOrderAndClosesPicker() {
        var selection = ImportDocumentSelection()
        let urls = [URL(fileURLWithPath: "/picked/game.zip"), URL(fileURLWithPath: "/picked/game.chd")]
        selection.begin()

        XCTAssertEqual(selection.complete(.success(urls)), urls)
        XCTAssertFalse(selection.isPresented)
        XCTAssertNil(selection.errorMessage)
    }

    func testEmptySelectionDoesNotQueueDocuments() {
        var selection = ImportDocumentSelection()
        selection.begin()

        XCTAssertTrue(selection.complete(.success([])).isEmpty)
        XCTAssertFalse(selection.isPresented)
        XCTAssertNil(selection.errorMessage)
    }

    func testCancellationDoesNotReportAnImportError() {
        var selection = ImportDocumentSelection()
        selection.begin()

        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        XCTAssertTrue(selection.complete(.failure(error)).isEmpty)
        XCTAssertFalse(selection.isPresented)
        XCTAssertNil(selection.errorMessage)
    }

    func testFailureCanBeRetriedWithoutKeepingThePreviousError() {
        var selection = ImportDocumentSelection()
        selection.begin()
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError,
                            userInfo: [NSLocalizedDescriptionKey: "The file provider refused access."])

        XCTAssertTrue(selection.complete(.failure(error)).isEmpty)
        XCTAssertEqual(selection.errorMessage, error.localizedDescription)
        XCTAssertFalse(selection.isPresented)

        selection.begin()

        XCTAssertTrue(selection.isPresented)
        XCTAssertNil(selection.errorMessage)
        let urls = [URL(fileURLWithPath: "/picked/another.zip")]
        XCTAssertEqual(selection.complete(.success(urls)), urls)
        XCTAssertFalse(selection.isPresented)
    }
}
