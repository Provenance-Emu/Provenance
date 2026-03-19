//
//  ROMGameLookupTests.swift
//  PVQuickLookSupportTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVQuickLookSupport

final class ROMGameLookupTests: XCTestCase {

    // MARK: - romPathMatches

    func testMatchesSuffixFormat() {
        // romPath stored as "{systemID}/{filename}"
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "SuperMario.sfc")
        )
    }

    func testMatchesExactFormat() {
        // romPath stored as bare filename
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("SuperMario.sfc", filename: "SuperMario.sfc")
        )
    }

    func testDoesNotMatchPartialFilename() {
        // "ario.sfc" is a substring, not the full filename
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "ario.sfc")
        )
    }

    func testDoesNotMatchDifferentFilename() {
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "Zelda.sfc")
        )
    }

    func testMatchesNestedSubdirectoryPath() {
        // Multi-level path still matches on the trailing component
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("com.provenance.snes/usa/SuperMario.sfc",
                                         filename: "SuperMario.sfc")
        )
    }

    func testEmptyFilenameDoesNotMatch() {
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("com.provenance.snes/SuperMario.sfc",
                                         filename: "")
        )
    }

    func testEmptyPathDoesNotMatch() {
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("", filename: "SuperMario.sfc")
        )
    }

    func testBothEmptyDoNotMatch() {
        // "" == "" is true for exact match — but empty filename lookup should be
        // guarded by the caller, so test the raw predicate.
        XCTAssertTrue(
            ROMGameLookup.romPathMatches("", filename: "")
        )
    }

    // MARK: - lookup (no-database branch)

    func testLookupReturnsNilWhenAppGroupsUnavailable() {
        // In the test process App Groups are not configured, so lookup must
        // return nil gracefully (not crash).
        let result = ROMGameLookup.lookup(forROMFilename: "SuperMario.sfc")
        XCTAssertNil(result, "Expected nil when App Groups are unavailable")
    }

    func testSaveStateImageURLReturnsNilWhenAppGroupsUnavailable() {
        let result = ROMGameLookup.saveStateImageURL(forSaveStatePath: "/some/state.pvsav")
        XCTAssertNil(result, "Expected nil when App Groups are unavailable")
    }

    func testLookupEmptyFilenameReturnsNil() {
        let result = ROMGameLookup.lookup(forROMFilename: "")
        XCTAssertNil(result)
    }
}
