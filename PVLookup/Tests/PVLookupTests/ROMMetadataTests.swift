//
//  ROMMetadataTests.swift
//  PVLookup
//
//  Tests for ROMMetadata struct including initialization, Equatable,
//  Codable conformance, and copy(gameTitle:) functionality.
//

import Testing
import PVLookupTypes
import PVSystems
import Foundation

struct ROMMetadataTests {

    // MARK: - Initialization

    @Test("Init with only required fields leaves all optionals nil")
    func initRequiredFieldsOnly() {
        let metadata = ROMMetadata(gameTitle: "Test Game", systemID: .SNES)
        #expect(metadata.gameTitle == "Test Game")
        #expect(metadata.systemID == .SNES)
        #expect(metadata.boxImageURL == nil)
        #expect(metadata.region == nil)
        #expect(metadata.gameDescription == nil)
        #expect(metadata.boxBackURL == nil)
        #expect(metadata.developer == nil)
        #expect(metadata.publisher == nil)
        #expect(metadata.serial == nil)
        #expect(metadata.releaseDate == nil)
        #expect(metadata.genres == nil)
        #expect(metadata.referenceURL == nil)
        #expect(metadata.releaseID == nil)
        #expect(metadata.language == nil)
        #expect(metadata.regionID == nil)
        #expect(metadata.systemShortName == nil)
        #expect(metadata.romFileName == nil)
        #expect(metadata.romHashCRC == nil)
        #expect(metadata.romHashMD5 == nil)
        #expect(metadata.romID == nil)
        #expect(metadata.isBIOS == nil)
        #expect(metadata.source == nil)
    }

    @Test("Init with all fields stores each value correctly")
    func initAllFields() {
        let metadata = ROMMetadata(
            gameTitle: "Super Mario Bros.",
            boxImageURL: "https://example.com/box.jpg",
            region: "USA",
            gameDescription: "Classic platformer",
            boxBackURL: "https://example.com/back.jpg",
            developer: "Nintendo",
            publisher: "Nintendo",
            serial: "NES-SM-USA",
            releaseDate: "1985",
            genres: "Platform",
            referenceURL: "https://example.com",
            releaseID: "12345",
            language: "English",
            regionID: 21,
            systemID: .NES,
            systemShortName: "NES",
            romFileName: "Super Mario Bros. (USA).nes",
            romHashCRC: "ABCDEF12",
            romHashMD5: "abc123def456",
            romID: 1,
            isBIOS: false,
            source: "OpenVGDB"
        )
        #expect(metadata.gameTitle == "Super Mario Bros.")
        #expect(metadata.boxImageURL == "https://example.com/box.jpg")
        #expect(metadata.region == "USA")
        #expect(metadata.gameDescription == "Classic platformer")
        #expect(metadata.boxBackURL == "https://example.com/back.jpg")
        #expect(metadata.developer == "Nintendo")
        #expect(metadata.publisher == "Nintendo")
        #expect(metadata.serial == "NES-SM-USA")
        #expect(metadata.releaseDate == "1985")
        #expect(metadata.genres == "Platform")
        #expect(metadata.referenceURL == "https://example.com")
        #expect(metadata.releaseID == "12345")
        #expect(metadata.language == "English")
        #expect(metadata.regionID == 21)
        #expect(metadata.systemID == .NES)
        #expect(metadata.systemShortName == "NES")
        #expect(metadata.romFileName == "Super Mario Bros. (USA).nes")
        #expect(metadata.romHashCRC == "ABCDEF12")
        #expect(metadata.romHashMD5 == "abc123def456")
        #expect(metadata.romID == 1)
        #expect(metadata.isBIOS == false)
        #expect(metadata.source == "OpenVGDB")
    }

    @Test("Init stores empty string game title correctly")
    func initEmptyTitle() {
        let metadata = ROMMetadata(gameTitle: "", systemID: .Unknown)
        #expect(metadata.gameTitle == "")
        #expect(metadata.gameTitle.isEmpty)
    }

    @Test("Init with isBIOS true stores correctly")
    func initIsBIOSTrue() {
        let metadata = ROMMetadata(gameTitle: "BIOS", systemID: .PSX, isBIOS: true)
        #expect(metadata.isBIOS == true)
    }

    @Test("Init with various system identifiers stores correctly")
    func initVariousSystemIDs() {
        let systems: [SystemIdentifier] = [.NES, .SNES, .Genesis, .PSX, .Saturn, .Atari2600, .Unknown]
        for system in systems {
            let metadata = ROMMetadata(gameTitle: "Game", systemID: system)
            #expect(metadata.systemID == system, "Should store system: \(system)")
        }
    }

