// RetroArchSystemDirectoryNameTests.swift
// PVPrimitivesTests
//
// Verifies SystemIdentifier.retroArchSystemDirectoryName returns the
// subdirectory each libretro core actually looks for via
// RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY. Companion to issue #3576.
//

import XCTest
import PVSystems
@testable import PVPrimitives

final class RetroArchSystemDirectoryNameTests: XCTestCase {

    // MARK: - libretro-aligned names

    func testPSPMapsToPPSSPP() {
        XCTAssertEqual(SystemIdentifier.PSP.retroArchSystemDirectoryName, "PPSSPP")
    }

    func testDreamcastMapsToLowercaseDC() {
        XCTAssertEqual(SystemIdentifier.Dreamcast.retroArchSystemDirectoryName, "dc")
    }

    func testGameCubeMapsToDolphinEmu() {
        XCTAssertEqual(SystemIdentifier.GameCube.retroArchSystemDirectoryName, "dolphin-emu")
    }

    func testWiiMapsToDolphinEmu() {
        XCTAssertEqual(SystemIdentifier.Wii.retroArchSystemDirectoryName, "dolphin-emu")
    }

    func testGameCubeAndWiiShareDolphinDir() {
        XCTAssertEqual(SystemIdentifier.GameCube.retroArchSystemDirectoryName,
                       SystemIdentifier.Wii.retroArchSystemDirectoryName,
                       "Dolphin uses one system dir for both GameCube and Wii")
    }

    func testDSMapsToMelonds() {
        XCTAssertEqual(SystemIdentifier.DS.retroArchSystemDirectoryName, "melonds")
    }

    func testN64MapsToMupen64PlusNext() {
        XCTAssertEqual(SystemIdentifier.N64.retroArchSystemDirectoryName, "Mupen64Plus-Next")
    }

    func testAtariSTMapsToHatari() {
        XCTAssertEqual(SystemIdentifier.AtariST.retroArchSystemDirectoryName, "hatari")
    }

    func testC64MapsToVice() {
        XCTAssertEqual(SystemIdentifier.C64.retroArchSystemDirectoryName, "vice")
    }

    func testMAMEMapsToMame() {
        XCTAssertEqual(SystemIdentifier.MAME.retroArchSystemDirectoryName, "mame")
    }

    func testCPSAndNeoGeoMapToFBNeo() {
        let fbneo = "fbneo"
        XCTAssertEqual(SystemIdentifier.CPS1.retroArchSystemDirectoryName, fbneo)
        XCTAssertEqual(SystemIdentifier.CPS2.retroArchSystemDirectoryName, fbneo)
        XCTAssertEqual(SystemIdentifier.CPS3.retroArchSystemDirectoryName, fbneo)
        XCTAssertEqual(SystemIdentifier.NeoGeo.retroArchSystemDirectoryName, fbneo)
        XCTAssertEqual(SystemIdentifier.NeoGeoCD.retroArchSystemDirectoryName, fbneo)
    }

    func testCDiMapsToSameCDI() {
        XCTAssertEqual(SystemIdentifier.CDi.retroArchSystemDirectoryName, "same_cdi")
    }

    // MARK: - Systems without a libretro fork in our matrix

    func testNESReturnsNil() {
        XCTAssertNil(SystemIdentifier.NES.retroArchSystemDirectoryName)
    }

    func testSNESReturnsNil() {
        XCTAssertNil(SystemIdentifier.SNES.retroArchSystemDirectoryName)
    }

    func testGBReturnsNil() {
        XCTAssertNil(SystemIdentifier.GB.retroArchSystemDirectoryName)
    }

    // MARK: - Divergence from systemDirectoryName

    func testPSPDivergesFromUserFacingName() {
        XCTAssertNotEqual(SystemIdentifier.PSP.systemDirectoryName,
                          SystemIdentifier.PSP.retroArchSystemDirectoryName,
                          "PSP must use PPSSPP for libretro lookups even though the user-facing dir is PSP")
    }

    func testDreamcastDivergesFromUserFacingName() {
        XCTAssertNotEqual(SystemIdentifier.Dreamcast.systemDirectoryName,
                          SystemIdentifier.Dreamcast.retroArchSystemDirectoryName)
    }
}
