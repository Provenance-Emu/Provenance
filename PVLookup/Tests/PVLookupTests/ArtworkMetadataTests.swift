//
//  ArtworkMetadataTests.swift
//  PVLookup
//
//  Tests for ArtworkMetadata including initialization, Equatable, Hashable,
//  Codable conformance, and Set deduplication behavior.
//

import Testing
import PVLookupTypes
import PVSystems
import Foundation

struct ArtworkMetadataTests {

    // MARK: - Initialization

    @Test("Init with only required fields leaves optionals nil")
    func initWithRequiredFields() {
        let url = URL(string: "https://example.com/image.jpg")!
        let metadata = ArtworkMetadata(
            url: url,
            type: .boxFront,
            source: "TestDB"
        )
        #expect(metadata.url == url)
        #expect(metadata.type == .boxFront)
        #expect(metadata.source == "TestDB")
        #expect(metadata.resolution == nil)
        #expect(metadata.description == nil)
        #expect(metadata.systemID == nil)
    }

    @Test("Init with all fields stores all values correctly")
    func initWithAllFields() {
        let url = URL(string: "https://cdn.thegamesdb.net/images/screenshot/1018-1.jpg")!
        let metadata = ArtworkMetadata(
            url: url,
            type: .screenshot,
            resolution: "1920x1080",
            description: "In-game screenshot",
            source: "TheGamesDB",
            systemID: .SNES
        )
        #expect(metadata.url == url)
        #expect(metadata.type == .screenshot)
        #expect(metadata.resolution == "1920x1080")
        #expect(metadata.description == "In-game screenshot")
        #expect(metadata.source == "TheGamesDB")
        #expect(metadata.systemID == .SNES)
    }

    @Test("Init stores different artwork types correctly")
    func initWithDifferentTypes() {
        let url = URL(string: "https://example.com/img.jpg")!
        let types: [ArtworkType] = [.boxFront, .boxBack, .manual, .screenshot, .titleScreen, .fanArt, .banner, .clearLogo, .other]

        for type in types {
            let metadata = ArtworkMetadata(url: url, type: type, source: "DB")
            #expect(metadata.type == type, "Should store type: \(type.displayName)")
        }
    }

    // MARK: - Equatable

