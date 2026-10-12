//
//  LibraryPathRemapperTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVLibrary

final class LibraryPathRemapperTests: XCTestCase {
    func testRomPathDropsTheROMsPrefixOnly() {
        XCTAssertEqual(LibraryPathRemapper.romPath(forPartialPath: "ROMs/com.provenance.snes/Game (USA).sfc"), "com.provenance.snes/Game (USA).sfc")
        XCTAssertEqual(LibraryPathRemapper.romPath(forPartialPath: "com.provenance.snes/Game.sfc"), "com.provenance.snes/Game.sfc")
        XCTAssertEqual(LibraryPathRemapper.romPath(forPartialPath: "BIOS/x.bin"), "BIOS/x.bin")
    }
}
