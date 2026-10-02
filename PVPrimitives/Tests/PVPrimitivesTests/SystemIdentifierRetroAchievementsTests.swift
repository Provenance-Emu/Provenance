// SystemIdentifierRetroAchievementsTests.swift
// PVPrimitivesTests
//
// Unit tests for `SystemIdentifier.retroAchievementsConsoleID` and
// `retroAchievementsHashesArchiveDirectly`.

import XCTest
import PVSystems

final class SystemIdentifierRetroAchievementsTests: XCTestCase {

    private let arcadeSystems: Set<SystemIdentifier> = [
        .MAME, .CPS1, .CPS2, .CPS3, .NeoGeo, .NAOMI, .NAOMI2, .Atomiswave
    ]

    func testCartridgeConsolesMatchRcheevosIDs() {
        XCTAssertEqual(SystemIdentifier.Genesis.retroAchievementsConsoleID, 1)
        XCTAssertEqual(SystemIdentifier.N64.retroAchievementsConsoleID, 2)
        XCTAssertEqual(SystemIdentifier.SNES.retroAchievementsConsoleID, 3)
        XCTAssertEqual(SystemIdentifier.GBA.retroAchievementsConsoleID, 5)
        XCTAssertEqual(SystemIdentifier.NES.retroAchievementsConsoleID, 7)
        XCTAssertEqual(SystemIdentifier.SGFX.retroAchievementsConsoleID, 8)
        XCTAssertEqual(SystemIdentifier.PSX.retroAchievementsConsoleID, 12)
        XCTAssertEqual(SystemIdentifier.PCECD.retroAchievementsConsoleID, 76)
        XCTAssertEqual(SystemIdentifier.FDS.retroAchievementsConsoleID, 81)
    }

    func testArcadeSystemsMapToArcadeConsole() {
        for system in arcadeSystems {
            XCTAssertEqual(system.retroAchievementsConsoleID, SystemIdentifier.retroAchievementsArcadeConsoleID, "\(system)")
            XCTAssertTrue(system.retroAchievementsHashesArchiveDirectly, "\(system)")
        }
    }

    func testNoNonArcadeSystemMapsToArcadeConsole() {
        for system in SystemIdentifier.allCases where !arcadeSystems.contains(system) {
            XCTAssertNotEqual(system.retroAchievementsConsoleID, SystemIdentifier.retroAchievementsArcadeConsoleID, "\(system)")
        }
    }

    func testOnlyArcadeAndDOSHashTheArchiveDirectly() {
        XCTAssertTrue(SystemIdentifier.DOS.retroAchievementsHashesArchiveDirectly)
        for system in SystemIdentifier.allCases where !arcadeSystems.contains(system) && system != .DOS {
            XCTAssertFalse(system.retroAchievementsHashesArchiveDirectly, "\(system)")
        }
    }

    func testSystemsWithoutAConsoleReturnNil() {
        XCTAssertNil(SystemIdentifier.RetroArch.retroAchievementsConsoleID)
        XCTAssertNil(SystemIdentifier.Unknown.retroAchievementsConsoleID)
        XCTAssertFalse(SystemIdentifier.Unknown.retroAchievementsHashesArchiveDirectly)
    }
}
