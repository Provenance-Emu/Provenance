// GeckoCodesLookupTests.swift
// PVLibraryTests
//
// Unit tests for GeckoCodesLookup's plain-text Gecko code parser.
// Tests run against static fixture strings — no network required.

@testable import PVLibrary
import XCTest

final class GeckoCodesLookupTests: XCTestCase {

    // MARK: - Happy Path

    func testParseMultipleCheats() async {
        let fixture = """
        [GALE01 - Super Smash Bros. Melee]
        $Infinite Stock
        04396458 00000003
        $Master Hand Always Available
        0439E83C 00000001
        04400000 00000002
        """
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes(fixture, gameID: "GALE01")
        XCTAssertEqual(entries.count, 2, "Expected 2 cheats parsed")

        let first = entries[0]
        XCTAssertEqual(first.cheatName, "Infinite Stock")
        XCTAssertEqual(first.cheatCode, "0439645800000003")
        XCTAssertEqual(first.deviceName, "Gecko")
        XCTAssertEqual(first.romTitle, "GALE01")
        XCTAssertTrue(first.isOnlineResult)

        let second = entries[1]
        XCTAssertEqual(second.cheatName, "Master Hand Always Available")
        // Two code lines joined with "+"
        XCTAssertEqual(second.cheatCode, "0439E83C00000001+0440000000000002")
    }

    func testParseSkipsHeaderAndCommentLines() async {
        let fixture = """
        [RMCE01 - Mario Kart Wii]
        # This is a comment
        $No Gravity
        04000000 00000000
        """
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes(fixture, gameID: "RMCE01")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].cheatName, "No Gravity")
    }

    func testParseAsteriskCheatPrefix() async {
        let fixture = """
        *Alternate prefix cheat
        04AABBCC 00112233
        """
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes(fixture, gameID: "TEST01")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].cheatName, "Alternate prefix cheat")
    }

    // MARK: - Edge Cases

    func testEmptyTextReturnsEmpty() async {
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes("", gameID: "GALE01")
        XCTAssertTrue(entries.isEmpty)
    }

    func testNoCodeLinesReturnsEmpty() async {
        let fixture = """
        [GALE01 - Super Smash Bros. Melee]
        $Cheat with no code lines
        """
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes(fixture, gameID: "GALE01")
        XCTAssertTrue(entries.isEmpty, "A cheat entry with no code lines should not be emitted")
    }

    func testCodeLineWithoutCheatNameIsIgnored() async {
        let fixture = """
        04396458 00000003
        04396459 00000004
        $Valid Cheat
        AABBCCDD 00112233
        """
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes(fixture, gameID: "GALE01")
        XCTAssertEqual(entries.count, 1, "Orphaned code lines before any cheat name should be ignored")
        XCTAssertEqual(entries[0].cheatName, "Valid Cheat")
    }

    func testIdsAreUniqueAndSequential() async {
        let fixture = """
        $Cheat A
        04000000 00000001
        $Cheat B
        04000000 00000002
        $Cheat C
        04000000 00000003
        """
        let entries = await GeckoCodesLookup.shared.parseGeckoCodes(fixture, gameID: "TEST01")
        XCTAssertEqual(entries.count, 3)
        let ids = entries.map(\.id)
        XCTAssertEqual(Set(ids).count, 3, "All IDs should be unique")
    }
}