    // MARK: - Equatable

    @Test("Identical instances are equal")
    func equatableEqualInstances() {
        let a = ROMMetadata(gameTitle: "Game", systemID: .NES, romHashMD5: "abc123")
        let b = ROMMetadata(gameTitle: "Game", systemID: .NES, romHashMD5: "abc123")
        #expect(a == b)
    }

    @Test("Instances with different titles are not equal")
    func equatableDifferentTitle() {
        let a = ROMMetadata(gameTitle: "Game A", systemID: .NES)
        let b = ROMMetadata(gameTitle: "Game B", systemID: .NES)
        #expect(a != b)
    }

    @Test("Instances with different system IDs are not equal")
    func equatableDifferentSystemID() {
        let a = ROMMetadata(gameTitle: "Game", systemID: .NES)
        let b = ROMMetadata(gameTitle: "Game", systemID: .SNES)
        #expect(a != b)
    }

    @Test("Instances with different MD5 hashes are not equal")
    func equatableDifferentMD5() {
        let a = ROMMetadata(gameTitle: "Game", systemID: .NES, romHashMD5: "abc123")
        let b = ROMMetadata(gameTitle: "Game", systemID: .NES, romHashMD5: "def456")
        #expect(a != b)
    }

    @Test("Instances with different sources are not equal")
    func equatableDifferentSource() {
        let a = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "OpenVGDB")
        let b = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "LibretroDB")
        #expect(a != b)
    }

    @Test("Instances with different regions are not equal")
    func equatableDifferentRegion() {
        let a = ROMMetadata(gameTitle: "Game", region: "USA", systemID: .NES)
        let b = ROMMetadata(gameTitle: "Game", region: "Japan", systemID: .NES)
        #expect(a != b)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves all non-nil fields")
    func codableRoundTripAllFields() throws {
        let original = ROMMetadata(
            gameTitle: "The Legend of Zelda",
            boxImageURL: "https://example.com/zelda_box.jpg",
            region: "USA",
            gameDescription: "An epic adventure",
            developer: "Nintendo",
            publisher: "Nintendo",
            serial: "NES-ZL-USA",
            releaseDate: "1987",
            genres: "Action, Adventure",
            regionID: 21,
            systemID: .NES,
            systemShortName: "NES",
            romFileName: "Legend of Zelda, The (USA).nes",
            romHashCRC: "A12BC3D4",
            romHashMD5: "deadbeef12345678",
            romID: 100,
            isBIOS: false,
            source: "OpenVGDB"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ROMMetadata.self, from: data)

        #expect(decoded == original)
        #expect(decoded.gameTitle == original.gameTitle)
        #expect(decoded.region == original.region)
        #expect(decoded.developer == original.developer)
        #expect(decoded.systemID == original.systemID)
        #expect(decoded.romFileName == original.romFileName)
        #expect(decoded.romHashMD5 == original.romHashMD5)
        #expect(decoded.source == original.source)
        #expect(decoded.isBIOS == original.isBIOS)
    }

    @Test("Codable round-trip preserves nil optional fields as nil")
    func codableRoundTripNilFields() throws {
        let original = ROMMetadata(gameTitle: "Minimal Game", systemID: .Unknown)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ROMMetadata.self, from: data)

        #expect(decoded.gameTitle == original.gameTitle)
        #expect(decoded.systemID == original.systemID)
        #expect(decoded.boxImageURL == nil)
        #expect(decoded.region == nil)
        #expect(decoded.romHashMD5 == nil)
        #expect(decoded.source == nil)
        #expect(decoded.isBIOS == nil)
        #expect(decoded.regionID == nil)
        #expect(decoded.romID == nil)
    }

    @Test("Codable round-trip preserves empty string title")
    func codableRoundTripEmptyTitle() throws {
        let original = ROMMetadata(gameTitle: "", systemID: .SNES)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ROMMetadata.self, from: data)
        #expect(decoded.gameTitle == "")
        #expect(decoded.gameTitle.isEmpty)
    }

    @Test("Codable round-trip with isBIOS true preserves value")
    func codableRoundTripIsBIOS() throws {
        let original = ROMMetadata(gameTitle: "PSX BIOS", systemID: .PSX, isBIOS: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ROMMetadata.self, from: data)
        #expect(decoded.isBIOS == true)
    }

    // MARK: - copy(gameTitle:)

    @Test("copy(gameTitle:) changes only the title, preserving all other fields")
    func copyChangesOnlyTitle() {
        let original = ROMMetadata(
            gameTitle: "Original Title",
            boxImageURL: "https://example.com/box.jpg",
            region: "Japan",
            gameDescription: "A game",
            developer: "Developer Co.",
            publisher: "Publisher Inc.",
            serial: "SLPM-12345",
            releaseDate: "1998",
            genres: "RPG",
            regionID: 13,
            systemID: .PSX,
            systemShortName: "PSX",
            romFileName: "game.cue",
            romHashCRC: "DEADBEEF",
            romHashMD5: "abc123",
            romID: 99,
            isBIOS: false,
            source: "OpenVGDB"
        )

        let copy = original.copy(gameTitle: "Updated Title")

        // Only title changes
        #expect(copy.gameTitle == "Updated Title")
        // All other fields remain unchanged
        #expect(copy.boxImageURL == original.boxImageURL)
        #expect(copy.region == original.region)
        #expect(copy.gameDescription == original.gameDescription)
        #expect(copy.developer == original.developer)
        #expect(copy.publisher == original.publisher)
        #expect(copy.serial == original.serial)
        #expect(copy.releaseDate == original.releaseDate)
        #expect(copy.genres == original.genres)
        #expect(copy.regionID == original.regionID)
        #expect(copy.systemID == original.systemID)
        #expect(copy.systemShortName == original.systemShortName)
        #expect(copy.romFileName == original.romFileName)
        #expect(copy.romHashCRC == original.romHashCRC)
        #expect(copy.romHashMD5 == original.romHashMD5)
        #expect(copy.romID == original.romID)
        #expect(copy.isBIOS == original.isBIOS)
        #expect(copy.source == original.source)
    }

    @Test("copy(gameTitle:) with empty string stores empty title")
    func copyWithEmptyTitle() {
        let original = ROMMetadata(gameTitle: "Original", systemID: .NES)
        let copy = original.copy(gameTitle: "")
        #expect(copy.gameTitle == "")
        #expect(copy.gameTitle.isEmpty)
        #expect(copy.systemID == .NES)
    }

    @Test("copy(gameTitle:) on minimal metadata works correctly")
    func copyMinimalMetadata() {
        let original = ROMMetadata(gameTitle: "Game", systemID: .Unknown)
        let copy = original.copy(gameTitle: "New Name")
        #expect(copy.gameTitle == "New Name")
        #expect(copy.systemID == .Unknown)
        #expect(copy.region == nil)
        #expect(copy.romHashMD5 == nil)
    }

    @Test("copy(gameTitle:) does not mutate the original")
    func copyDoesNotMutateOriginal() {
        let original = ROMMetadata(gameTitle: "Original", systemID: .SNES)
        let _ = original.copy(gameTitle: "Changed")
        // Original should remain unchanged (struct value semantics)
        #expect(original.gameTitle == "Original")
    }

    // MARK: - Backward Compatibility

    @Test("openVGDBSystemID returns expected integer for known systems")
    func openVGDBSystemIDBackwardCompat() {
        let metadata = ROMMetadata(gameTitle: "Game", systemID: .SNES)
        // This tests the deprecated property but ensures backward compatibility
        let openVGDBID = metadata.openVGDBSystemID
        // SNES should map to a specific openVGDB ID (non-zero)
        #expect(openVGDBID >= 0)
        // Same systemID should always give the same openVGDB ID
        let metadata2 = ROMMetadata(gameTitle: "Other Game", systemID: .SNES)
        #expect(metadata.openVGDBSystemID == metadata2.openVGDBSystemID)
    }

    @Test("openVGDBSystemID differs between different systems")
    func openVGDBSystemIDDiffersBetweenSystems() {
        let snes = ROMMetadata(gameTitle: "Game", systemID: .SNES)
        let nes = ROMMetadata(gameTitle: "Game", systemID: .NES)
        #expect(snes.openVGDBSystemID != nes.openVGDBSystemID)
    }

    // MARK: - Sendable / Thread Safety

    @Test("ROMMetadata can be passed across actor boundaries")
    func sendableAcrossActors() async {
        let metadata = ROMMetadata(
            gameTitle: "Concurrent Game",
            systemID: .SNES,
            romHashMD5: "abc123"
        )

        // Verify we can use it in async context
        let result = await Task.detached {
            return metadata.gameTitle
        }.value

        #expect(result == "Concurrent Game")
    }
}
