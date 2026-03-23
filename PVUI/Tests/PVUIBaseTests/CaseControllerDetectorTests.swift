import XCTest
@testable import PVUIBase

final class CaseControllerDetectorTests: XCTestCase {

    // MARK: - knownLayouts sanity

    func testKnownLayoutsNotEmpty() {
        XCTAssertFalse(CaseControllerDetector.knownLayouts.isEmpty)
    }

    func testEveryLayoutHasName() {
        for layout in CaseControllerDetector.knownLayouts {
            XCTAssertFalse(layout.name.isEmpty, "Layout has empty name")
        }
    }

    func testEveryLayoutHasPositiveButtonCount() {
        for layout in CaseControllerDetector.knownLayouts {
            XCTAssertGreaterThan(layout.buttonCount, 0, "\(layout.name) has zero buttonCount")
        }
    }

    // MARK: - isSmart

    func testGameSirIsSmart() throws {
        let layout = try XCTUnwrap(
            CaseControllerDetector.knownLayouts.first { $0.name == "GameSir Pocket Taco" },
            "Expected to find GameSir Pocket Taco layout in knownLayouts"
        )
        XCTAssertTrue(layout.isSmart)
    }

    func testSoolraIsSmart() throws {
        let layout = try XCTUnwrap(
            CaseControllerDetector.knownLayouts.first { $0.name == "Soolra Controller" },
            "Expected to find Soolra Controller layout in knownLayouts"
        )
        XCTAssertTrue(layout.isSmart)
    }

    func testBuppinIsNotSmart() throws {
        let layout = try XCTUnwrap(
            CaseControllerDetector.knownLayouts.first { $0.name == "Buppin Case" },
            "Expected to find Buppin Case layout in knownLayouts"
        )
        XCTAssertFalse(layout.isSmart, "Buppin is a passive case — it should NOT be smart")
    }

    // MARK: - casesCompatibleWithSkin

    func testBuppinSkinIdentifierDetected() {
        let layouts = CaseControllerDetector.casesCompatibleWithSkin("com.buppin.case")
        XCTAssertFalse(layouts.isEmpty, "Expected at least one layout for com.buppin.case")
        XCTAssertEqual(layouts.first?.name, "Buppin Case")
    }

    func testGameSirSkinIdentifierDetected() {
        let layouts = CaseControllerDetector.casesCompatibleWithSkin("com.gamesir.pockettaco")
        XCTAssertFalse(layouts.isEmpty)
        XCTAssertEqual(layouts.first?.name, "GameSir Pocket Taco")
    }

    func testSkinIdentifierMatchIsCaseInsensitive() {
        let layouts = CaseControllerDetector.casesCompatibleWithSkin("COM.BUPPIN.CASE")
        XCTAssertFalse(layouts.isEmpty, "Skin-ID matching should be case-insensitive")
    }

    func testUnknownSkinIdentifierReturnsEmpty() {
        let layouts = CaseControllerDetector.casesCompatibleWithSkin("com.unknown.skin.abc123")
        XCTAssertTrue(layouts.isEmpty)
    }

    func testCaseLayoutForSkinIdentifierConvenience() {
        let layout = CaseControllerDetector.caseLayout(forSkinIdentifier: "com.soolra.controller")
        XCTAssertNotNil(layout)
        XCTAssertEqual(layout?.name, "Soolra Controller")
    }

    // MARK: - layoutByFuzzyVendorName

    func testFuzzyVendorMatchPartialName() {
        let layout = CaseControllerDetector.layoutByFuzzyVendorName("Taco")
        XCTAssertNotNil(layout, "Partial vendor name 'Taco' should match GameSir Pocket Taco")
        XCTAssertEqual(layout?.name, "GameSir Pocket Taco")
    }

    func testFuzzyVendorMatchCaseInsensitive() {
        let layout = CaseControllerDetector.layoutByFuzzyVendorName("soolra")
        XCTAssertNotNil(layout)
        XCTAssertEqual(layout?.name, "Soolra Controller")
    }

    func testFuzzyVendorNoMatchForUnknown() {
        let layout = CaseControllerDetector.layoutByFuzzyVendorName("XYZUNKNOWNCONTROLLER")
        XCTAssertNil(layout)
    }

    // MARK: - notifyIfCaseSkin posts notification

    func testNotifyIfCaseSkinPostsNotification() {
        let expectation = XCTestExpectation(description: "PVPhysicalCaseSkinDetected posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .PVPhysicalCaseSkinDetected,
            object: nil,
            queue: .main
        ) { note in
            let layout = note.userInfo?[CaseControllerDetectorKeys.layout] as? PhysicalCaseLayout
            XCTAssertNotNil(layout)
            XCTAssertEqual(layout?.name, "Buppin Case")
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let layouts = CaseControllerDetector.notifyIfCaseSkin("com.buppin.case")
        XCTAssertFalse(layouts.isEmpty)
        wait(for: [expectation], timeout: 1.0)
    }

    func testNotifyIfCaseSkinUnknownDoesNotPost() {
        let expectation = XCTNSNotificationExpectation(name: .PVPhysicalCaseSkinDetected)
        expectation.isInverted = true

        let layouts = CaseControllerDetector.notifyIfCaseSkin("com.nobody.unknown")
        XCTAssertTrue(layouts.isEmpty)

        wait(for: [expectation], timeout: 0.1)
    }
}
