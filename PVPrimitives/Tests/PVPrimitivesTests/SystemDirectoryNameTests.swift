// SystemDirectoryNameTests.swift
// PVPrimitivesTests
//
// Created by Provenance Emu on 2026-03-28.
// Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
import PVSystems
@testable import PVPrimitives

final class SystemDirectoryNameTests: XCTestCase {

    // MARK: - Pre-existing mappings (regression)

    func testPSPDirectory() {
        XCTAssertEqual(SystemIdentifier.PSP.systemDirectoryName, "PSP")
    }

    func testNDSDirectory() {
        XCTAssertEqual(SystemIdentifier.DS.systemDirectoryName, "NDS")
    }

    func test3DSDirectory() {
        XCTAssertEqual(SystemIdentifier._3DS.systemDirectoryName, "3DS")
    }

    func testDreamcastDirectory() {
        XCTAssertEqual(SystemIdentifier.Dreamcast.systemDirectoryName, "DC")
    }

    func testN64Directory() {
        XCTAssertEqual(SystemIdentifier.N64.systemDirectoryName, "N64")
    }

    func testGameCubeDirectory() {
        XCTAssertEqual(SystemIdentifier.GameCube.systemDirectoryName, "GC")
    }

    func testWiiDirectory() {
        XCTAssertEqual(SystemIdentifier.Wii.systemDirectoryName, "Wii")
    }

    func testAtariSTDirectory() {
        XCTAssertEqual(SystemIdentifier.AtariST.systemDirectoryName, "AtariST")
    }

    func testDOSDirectory() {
        XCTAssertEqual(SystemIdentifier.DOS.systemDirectoryName, "DOS")
    }

    func testPS2Directory() {
        XCTAssertEqual(SystemIdentifier.PS2.systemDirectoryName, "PS2")
    }

    func testSaturnDirectory() {
        XCTAssertEqual(SystemIdentifier.Saturn.systemDirectoryName, "Saturn")
    }

    // MARK: - New mappings added in #3580

    func testMAMEDirectory() {
        XCTAssertEqual(SystemIdentifier.MAME.systemDirectoryName, "MAME")
    }

    func testNeoGeoDirectory() {
        XCTAssertEqual(SystemIdentifier.NeoGeo.systemDirectoryName, "NeoGeo")
    }

    func testNeoGeoCDDirectory() {
        XCTAssertEqual(SystemIdentifier.NeoGeoCD.systemDirectoryName, "NeoGeoCD")
    }

    func testCDiDirectory() {
        XCTAssertEqual(SystemIdentifier.CDi.systemDirectoryName, "CDi")
    }

    func testMacintoshDirectory() {
        XCTAssertEqual(SystemIdentifier.Macintosh.systemDirectoryName, "Mac")
    }

    func testPC98Directory() {
        XCTAssertEqual(SystemIdentifier.PC98.systemDirectoryName, "PC98")
    }

    func testMSXDirectory() {
        XCTAssertEqual(SystemIdentifier.MSX.systemDirectoryName, "MSX")
    }

    func testMSX2Directory() {
        // MSX2 shares the MSX/ directory with MSX
        XCTAssertEqual(SystemIdentifier.MSX2.systemDirectoryName, "MSX")
    }

    func testC64Directory() {
        XCTAssertEqual(SystemIdentifier.C64.systemDirectoryName, "C64")
    }

    func testEP128Directory() {
        XCTAssertEqual(SystemIdentifier.EP128.systemDirectoryName, "EP128")
    }

    // MARK: - Systems with no dedicated directory (nil)

    func testNESReturnsNil() {
        XCTAssertNil(SystemIdentifier.NES.systemDirectoryName)
    }

    func testSNESReturnsNil() {
        XCTAssertNil(SystemIdentifier.SNES.systemDirectoryName)
    }

    func testGBReturnsNil() {
        XCTAssertNil(SystemIdentifier.GB.systemDirectoryName)
    }

    func testRetroArchReturnsNil() {
        XCTAssertNil(SystemIdentifier.RetroArch.systemDirectoryName)
    }

    // MARK: - MSX/MSX2 shared directory invariant

    func testMSXAndMSX2ShareDirectory() {
        XCTAssertEqual(SystemIdentifier.MSX.systemDirectoryName,
                       SystemIdentifier.MSX2.systemDirectoryName,
                       "MSX and MSX2 must share the same system directory")
    }
}
