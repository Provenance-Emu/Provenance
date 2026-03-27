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
        // Empty filename is always rejected; the predicate guards against it explicitly.
        XCTAssertFalse(
            ROMGameLookup.romPathMatches("", filename: "")
        )
    }

    // MARK: - realFilename(from:)

    func testRealFilenamePassthrough() {
        let url = URL(fileURLWithPath: "/ROMs/SuperMario64.n64")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "SuperMario64.n64")
    }

    func testRealFilenameStripsIcloudSuffix() {
        // Evicted file without leading dot (edge case)
        let url = URL(fileURLWithPath: "/ROMs/SuperMario64.n64.icloud")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "SuperMario64.n64")
    }

    func testRealFilenameStripsLeadingDotAndIcloudSuffix() {
        // Standard iCloud placeholder: hidden file with leading dot
        let url = URL(fileURLWithPath: "/ROMs/.SuperMario64.n64.icloud")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "SuperMario64.n64")
    }

    func testRealFilenameOnlyIcloudSuffixReturnsEmpty() {
        // Degenerate case: filename is just ".icloud" — returns "" which lookup rejects safely
        let url = URL(fileURLWithPath: "/ROMs/.icloud")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), "")
    }

    func testRealFilenamePreservesHiddenFileWithoutIcloud() {
        // A legitimately hidden file (dot-prefixed, no .icloud suffix) passes through unchanged
        let url = URL(fileURLWithPath: "/ROMs/.hidden-game.sfc")
        XCTAssertEqual(ROMGameLookup.realFilename(from: url), ".hidden-game.sfc")
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
