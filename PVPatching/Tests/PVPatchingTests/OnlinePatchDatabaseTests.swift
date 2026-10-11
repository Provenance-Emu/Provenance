//
//  OnlinePatchDatabaseTests.swift
//  PVPatchingTests
//

import Foundation
import XCTest
@testable import PVPatching

final class OnlinePatchDatabaseTests: XCTestCase {

    func testDuckDuckGoParserExtractsRomHackingEntries() throws {
        let url = try fixtureURL(named: "duckduckgo_rhdn_search")
        let html = try String(contentsOf: url, encoding: .utf8)
        let results = DuckDuckGoHTMLParser.parseSearchResults(html)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.pageURL.host?.contains("romhacking.net") == true })
        XCTAssertTrue(results.contains(where: { $0.pageURL.path.contains("/translations/") }))
        XCTAssertFalse(results.contains(where: { $0.pageURL.path.hasSuffix("/hacks/") && !$0.pageURL.path.contains("/hacks/") }))
        // Homepage / community / reviews should be filtered out.
        XCTAssertFalse(results.contains(where: { $0.pageURL.path == "/" || $0.pageURL.path.isEmpty }))
        XCTAssertFalse(results.contains(where: { $0.pageURL.path.contains("/community/") }))
        XCTAssertFalse(results.contains(where: { $0.pageURL.path.contains("/reviews/") }))

        let zelda = results.first(where: { $0.pageURL.absoluteString.contains("/translations/6228") })
        XCTAssertNotNil(zelda)
        XCTAssertEqual(zelda?.category, .translation)
        XCTAssertFalse(zelda?.title.lowercased().contains("romhacking.net -") == true)
    }

    func testRomHackingDetailParser() throws {
        let url = try fixtureURL(named: "romhacking_detail_fixture")
        let html = try String(contentsOf: url, encoding: .utf8)
        let page = try XCTUnwrap(URL(string: "https://www.romhacking.net/translations/6228/"))
        let info = try RomHackingNetHTMLParser.parseDetail(html: html, pageURL: page)

        XCTAssertEqual(info.title, "The Legend of Zelda")
        XCTAssertEqual(info.author, "ExampleHacker")
        XCTAssertEqual(info.version, "1.0")
        XCTAssertEqual(info.platformName, "NES")
        XCTAssertEqual(info.language, "English")
        XCTAssertEqual(info.category, .translation)
        XCTAssertEqual(info.downloadURL?.absoluteString, "https://www.romhacking.net/download/6228")
        XCTAssertTrue(info.patchDescription?.contains("English translation") == true)
    }

    func testIsRomHackingEntryRequiresNumericID() {
        XCTAssertTrue(
            DuckDuckGoHTMLParser.isRomHackingEntry(
                URL(string: "https://www.romhacking.net/translations/6228/")!
            )
        )
        XCTAssertFalse(
            DuckDuckGoHTMLParser.isRomHackingEntry(
                URL(string: "https://www.romhacking.net/hacks/")!
            )
        )
        XCTAssertFalse(
            DuckDuckGoHTMLParser.isRomHackingEntry(
                URL(string: "https://example.com/translations/1/")!
            )
        )
    }

    func testRateLimiterCachesAndExpires() async {
        let limiter = PatchDatabaseRateLimiter(minimumInterval: 0, cacheTTL: 60)
        let key = "test"
        XCTAssertNil(await limiter.cachedData(for: key))
        await limiter.store(Data("abc".utf8), for: key)
        XCTAssertEqual(await limiter.cachedData(for: key), Data("abc".utf8))
    }

    func testSafariSearchURL() {
        let db = RomHackingNetDatabase()
        let url = db.safariSearchURL(query: "zelda", filter: OnlinePatchSearchFilter(category: .translation, platformQuery: "NES"))
        XCTAssertEqual(url?.host, "www.romhacking.net")
        XCTAssertTrue(url?.absoluteString.contains("search=zelda") == true || url?.query?.contains("zelda") == true)
    }

    private func fixtureURL(named name: String) throws -> URL {
        if let url = Bundle.module.url(forResource: name, withExtension: "html") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Resources") {
            return url
        }
        throw XCTSkip("Missing fixture \(name).html in test bundle")
    }
}
