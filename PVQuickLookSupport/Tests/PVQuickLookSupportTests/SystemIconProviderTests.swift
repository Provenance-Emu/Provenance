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

    func testMAMEReturnsArcade() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.mame")
        XCTAssertEqual(icon, "arcade.stick.console.fill")
    }

    func testNeoGeoReturnsArcade() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.neogeo")
        XCTAssertEqual(icon, "arcade.stick.console.fill")
    }

    func testCPS1ReturnsArcade() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.cps1")
        XCTAssertEqual(icon, "arcade.stick.console.fill")
    }

    func testAtariSTReturnsDesktop() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.atarist")
        XCTAssertEqual(icon, "desktopcomputer")
    }

    func testSegaGenesisReturnsGameController() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.genesis")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testPlayStationReturnsGameController() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.psx")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testGameGearReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.gamegear")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testWonderSwanReturnsHandheld() {
        // WonderSwan uses short-form ".ws" identifier — verify the suffix match works.
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.ws")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testWonderSwanColorReturnsHandheld() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.wsc")
        XCTAssertEqual(icon, "handheld.fill")
    }

    func testPS3ReturnsGameController() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.ps3")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testCPS2ReturnsArcade() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.cps2")
        XCTAssertEqual(icon, "arcade.stick.console.fill")
    }

    func testCPS3ReturnsArcade() {
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.cps3")
        XCTAssertEqual(icon, "arcade.stick.console.fill")
    }

    func testGenesisDoesNotMatchNESCase() {
        // "genesis" contains "nes" as a substring (g-e-n-e-s-i-s); ensure it
        // resolves to a game-controller icon via the Genesis case, not NES.
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.genesis")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }

    func testTIC80ReturnsDefault() {
        // TIC-80 is a fantasy computer — falls back to the generic game-controller icon.
        let icon = SystemIconProvider.sfSymbolName(forSystemIdentifier: "com.provenance.tic80")
        XCTAssertEqual(icon, "gamecontroller.fill")
    }
}
