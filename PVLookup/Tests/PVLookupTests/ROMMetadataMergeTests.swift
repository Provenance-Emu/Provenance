import Testing
@testable import PVLookupTypes

final class ROMMetadataMergeTests {
    func testSingleMetadataMerge() {
        let primary = ROMMetadata(
            gameTitle: "Primary Title",
            boxImageURL: nil,
            region: nil,
            gameDescription: "Primary Description",
            boxBackURL: nil,
            developer: nil,
            publisher: "",
            serial: nil,
            releaseDate: nil,
            genres: nil,
            referenceURL: nil,
            releaseID: nil,
            language: nil,
            regionID: nil,
            systemID: 0,
            systemShortName: nil,
            romFileName: "primary.rom",
            romHashCRC: nil,
            romHashMD5: "ABC123",
            romID: nil
        )

        let secondary = ROMMetadata(
            gameTitle: "Secondary Title",
            boxImageURL: "http://example.com/box.jpg",
            region: "USA",
            gameDescription: "Secondary Description",
            boxBackURL: "http://example.com/back.jpg",
            developer: "Developer",
            publisher: "Publisher",
            serial: "123",
            releaseDate: "2024",
            genres: "Action",
            referenceURL: nil,
            releaseID: nil,
            language: "en",
            regionID: 1,
            systemID: 25,
            systemShortName: "NES",
            romFileName: "secondary.rom",
            romHashCRC: "CRC123",
            romHashMD5: "ABC123",
            romID: 456
        )

        let merged = primary.merged(with: secondary)

        // Primary values should be preserved when non-empty
        #expect(merged.gameTitle == "Primary Title")
        #expect(merged.gameDescription == "Primary Description")
        #expect(merged.romFileName == "primary.rom")

        // Secondary values should fill in empty/nil primary values
        #expect(merged.boxImageURL == "http://example.com/box.jpg")
        #expect(merged.region == "USA")
        #expect(merged.developer == "Developer")
        #expect(merged.publisher == "Publisher")
        #expect(merged.systemID == 25)
    }

    func testArrayMerge() {
        let primary: [ROMMetadata] = [
            .forTesting(gameTitle: "Game 1", romHashMD5: "ABC123"),
            .forTesting(gameTitle: "Game 2", romHashMD5: "DEF456")
        ]

        let secondary: [ROMMetadata] = [
            .forTesting(gameTitle: "Game 1 Alt", region: "USA", romHashMD5: "ABC123"),
            .forTesting(gameTitle: "Game 3", romHashMD5: "GHI789")
        ]

        let merged = primary.merged(with: secondary)

        #expect(merged.count == 3)

        // Check merged entry
        let mergedGame = merged.first { $0.romHashMD5 == "ABC123" }
        #expect(mergedGame?.gameTitle == "Game 1")
        #expect(mergedGame?.region == "USA")

        // Check unique entries
        #expect(merged.contains { $0.romHashMD5 == "DEF456" })
        #expect(merged.contains { $0.romHashMD5 == "GHI789" })
    }

    // Example of using additionalFields
    func testComplexMetadata() {
        let metadata = ROMMetadata.forTesting(
            gameTitle: "Test Game",
            region: "USA",
            systemID: 25,
            romHashMD5: "ABC123",
            additionalFields: [
                "developer": "Test Developer",
                "publisher": "Test Publisher",
                "releaseDate": "2024"
            ]
        )

        #expect(metadata.gameTitle == "Test Game")
        #expect(metadata.developer == "Test Developer")
        #expect(metadata.publisher == "Test Publisher")
        #expect(metadata.releaseDate == "2024")
    }
}