    @Test("Instances with same URL, type, and source are equal")
    func equatableEqualInstances() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        #expect(a == b)
    }

    @Test("Instances with different URLs are not equal")
    func equatableDifferentURL() {
        let a = ArtworkMetadata(
            url: URL(string: "https://example.com/a.jpg")!,
            type: .boxFront,
            source: "DB1"
        )
        let b = ArtworkMetadata(
            url: URL(string: "https://example.com/b.jpg")!,
            type: .boxFront,
            source: "DB1"
        )
        #expect(a != b)
    }

    @Test("Instances with different types are not equal")
    func equatableDifferentType() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxBack, source: "DB1")
        #expect(a != b)
    }

    @Test("Instances with different sources are not equal")
    func equatableDifferentSource() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxFront, source: "DB2")
        #expect(a != b)
    }

    @Test("Instances are equal even with different resolution values")
    func equatableIgnoresResolution() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, resolution: "1920x1080", source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxFront, resolution: "800x600", source: "DB1")
        // Equatable only considers url, type, and source per implementation
        #expect(a == b)
    }

    @Test("Instances are equal even with different description values")
    func equatableIgnoresDescription() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, description: "Front cover", source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxFront, description: "Box art front", source: "DB1")
        #expect(a == b)
    }

    @Test("Instances are equal even with different systemID values")
    func equatableIgnoresSystemID() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "DB1", systemID: .SNES)
        let b = ArtworkMetadata(url: url, type: .boxFront, source: "DB1", systemID: .NES)
        #expect(a == b)
    }

    // MARK: - Hashable

    @Test("Equal instances produce the same hash value")
    func hashableEqualInstances() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Instances with different URLs have different hash values")
    func hashableDifferentURL() {
        let a = ArtworkMetadata(
            url: URL(string: "https://example.com/a.jpg")!,
            type: .boxFront,
            source: "DB1"
        )
        let b = ArtworkMetadata(
            url: URL(string: "https://example.com/b.jpg")!,
            type: .boxFront,
            source: "DB1"
        )
        #expect(a.hashValue != b.hashValue)
    }

    @Test("Duplicate items are deduplicated in a Set")
    func setDeduplicationRemovesDuplicates() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "DB1")
        let b = ArtworkMetadata(url: url, type: .boxFront, source: "DB1") // duplicate
        let c = ArtworkMetadata(url: url, type: .boxBack, source: "DB1")   // different type

        let set: Set<ArtworkMetadata> = [a, b, c]
        #expect(set.count == 2, "Duplicate instances should be deduplicated")
    }

    @Test("Distinct items remain separate in a Set")
    func setKeepsDistinctItems() {
        let url1 = URL(string: "https://example.com/a.jpg")!
        let url2 = URL(string: "https://example.com/b.jpg")!
        let a = ArtworkMetadata(url: url1, type: .boxFront, source: "DB1")
        let b = ArtworkMetadata(url: url2, type: .boxFront, source: "DB1")

        let set: Set<ArtworkMetadata> = [a, b]
        #expect(set.count == 2)
    }

    @Test("Artwork from different sources not deduplicated even with same URL")
    func setKeepsDifferentSources() {
        let url = URL(string: "https://example.com/image.jpg")!
        let a = ArtworkMetadata(url: url, type: .boxFront, source: "OpenVGDB")
        let b = ArtworkMetadata(url: url, type: .boxFront, source: "LibretroDB")

        let set: Set<ArtworkMetadata> = [a, b]
        #expect(set.count == 2)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves all fields")
    func codableRoundTripAllFields() throws {
        let url = URL(string: "https://thumbnails.libretro.com/SNES/Named_Boxarts/Super%20Mario%20World.png")!
        let original = ArtworkMetadata(
            url: url,
            type: .boxFront,
            resolution: "640x480",
            description: "Box front artwork",
            source: "LibretroDB",
            systemID: .SNES
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ArtworkMetadata.self, from: data)

        #expect(decoded.url == original.url)
        #expect(decoded.type == original.type)
        #expect(decoded.resolution == original.resolution)
        #expect(decoded.description == original.description)
        #expect(decoded.source == original.source)
        #expect(decoded.systemID == original.systemID)
    }

    @Test("Codable round-trip preserves nil optional fields")
    func codableRoundTripNilFields() throws {
        let url = URL(string: "https://example.com/image.jpg")!
        let original = ArtworkMetadata(url: url, type: .screenshot, source: "TestDB")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ArtworkMetadata.self, from: data)

        #expect(decoded.url == original.url)
        #expect(decoded.type == original.type)
        #expect(decoded.source == original.source)
        #expect(decoded.resolution == nil)
        #expect(decoded.description == nil)
        #expect(decoded.systemID == nil)
    }

    @Test("Codable round-trip preserves all artwork types")
    func codableRoundTripAllTypes() throws {
        let url = URL(string: "https://example.com/image.jpg")!
        let types: [ArtworkType] = [.boxFront, .boxBack, .manual, .screenshot, .titleScreen, .fanArt, .banner, .clearLogo, .other]

        for type in types {
            let original = ArtworkMetadata(url: url, type: type, source: "DB")
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ArtworkMetadata.self, from: data)
            #expect(decoded.type == type, "Should preserve artwork type: \(type.displayName)")
        }
    }

    // MARK: - URL Integrity

    @Test("URL with percent encoding is preserved correctly")
    func urlPercentEncodingPreserved() {
        let urlString = "https://thumbnails.libretro.com/Nintendo%20-%20Super%20Nintendo%20Entertainment%20System/Named_Boxarts/Super%20Mario%20World%20(USA).png"
        let url = URL(string: urlString)!
        let metadata = ArtworkMetadata(url: url, type: .boxFront, source: "LibretroDB")
        #expect(metadata.url.absoluteString == urlString)
    }

    @Test("GameFAQs-style URL is stored correctly")
    func gameFAQsURLIsStoredCorrectly() {
        let url = URL(string: "https://gamefaqs.gamespot.com/a/box/3/5/1/307351_front.jpg")!
        let metadata = ArtworkMetadata(url: url, type: .boxFront, source: "OpenVGDB")
        #expect(metadata.url == url)
        #expect(metadata.url.host == "gamefaqs.gamespot.com")
    }

    @Test("TheGamesDB CDN URL is stored correctly")
    func theGamesDBURLIsStoredCorrectly() {
        let url = URL(string: "https://cdn.thegamesdb.net/images/boxart/front/1018-1.jpg")!
        let metadata = ArtworkMetadata(url: url, type: .boxFront, source: "TheGamesDB")
        #expect(metadata.url == url)
        #expect(metadata.url.host == "cdn.thegamesdb.net")
    }
}
