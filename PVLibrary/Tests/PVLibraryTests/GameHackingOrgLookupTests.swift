// GameHackingOrgLookupTests.swift
// PVLibraryTests
//
// Unit tests for GameHackingOrgLookup's HTML parsing strategies and proxy path.
// Tests run against static HTML fixtures — no network required.

@testable import PVLibrary
import Defaults
import PVSettings
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

    // MARK: - Proxy Path (URLProtocol stubs)

    func testSearchCheats_proxyReturnsResults() async {
        URLProtocol.registerClass(ProxyCannedProtocol.self)
        defer { URLProtocol.unregisterClass(ProxyCannedProtocol.self) }

        let json = #"[{"name":"Infinite Lives","code":"DEADBEEF00000001","category":"General"}]"#
        ProxyCannedProtocol.cannedJSON = Data(json.utf8)
        ProxyCannedProtocol.statusCode = 200
        ProxyCannedProtocol.lastRequest = nil

        Defaults[.useCheatProxy] = true
        Defaults[.cheatProxyURL] = "https://test.proxy.pvemu.invalid"
        defer {
            Defaults.reset(.useCheatProxy)
            Defaults.reset(.cheatProxyURL)
        }

        let title = "ProxyHappyPath_\(UUID().uuidString)"
        let entries = await GameHackingOrgLookup.shared.searchCheats(title: title, systemSlug: "n64")

        // The proxy URL should have been contacted with the correct path/query
        let intercepted = ProxyCannedProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(intercepted.contains("/cheats"), "Expected /cheats in proxy request URL, got: \(intercepted)")
        XCTAssertTrue(intercepted.contains("title="), "Expected title= query param in proxy request URL")

        // Results should be decoded from the proxy JSON
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.cheatName, "Infinite Lives")
        XCTAssertEqual(entries.first?.cheatCode, "DEADBEEF00000001")
        XCTAssertEqual(entries.first?.deviceName, "GameHacking.org")
        XCTAssertTrue(entries.first?.isOnlineResult ?? false)
    }

    func testSearchCheats_proxyReturnsEmpty_fallsThrough() async {
        URLProtocol.registerClass(ProxyCannedProtocol.self)
        defer { URLProtocol.unregisterClass(ProxyCannedProtocol.self) }

        // Proxy returns empty array — direct scraping also yields nothing (no network in CI)
        ProxyCannedProtocol.cannedJSON = Data("[]".utf8)
        ProxyCannedProtocol.statusCode = 200
        ProxyCannedProtocol.lastRequest = nil

        Defaults[.useCheatProxy] = true
        Defaults[.cheatProxyURL] = "https://test.proxy.pvemu.invalid"
        defer {
            Defaults.reset(.useCheatProxy)
            Defaults.reset(.cheatProxyURL)
        }

        let title = "ProxyEmptyFallback_\(UUID().uuidString)"
        let entries = await GameHackingOrgLookup.shared.searchCheats(title: title, systemSlug: nil)
        // Proxy was contacted but returned empty; direct scraping also fails offline — result is empty
        XCTAssertTrue(entries.isEmpty)
        let intercepted = ProxyCannedProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(intercepted.contains("/cheats"), "Proxy should still have been contacted even when empty")
    }

    func testSearchCheats_proxyDisabled_doesNotContactProxy() async {
        URLProtocol.registerClass(ProxyCannedProtocol.self)
        defer { URLProtocol.unregisterClass(ProxyCannedProtocol.self) }

        ProxyCannedProtocol.cannedJSON = Data()
        ProxyCannedProtocol.lastRequest = nil

        Defaults[.useCheatProxy] = false
        Defaults[.cheatProxyURL] = "https://test.proxy.pvemu.invalid"
        defer {
            Defaults.reset(.useCheatProxy)
            Defaults.reset(.cheatProxyURL)
        }

        let title = "ProxyDisabled_\(UUID().uuidString)"
        _ = await GameHackingOrgLookup.shared.searchCheats(title: title, systemSlug: nil)
        // The proxy should not have been contacted when useCheatProxy is false
        XCTAssertNil(ProxyCannedProtocol.lastRequest, "Proxy should not be contacted when useCheatProxy is false")
    }
}

// MARK: - URLProtocol stub for proxy tests

/// Intercepts requests to the test proxy host and returns canned JSON.
private final class ProxyCannedProtocol: URLProtocol {
    static var cannedJSON: Data = Data()
    static var statusCode: Int = 200
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.contains("test.proxy.pvemu.invalid") ?? false
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        ProxyCannedProtocol.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: ProxyCannedProtocol.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: ProxyCannedProtocol.cannedJSON)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
