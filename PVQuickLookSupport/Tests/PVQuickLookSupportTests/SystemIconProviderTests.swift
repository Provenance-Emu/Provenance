//
//  SystemIconProviderTests.swift
//  PVQuickLookSupportTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVQuickLookSupport

final class SystemIconProviderTests: XCTestCase {

    func testEmptyIdentifierReturnsDefault() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testUnknownIdentifierReturnsDefault() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.unknown")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testGameBoyReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.gb")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testGBAReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.gba")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testPSPReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.psp")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testNESReturnsGameController() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.nes")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testSNESReturnsGameController() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.snes")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testDOSReturnsDesktop() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.dos")
        XCTAssertEqual(icon, "desktopcomputer")
    }

    func testArcadeReturnsArcadeSymbol() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.arcade")
        XCTAssertEqual(icon, "arcade.stick.console.fill")
    }

    func testIsCaseInsensitive() {
        let lowerIcon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.gb")
        let upperIcon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.GB")
        XCTAssertEqual(lowerIcon, upperIcon)
    }

    func testNintendoDSReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.ds")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testNintendo3DSReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.3ds")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testFamicomDiskSystemDoesNotMatchDS() {
        // com.provenance.fds (Famicom Disk System) must NOT be treated as a handheld
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.fds")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testColecoVisionReturnsGameController() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.colecovision")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }
}
