import CoreGraphics
import SwiftUI
import XCTest
@testable import PVUIBase

final class AdaptiveWindowTests: XCTestCase {
    // Sizes measured on the iPhone Duo simulator (iOS 27.1).
    private let folded = CGSize(width: 466, height: 678)
    private let unfoldedWide = CGSize(width: 951, height: 669)
    private let unfoldedTall = CGSize(width: 669, height: 951)

    func testOrdinaryPhonesStayPhoneInEveryOrientation() {
        // Portrait, landscape, and a Max phone in landscape (regular width, compact height).
        let sizeClasses: [(UserInterfaceSizeClass?, UserInterfaceSizeClass?)] = [
            (.compact, .regular), (.compact, .compact), (.regular, .compact), (nil, nil)
        ]
        for (horizontal, vertical) in sizeClasses {
            XCTAssertEqual(
                AdaptiveWindowClass.resolve(isPhoneIdiom: true, horizontal: horizontal, vertical: vertical), .phone)
        }
    }

    func testUnfoldedPhoneIsExpanded() {
        XCTAssertEqual(
            AdaptiveWindowClass.resolve(isPhoneIdiom: true, horizontal: .regular, vertical: .regular), .expandedPhone)
    }

    func testOtherIdiomsAreTabletWhateverTheSizeClasses() {
        for horizontal in [UserInterfaceSizeClass.compact, .regular] {
            XCTAssertEqual(
                AdaptiveWindowClass.resolve(isPhoneIdiom: false, horizontal: horizontal, vertical: .regular), .tablet)
        }
    }

    func testShapeFollowsTheWindowNotTheDevice() {
        XCTAssertEqual(AdaptiveWindowShape.resolve(folded), .portrait)
        XCTAssertEqual(AdaptiveWindowShape.resolve(unfoldedWide), .landscape)
        XCTAssertEqual(AdaptiveWindowShape.resolve(unfoldedTall), .portrait)
        XCTAssertNil(AdaptiveWindowShape.resolve(.zero))
    }

    func testCompactPhoneChromeOnlyOnAnUprightPhoneWindow() {
        XCTAssertTrue(AdaptiveWindowRules.usesCompactPhoneChrome(windowClass: .phone, vertical: .regular))
        XCTAssertFalse(AdaptiveWindowRules.usesCompactPhoneChrome(windowClass: .phone, vertical: .compact))
        XCTAssertFalse(AdaptiveWindowRules.usesCompactPhoneChrome(windowClass: .expandedPhone, vertical: .regular))
        XCTAssertFalse(AdaptiveWindowRules.usesCompactPhoneChrome(windowClass: .tablet, vertical: .regular))
    }

    func testSidebarPinsOnIPadAsBefore() {
        XCTAssertTrue(AdaptiveWindowRules.pinsLibrarySidebar(windowClass: .tablet, horizontal: .regular, width: 744))
        XCTAssertFalse(AdaptiveWindowRules.pinsLibrarySidebar(windowClass: .tablet, horizontal: .compact, width: 375))
    }

    func testSidebarNeverPinsOnAPhoneSizedWindow() {
        XCTAssertFalse(AdaptiveWindowRules.pinsLibrarySidebar(windowClass: .phone, horizontal: .compact, width: folded.width))
        // A Max phone in landscape is regular width and wider than the pin threshold.
        XCTAssertFalse(AdaptiveWindowRules.pinsLibrarySidebar(windowClass: .phone, horizontal: .regular, width: 956))
    }

    func testUnfoldedPhonePinsOnlyWhenWide() {
        XCTAssertTrue(AdaptiveWindowRules.pinsLibrarySidebar(
            windowClass: .expandedPhone, horizontal: .regular, width: unfoldedWide.width))
        XCTAssertFalse(AdaptiveWindowRules.pinsLibrarySidebar(
            windowClass: .expandedPhone, horizontal: .regular, width: unfoldedTall.width))
    }
}
