// GameHackingOrgLookupTests.swift
// PVLibraryTests
//
// Unit tests for GameHackingOrgLookup's HTML parsing strategies.
// Tests run against static HTML fixtures — no network required.

@testable import PVLibrary
import XCTest

final class GameHackingOrgLookupTests: XCTestCase {

    let lookup = GameHackingOrgLookup.shared

    // MARK: - Table Parser

    func testParseTableCheats_happyPath() async {
        let html = """
        <table>
          <tr><th>Code</th><th>Name</th></tr>
          <tr><td>DEADBEEF12345678</td><td>Infinite Lives</td></tr>
          <tr><td>AABBCCDD00000001</td><td>Max Score</td></tr>
        </table>
        """
        let entries = await lookup.parseTableCheats(html, romTitle: "Test Game")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].cheatName, "Infinite Lives")
        XCTAssertEqual(entries[0].cheatCode, "DEADBEEF12345678")
        XCTAssertEqual(entries[0].deviceName, "GameHacking.org")
        XCTAssertTrue(entries[0].isOnlineResult)
        XCTAssertEqual(entries[1].cheatName, "Max Score")
    }

    func testParseTableCheats_skipsHeaderRow() async {
        let html = """
        <table>
          <tr><th>Name</th><th>Code</th></tr>
          <tr><td>God Mode</td><td>FF00FF0000000001</td></tr>
        </table>
        """
        let entries = await lookup.parseTableCheats(html, romTitle: "Test Game")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].cheatName, "God Mode")
    }

    func testParseTableCheats_emptyTableReturnsEmpty() async {
        let html = "<table><tr><td>no codes here</td></tr></table>"
        let entries = await lookup.parseTableCheats(html, romTitle: "Test Game")
        XCTAssertTrue(entries.isEmpty)
    }

    func testParseTableCheats_noTableReturnsEmpty() async {
        let entries = await lookup.parseTableCheats("<p>No table at all</p>", romTitle: "Test Game")
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Definition List Parser

    func testParseDefinitionListCheats_happyPath() async {
        let html = """
        <dl>
          <dt>Infinite Health</dt><dd>DEADBEEF 00000001</dd>
          <dt>AABBCCDD 00112233</dt><dd>Max Ammo</dd>
        </dl>
        """
        let entries = await lookup.parseDefinitionListCheats(html, romTitle: "Test Game")
        XCTAssertEqual(entries.count, 2)
        // First pair: dt=name, dd=code
        XCTAssertEqual(entries[0].cheatName, "Infinite Health")
        // Second pair: dt=code, dd=name
        XCTAssertEqual(entries[1].cheatName, "Max Ammo")
    }

    func testParseDefinitionListCheats_emptyReturnsEmpty() async {
        let entries = await lookup.parseDefinitionListCheats("<p>nothing</p>", romTitle: "Test Game")
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Best Game Link

    func testBestGameLink_exactTitleMatch() async {
        let html = """
        <a href="/game/100">Some Other Game</a>
        <a href="/game/200">Super Mario Bros</a>
        <a href="/game/300">Totally Different</a>
        """
        let path = await lookup.bestGameLink(in: html, for: "Super Mario Bros")
        XCTAssertEqual(path, "/game/200")
    }

    func testBestGameLink_noMatchReturnsNil() async {
        let html = "<a href=\"/game/100\">Completely Unrelated Title Here</a>"
        let path = await lookup.bestGameLink(in: html, for: "Zelda")
        XCTAssertNil(path)
    }

    func testBestGameLink_emptyHTMLReturnsNil() async {
        let path = await lookup.bestGameLink(in: "", for: "Zelda")
        XCTAssertNil(path)
    }

    // MARK: - looksLikeCode

    func testLooksLikeCode_validHex() async {
        let result = await lookup.looksLikeCode("DEADBEEF00000001")
        XCTAssertTrue(result)
    }

    func testLooksLikeCode_shortStringFalse() async {
        let result = await lookup.looksLikeCode("AB")
        XCTAssertFalse(result)
    }

    func testLooksLikeCode_plainTextFalse() async {
        let result = await lookup.looksLikeCode("Infinite Lives")
        XCTAssertFalse(result)
    }
}
