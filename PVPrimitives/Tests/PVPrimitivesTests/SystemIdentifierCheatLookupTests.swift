// SystemIdentifierCheatLookupTests.swift
// PVPrimitivesTests
//
// Unit tests for `SystemIdentifier.cheatLookupResolvedIdentifier` / `cheatLookupLibretroFolderName`.

import XCTest
import PVSystems

final class SystemIdentifierCheatLookupTests: XCTestCase {

    func testDreamcastGameUsesSegaDreamcastFolder() {
        let name = SystemIdentifier.cheatLookupLibretroFolderName(
            gameSystemIdentifier: SystemIdentifier.Dreamcast.rawValue,
            linkedPVSystemIdentifier: nil,
            coreIdentifier: nil
        )
        XCTAssertEqual(name, "Sega - Dreamcast")
    }

    func testRetroArchGameWithLinkedDreamcastSystem() {
        let resolved = SystemIdentifier.cheatLookupResolvedIdentifier(
            gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            linkedPVSystemIdentifier: SystemIdentifier.Dreamcast.rawValue,
            coreIdentifier: "PVRetroArchCore"
        )
        XCTAssertEqual(resolved, .Dreamcast)
        XCTAssertEqual(
            SystemIdentifier.cheatLookupLibretroFolderName(
                gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
                linkedPVSystemIdentifier: SystemIdentifier.Dreamcast.rawValue,
                coreIdentifier: "PVRetroArchCore"
            ),
            "Sega - Dreamcast"
        )
    }

    func testRetroArchWithFlycastCoreInfersDreamcast() {
        let resolved = SystemIdentifier.cheatLookupResolvedIdentifier(
            gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            linkedPVSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            coreIdentifier: "flycast.libretro.framework"
        )
        XCTAssertEqual(resolved, .Dreamcast)
    }

    func testNativeFlycastCoreIdentifierInfersDreamcast() {
        let resolved = SystemIdentifier.cheatLookupResolvedIdentifier(
            gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            linkedPVSystemIdentifier: nil,
            coreIdentifier: "com.provenance.core.flycast"
        )
        XCTAssertEqual(resolved, .Dreamcast)
    }

    func testRetroArchWithVirtualJaguarCoreInfersAtariJaguar() {
        let resolved = SystemIdentifier.cheatLookupResolvedIdentifier(
            gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            linkedPVSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            coreIdentifier: "virtualjaguar.libretro.framework"
        )
        XCTAssertEqual(resolved, .AtariJaguar)
        XCTAssertEqual(
            SystemIdentifier.cheatLookupLibretroFolderName(
                gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
                linkedPVSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
                coreIdentifier: "virtualjaguar.libretro.framework"
            ),
            "Atari - Jaguar"
        )
    }

    func testProvenanceJaguarCoreIdentifierInfersAtariJaguar() {
        let resolved = SystemIdentifier.cheatLookupResolvedIdentifier(
            gameSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            linkedPVSystemIdentifier: nil,
            coreIdentifier: "com.provenance.core.jaguar"
        )
        XCTAssertEqual(resolved, .AtariJaguar)
    }

    func testConcreteGameSystemWinsOverLinkedSystem() {
        let resolved = SystemIdentifier.cheatLookupResolvedIdentifier(
            gameSystemIdentifier: SystemIdentifier.SNES.rawValue,
            linkedPVSystemIdentifier: SystemIdentifier.RetroArch.rawValue,
            coreIdentifier: nil
        )
        XCTAssertEqual(resolved, .SNES)
    }
}
