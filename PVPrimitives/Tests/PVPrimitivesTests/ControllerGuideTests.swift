//
//  ControllerGuideTests.swift
//  PVPrimitivesTests
//
//  Created by Provenance Emu on 2026-03-05.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVPrimitives

final class ControllerGuideInfoTests: XCTestCase {

    // MARK: - ControllerType

    func testControllerTypeDisplayNames() {
        XCTAssertEqual(ControllerType.mfi.displayName, "MFi")
        XCTAssertEqual(ControllerType.dualShock4.displayName, "DualShock 4")
        XCTAssertEqual(ControllerType.dualSense.displayName, "DualSense")
        XCTAssertEqual(ControllerType.xbox.displayName, "Xbox Wireless")
        XCTAssertEqual(ControllerType.switchPro.displayName, "Nintendo Switch Pro")
        XCTAssertEqual(ControllerType.iCade.displayName, "iCade")
        XCTAssertEqual(ControllerType.siriRemote.displayName, "Siri Remote")
        XCTAssertEqual(ControllerType.keyboard.displayName, "Keyboard")
    }

    func testModernControllerTypes() {
        XCTAssertTrue(ControllerType.dualSense.isModern)
        XCTAssertTrue(ControllerType.xbox.isModern)
        XCTAssertTrue(ControllerType.switchPro.isModern)
        XCTAssertTrue(ControllerType.dualShock4.isModern)
    }

    func testLegacyControllerTypes() {
        XCTAssertFalse(ControllerType.mfi.isModern)
        XCTAssertFalse(ControllerType.iCade.isModern)
        XCTAssertFalse(ControllerType.siriRemote.isModern)
        XCTAssertFalse(ControllerType.keyboard.isModern)
    }

    // MARK: - ControllerPlatformSupport

    func testPlatformSupportIOS() {
        let support: ControllerPlatformSupport = .iOS
        XCTAssertTrue(support.contains(.iOS))
        XCTAssertFalse(support.contains(.tvOS))
    }

    func testPlatformSupportTVOS() {
        let support: ControllerPlatformSupport = .tvOS
        XCTAssertFalse(support.contains(.iOS))
        XCTAssertTrue(support.contains(.tvOS))
    }

    func testPlatformSupportAll() {
        let support: ControllerPlatformSupport = .all
        XCTAssertTrue(support.contains(.iOS))
        XCTAssertTrue(support.contains(.tvOS))
    }

    // MARK: - ControllerGuideInfo init & id

    func testControllerGuideInfoID() {
        let info = ControllerGuideInfo(
            name: "My Test Controller",
            controllerType: .mfi,
            supportedPlatforms: .all,
            pairingInstructions: ["Step 1"],
            featureNotes: ["Note 1"],
            isRecommended: false
        )
        XCTAssertEqual(info.id, "my-test-controller")
    }

    func testControllerGuideInfoEquality() {
        let a = ControllerGuideInfo(
            name: "Controller A",
            controllerType: .xbox,
            supportedPlatforms: .all,
            pairingInstructions: ["Step 1"],
            featureNotes: [],
            isRecommended: true
        )
        let b = ControllerGuideInfo(
            name: "Controller A",
            controllerType: .xbox,
            supportedPlatforms: .all,
            pairingInstructions: ["Step 1"],
            featureNotes: [],
            isRecommended: true
        )
        XCTAssertEqual(a, b)
    }

    func testControllerGuideInfoPlatformConvenience() {
        let iOSOnly = ControllerGuideInfo(
            name: "iOS Controller",
            controllerType: .iCade,
            supportedPlatforms: .iOS,
            pairingInstructions: [],
            featureNotes: [],
            isRecommended: false
        )
        XCTAssertTrue(iOSOnly.supportsIOS)
        XCTAssertFalse(iOSOnly.supportsTVOS)

        let tvOSOnly = ControllerGuideInfo(
            name: "tvOS Controller",
            controllerType: .siriRemote,
            supportedPlatforms: .tvOS,
            pairingInstructions: [],
            featureNotes: [],
            isRecommended: false
        )
        XCTAssertFalse(tvOSOnly.supportsIOS)
        XCTAssertTrue(tvOSOnly.supportsTVOS)
    }
}

// MARK: - ControllerCatalog tests

final class ControllerCatalogTests: XCTestCase {

    func testCatalogIsNotEmpty() {
        XCTAssertFalse(ControllerCatalog.all.isEmpty)
    }

