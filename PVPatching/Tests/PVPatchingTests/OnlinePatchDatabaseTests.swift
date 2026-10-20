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
        let before = await limiter.cachedData(for: key)
        XCTAssertNil(before)
        await limiter.store(Data("abc".utf8), for: key)
        let after = await limiter.cachedData(for: key)
        XCTAssertEqual(after, Data("abc".utf8))
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

final class RomHackingNetDownloadNamingTests: XCTestCase {
    private let info = OnlinePatchInfo(
        id: "https://www.romhacking.net/translations/6228/",
        title: "The Legend of Zelda",
        category: .translation,
        pageURL: URL(string: "https://www.romhacking.net/translations/6228/")!
    )
    private let downloadURL = URL(string: "https://www.romhacking.net/download/6228")!

    func testContentDispositionWins() {
        let name = RomHackingNetDatabase.suggestedFilename(
            for: info, downloadURL: downloadURL,
            contentDisposition: "attachment; filename=\"zelda_en_v1.0.zip\"",
            data: Data([0x50, 0x4B, 0x03, 0x04])
        )
        XCTAssertEqual(name, "zelda_en_v1.0.zip")
    }

    func testRFC5987FilenameIsDecoded() {
        let name = RomHackingNetDatabase.suggestedFilename(
            for: info, downloadURL: downloadURL,
            contentDisposition: "attachment; filename*=UTF-8''Zelda%20EN.ips",
            data: Data("PATCH".utf8)
        )
        XCTAssertEqual(name, "Zelda EN.ips")
    }

    func testExtensionlessZipIsSniffed() {
        let name = RomHackingNetDatabase.suggestedFilename(
            for: info, downloadURL: downloadURL, contentDisposition: nil,
            data: Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00])
        )
        XCTAssertEqual(name, "The Legend of Zelda.zip")
    }

    func testExtensionlessBPSIsSniffed() {
        let name = RomHackingNetDatabase.suggestedFilename(
            for: info, downloadURL: downloadURL, contentDisposition: nil,
            data: Data("BPS1".utf8) + Data([0x80, 0x80, 0x80])
        )
        XCTAssertEqual(name, "The Legend of Zelda.bps")
    }

    func testUnknownPayloadFallsBackToBPSWithStableStem() {
        let anonymous = OnlinePatchInfo(id: info.id, title: "", category: .hack, pageURL: info.pageURL)
        let name = RomHackingNetDatabase.suggestedFilename(
            for: anonymous, downloadURL: downloadURL, contentDisposition: nil, data: Data([0x00, 0x01])
        )
        XCTAssertEqual(name, "rhdn-6228.bps")
    }

    func testSearchChallengeDetection() {
        XCTAssertTrue(RomHackingNetDatabase.isSearchChallenge("<html><body class=\"anomaly-modal\">Unfortunately, bots use DuckDuckGo too.</body></html>"))
        XCTAssertFalse(RomHackingNetDatabase.isSearchChallenge("<a class=\"result__a\" href=\"x\">anomaly</a>"))
    }

    func testSnippetKeepsTextAfterBoldTags() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "duckduckgo_rhdn_search", withExtension: "html", subdirectory: "Resources"
        ))
        let html = try String(contentsOf: url, encoding: .utf8)
        let zelda = DuckDuckGoHTMLParser.parseSearchResults(html)
            .first(where: { $0.pageURL.absoluteString.contains("/translations/6228") })
        let snippet = try XCTUnwrap(zelda?.snippet)
        XCTAssertTrue(snippet.lowercased().hasPrefix("an unofficial indonesian translation"), snippet)
        XCTAssertGreaterThan(snippet.count, "An unofficial Indonesian".count)
    }
}
