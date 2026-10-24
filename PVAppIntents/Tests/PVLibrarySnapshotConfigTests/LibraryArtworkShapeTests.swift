//
//  LibraryArtworkShapeTests.swift
//  PVLibrarySnapshotConfigTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVLibrarySnapshotConfig

/// Guards the shape table used by Top Shelf to pick `ImageShape`.
final class LibraryArtworkShapeTests: XCTestCase {
    func testWideSystemsResolveToWide() {
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.provenance.snes"), .wide)
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.provenance.psx"), .wide)
    }

    func testHandheldsAndUnknownsResolveToSquare() {
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.provenance.gb"), .square)
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: "com.example.unknown"), .square)
        XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: nil), .square)
    }

    func testEveryWideIdentifierUsesTheProvenanceReverseDNSPrefix() {
        // Cheap guard against a typo'd entry silently never matching.
        for identifier in ["com.provenance.snes", "com.provenance.wii"] {
            XCTAssertEqual(LibraryArtworkShape.shape(forSystemIdentifier: identifier), .wide)
        }
    }
}