    func testCatalogContainsExpectedControllers() {
        let names = ControllerCatalog.all.map { $0.name }
        XCTAssertTrue(names.contains("DualSense Wireless Controller"))
        XCTAssertTrue(names.contains("Xbox Wireless Controller"))
        XCTAssertTrue(names.contains("Nintendo Switch Pro Controller"))
        XCTAssertTrue(names.contains("DualShock 4 Wireless Controller"))
        XCTAssertTrue(names.contains("MFi Game Controller"))
        XCTAssertTrue(names.contains("Siri Remote"))
        XCTAssertTrue(names.contains("iCade Arcade Cabinet"))
        XCTAssertTrue(names.contains("Bluetooth / USB Keyboard"))
    }

    func testRecommendedControllersAreModernTypes() {
        for controller in ControllerCatalog.recommendedControllers {
            XCTAssertTrue(controller.controllerType.isModern,
                          "\(controller.name) is recommended but its type is not modern")
        }
    }

    func testSiriRemoteIsNotRecommended() {
        XCTAssertFalse(ControllerCatalog.siriRemote.isRecommended)
    }

    func testIcadeIsNotRecommended() {
        XCTAssertFalse(ControllerCatalog.iCade.isRecommended)
    }

    func testSiriRemoteIsTVOSOnly() {
        XCTAssertFalse(ControllerCatalog.siriRemote.supportsIOS)
        XCTAssertTrue(ControllerCatalog.siriRemote.supportsTVOS)
    }

    func testIcadeIsIOSOnly() {
        XCTAssertTrue(ControllerCatalog.iCade.supportsIOS)
        XCTAssertFalse(ControllerCatalog.iCade.supportsTVOS)
    }

    func testiOSControllersDoNotIncludeSiriRemote() {
        let ids = ControllerCatalog.iOSControllers.map { $0.id }
        XCTAssertFalse(ids.contains(ControllerCatalog.siriRemote.id))
    }

    func testtvOSControllersDoNotIncludeIcade() {
        let ids = ControllerCatalog.tvOSControllers.map { $0.id }
        XCTAssertFalse(ids.contains(ControllerCatalog.iCade.id))
    }

    func testLookupByID() {
        let dualsense = ControllerCatalog.dualSense
        let found = ControllerCatalog.controller(withID: dualsense.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, dualsense.name)
    }

    func testLookupByUnknownIDReturnsNil() {
        XCTAssertNil(ControllerCatalog.controller(withID: "nonexistent-controller"))
    }

    func testKeyboardSupportsAllPlatforms() {
        XCTAssertTrue(ControllerCatalog.keyboard.supportsIOS)
        XCTAssertTrue(ControllerCatalog.keyboard.supportsTVOS)
    }

    func testKeyboardIsNotRecommended() {
        XCTAssertFalse(ControllerCatalog.keyboard.isRecommended)
    }

    func testByTypeGroupingCoversAllControllers() {
        let grouped = ControllerCatalog.byType
        let totalInGroups = grouped.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalInGroups, ControllerCatalog.all.count)
    }

    func testAllControllersHaveNonEmptyPairingInstructions() {
        for controller in ControllerCatalog.all {
            XCTAssertFalse(controller.pairingInstructions.isEmpty,
                           "\(controller.name) has no pairing instructions")
        }
    }

    func testAllControllersHaveNonEmptyFeatureNotes() {
        for controller in ControllerCatalog.all {
            XCTAssertFalse(controller.featureNotes.isEmpty,
                           "\(controller.name) has no feature notes")
        }
    }

    func testModernControllersHaveDualAnalogStickMention() {
        let modernControllers = ControllerCatalog.all.filter { $0.controllerType.isModern }
        for controller in modernControllers {
            let allText = (controller.featureNotes + controller.pairingInstructions).joined()
            let hasAnalogMention = allText.localizedCaseInsensitiveContains("analog")
            XCTAssertTrue(hasAnalogMention,
                          "\(controller.name) feature notes don't mention analog sticks")
        }
    }

    func testSiriRemoteMentionsMenuButtonLimitation() {
        let allText = ControllerCatalog.siriRemote.featureNotes.joined()
        XCTAssertTrue(allText.localizedCaseInsensitiveContains("menu") ||
                      allText.localizedCaseInsensitiveContains("reserved"),
                      "Siri Remote feature notes should mention Menu button reservation")
    }
}
