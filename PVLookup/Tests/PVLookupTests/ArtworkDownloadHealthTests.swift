//
//  ArtworkDownloadHealthTests.swift
//  PVLookup
//

import Testing
import Foundation
@testable import PVLookup
import PVLookupTypes
import PVSystems

struct ArtworkDownloadHealthTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
    private let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])
    private let html = Data("<!DOCTYPE html><html><title>Just a moment...</title>".utf8)

    // MARK: Classifier

    @Test("403, 404 and 410 are dead URLs", arguments: [403, 404, 410])
    func deadStatuses(code: Int) {
        #expect(ArtworkDownloadClassifier.classify(statusCode: code, data: html).isDead)
        // Even with an image-looking body, a dead status wins.
        #expect(ArtworkDownloadClassifier.classify(statusCode: code, data: png).isDead)
    }

    @Test("5xx and 429 are transient, not dead", arguments: [429, 500, 502, 503])
    func transientStatuses(code: Int) {
        #expect(ArtworkDownloadClassifier.classify(statusCode: code, data: Data()) == .transient(reason: "HTTP \(code)"))
    }

    @Test("200 with an image body is an image")
    func okImage() {
        #expect(ArtworkDownloadClassifier.classify(statusCode: 200, data: png) == .image)
        #expect(ArtworkDownloadClassifier.classify(statusCode: 200, data: jpeg) == .image)
    }

    @Test("200 with an HTML or empty body is dead")
    func okButNotImage() {
        #expect(ArtworkDownloadClassifier.classify(statusCode: 200, data: html).isDead)
        #expect(ArtworkDownloadClassifier.classify(statusCode: 200, data: Data()).isDead)
    }

    @Test("Non-HTTP response is judged on the body alone")
    func nonHTTP() {
        #expect(ArtworkDownloadClassifier.classify(statusCode: nil, data: png) == .image)
        #expect(ArtworkDownloadClassifier.classify(statusCode: nil, data: html).isDead)
    }

    @Test("WebP, GIF and HEIC magic bytes are recognised")
    func otherFormats() {
        #expect(ArtworkDownloadClassifier.looksLikeImage(Data("RIFF".utf8) + Data([0, 0, 0, 0]) + Data("WEBP".utf8)))
        #expect(ArtworkDownloadClassifier.looksLikeImage(Data("GIF89a".utf8)))
        #expect(ArtworkDownloadClassifier.looksLikeImage(Data([0, 0, 0, 0x18]) + Data("ftypheic".utf8)))
        #expect(!ArtworkDownloadClassifier.looksLikeImage(Data("abc".utf8)))
    }

    // MARK: Fallback ordering

    private func url(_ s: String) -> URL { URL(string: s) ?? URL(fileURLWithPath: "/") }

    @Test("libretro candidates come before other sources")
    func libretroFirst() {
        let gamefaqs = url("https://gamefaqs.gamespot.com/a/box/1_front.jpg")
        let tgdb = url("https://cdn.thegamesdb.net/images/original/boxart/front/1-1.png")
        let libretro = url("https://thumbnails.libretro.com/Nintendo%20-%20Game%20Boy/Named_Boxarts/Tetris.png")
        let order = ArtworkFallbackPlanner.order(libretro: [libretro], others: [gamefaqs, tgdb], excluding: [])
        #expect(order == [libretro, gamefaqs, tgdb])
    }

    @Test("dead URL, known-dead URLs and duplicates are dropped")
    func excludesDeadAndDuplicates() {
        let dead = url("https://gamefaqs.gamespot.com/a/box/1_front.jpg")
        let other = url("https://cdn.thegamesdb.net/a.png")
        let libretro = url("https://thumbnails.libretro.com/x/Named_Boxarts/A.png")
        let order = ArtworkFallbackPlanner.order(
            libretro: [libretro, libretro],
            others: [dead, other, other],
            excluding: [dead.absoluteString]
        )
        #expect(order == [libretro, other])
    }

    @Test("blocked hosts are skipped and the attempt count is capped")
    func blockedAndCapped() {
        let blocked = url("https://gamefaqs.gamespot.com/a.jpg")
        let others = (1...6).map { url("https://example.com/\($0).png") }
        let order = ArtworkFallbackPlanner.order(
            libretro: [],
            others: [blocked] + others,
            excluding: [],
            isBlocked: { $0.host == "gamefaqs.gamespot.com" },
            maxAttempts: 3
        )
        #expect(order == Array(others.prefix(3)))
    }

    @Test("libretro thumbnail host detection")
    func libretroHost() {
        #expect(ArtworkFallbackPlanner.isLibretroThumbnail(url("https://thumbnails.libretro.com/a.png")))
        #expect(!ArtworkFallbackPlanner.isLibretroThumbnail(url("https://gamefaqs.gamespot.com/a.png")))
    }

    // MARK: Negative cache

    @Test("dead URLs are remembered and bounded")
    func deadCacheBounded() async {
        let cache = ArtworkDeadURLCache(maxEntries: 2, hostBlockThreshold: 3)
        let a = url("https://a.example/1.png")
        let b = url("https://b.example/2.png")
        let c = url("https://c.example/3.png")
        await cache.recordDead(a, statusCode: 404)
        await cache.recordDead(b, statusCode: 404)
        await cache.recordDead(c, statusCode: 404)
        #expect(await cache.isDead(a) == false)   // evicted, oldest first
        #expect(await cache.isDead(b))
        #expect(await cache.isDead(c))
    }

    @Test("repeated 403s block the host until a success")
    func hostBlocking() async {
        let cache = ArtworkDeadURLCache(maxEntries: 100, hostBlockThreshold: 3)
        for i in 1...3 {
            await cache.recordDead(url("https://gamefaqs.gamespot.com/\(i).jpg"), statusCode: 403)
        }
        let fresh = url("https://gamefaqs.gamespot.com/never-tried.jpg")
        #expect(await cache.isDead(fresh))
        await cache.recordSuccess(fresh)
        #expect(await cache.isDead(fresh) == false)
    }

    @Test("404s do not block a host")
    func notFoundDoesNotBlockHost() async {
        let cache = ArtworkDeadURLCache(maxEntries: 100, hostBlockThreshold: 2)
        for i in 1...5 {
            await cache.recordDead(url("https://thumbnails.libretro.com/\(i).png"), statusCode: 404)
        }
        #expect(await cache.isDead(url("https://thumbnails.libretro.com/other.png")) == false)
    }

    @Test("exhausted games stay skipped until forgotten")
    func exhaustedGames() async {
        let cache = ArtworkDeadURLCache()
        await cache.markExhausted(gameKey: "ABC")
        #expect(await cache.isExhausted(gameKey: "ABC"))
        await cache.forgetExhausted(gameKey: "ABC")
        #expect(await cache.isExhausted(gameKey: "ABC") == false)
    }
}

/// Hits the real thumbnails.libretro.com (like the other PVLookup artwork tests).
struct ArtworkFallbackLookupTests {
    @Test("A dead gamefaqs cover falls back to the libretro thumbnail first")
    func libretroPreferred() async {
        let dead = "https://gamefaqs.gamespot.com/a/box/2/8/3/22283_front.jpg"
        let rom = ROMMetadata(
            gameTitle: "Tetris",
            boxImageURL: dead,
            systemID: .GB,
            romFileName: "Tetris (World) (Rev 1).gb",
            romHashMD5: "982ED5D2B12A0377EB14BCDC4123744E"
        )
        let urls = await PVLookup.shared.fallbackArtworkURLs(forRom: rom, excluding: [dead])
        #expect(urls.first.map(ArtworkFallbackPlanner.isLibretroThumbnail) == true)
        #expect(!urls.contains { $0.absoluteString == dead })
    }
}
