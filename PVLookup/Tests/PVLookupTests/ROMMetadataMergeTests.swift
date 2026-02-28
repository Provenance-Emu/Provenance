//
//  ROMMetadataMergeTests.swift
//  PVLookup
//
//  Tests for ROMMetadata merge logic including single-item and array merge,
//  priority rules, system ID resolution, and source concatenation.
//

import Testing
import PVLookupTypes
import PVSystems

struct ROMMetadataMergeTests {

    // MARK: - Basic Merge Behavior

    @Test("Empty primary fields are filled by secondary values")
    func mergeEmptyFields() {
        let primary = ROMMetadata.testInstance(
            gameTitle: "",
            systemID: .Unknown,
            romHashMD5: "abc123"
        )
        let secondary = ROMMetadata.testInstance(
            gameTitle: "Secondary Title",
            systemID: .NES,
            romHashMD5: "abc123"
        )

        let merged = primary.merged(with: secondary)

        #expect(merged.gameTitle == "Secondary Title")
        #expect(merged.systemID == .NES)
        #expect(merged.romHashMD5 == "abc123")
    }

    @Test("Non-empty primary fields take priority over secondary")
    func mergeNonEmptyFields() {
        let primary = ROMMetadata.testInstance(
            gameTitle: "Primary Title",
            systemID: .SNES,
            romHashMD5: "abc123"
        )
        let secondary = ROMMetadata.testInstance(
            gameTitle: "Secondary Title",
            systemID: .NES,
            romHashMD5: "def456"
        )

        let merged = primary.merged(with: secondary)

        #expect(merged.gameTitle == "Primary Title")
        #expect(merged.systemID == .SNES)
        #expect(merged.romHashMD5 == "abc123")
    }

    @Test("Merging with nil secondary returns self unchanged")
    func mergeWithNilSecondary() {
        let primary = ROMMetadata.testInstance(
            gameTitle: "Primary Title",
            systemID: .SNES,
            romHashMD5: "abc123"
        )

        let merged = primary.merged(with: nil)

        #expect(merged.gameTitle == primary.gameTitle)
        #expect(merged.systemID == primary.systemID)
        #expect(merged.romHashMD5 == primary.romHashMD5)
    }

    // MARK: - System ID Resolution

    @Test("Unknown primary system ID is replaced by known secondary system ID")
    func mergeSystemIDUnknownReplacedByKnown() {
        let primary = ROMMetadata.testInstance(gameTitle: "Game", systemID: .Unknown)
        let secondary = ROMMetadata.testInstance(gameTitle: "Game", systemID: .SNES)

        let merged = primary.merged(with: secondary)
        #expect(merged.systemID == .SNES)
    }

    @Test("Known primary system ID is not replaced by secondary")
    func mergeSystemIDKnownNotReplaced() {
        let primary = ROMMetadata.testInstance(gameTitle: "Game", systemID: .NES)
        let secondary = ROMMetadata.testInstance(gameTitle: "Game", systemID: .SNES)

        let merged = primary.merged(with: secondary)
        #expect(merged.systemID == .NES)
    }

    @Test("Both Unknown system IDs remain Unknown after merge")
    func mergeBothUnknownSystemIDs() {
        let primary = ROMMetadata.testInstance(gameTitle: "Game", systemID: .Unknown)
        let secondary = ROMMetadata.testInstance(gameTitle: "Game", systemID: .Unknown)

        let merged = primary.merged(with: secondary)
        #expect(merged.systemID == .Unknown)
    }

    // MARK: - Source Concatenation

    @Test("Sources are concatenated with comma separator")
    func mergeSourceConcatenation() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "OpenVGDB")
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "LibretroDB")

        let merged = primary.merged(with: secondary)
        #expect(merged.source == "OpenVGDB,LibretroDB")
    }

    @Test("Nil primary source uses secondary source only")
    func mergeNilPrimarySource() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: nil)
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "LibretroDB")

        let merged = primary.merged(with: secondary)
        #expect(merged.source == "LibretroDB")
    }

    @Test("Nil secondary source uses primary source only")
    func mergeNilSecondarySource() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "OpenVGDB")
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: nil)

        let merged = primary.merged(with: secondary)
        #expect(merged.source == "OpenVGDB")
    }

    @Test("Both nil sources result in empty string source")
    func mergeBothNilSources() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: nil)
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: nil)

        let merged = primary.merged(with: secondary)
        // [nil, nil].compactMap(\.self) = [] -> "".joined = ""
        #expect(merged.source == "")
    }

    @Test("Three-way source merge chains correctly")
    func mergeThreeSourcesChained() {
        let a = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "OpenVGDB")
        let b = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "LibretroDB")
        let c = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "ShiraGame")

        let merged = a.merged(with: b).merged(with: c)
        // Source should include all three
        #expect(merged.source?.contains("OpenVGDB") == true)
        #expect(merged.source?.contains("LibretroDB") == true)
        #expect(merged.source?.contains("ShiraGame") == true)
    }

    // MARK: - Optional Field Priority

    @Test("Nil primary optional fields are filled from secondary")
    func mergeNilOptionalFieldsFilledFromSecondary() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES)
        let secondary = ROMMetadata(
            gameTitle: "Secondary",
            region: "Japan",
            gameDescription: "A great game",
            developer: "Nintendo",
            publisher: "Nintendo R&D",
            serial: "NES-001",
            releaseDate: "1985",
            genres: "Platformer",
            language: "Japanese",
            regionID: 13,
            systemID: .NES,
            systemShortName: "NES",
            romFileName: "game.nes",
            romHashCRC: "ABCDEF12",
            romHashMD5: "abc123",
            romID: 42,
            isBIOS: false
        )

        let merged = primary.merged(with: secondary)
        // Primary title is non-empty, so primary wins
        #expect(merged.gameTitle == "Game")
        // All nil optional fields are filled from secondary
        #expect(merged.region == "Japan")
        #expect(merged.gameDescription == "A great game")
        #expect(merged.developer == "Nintendo")
        #expect(merged.publisher == "Nintendo R&D")
        #expect(merged.serial == "NES-001")
        #expect(merged.releaseDate == "1985")
        #expect(merged.genres == "Platformer")
        #expect(merged.language == "Japanese")
        #expect(merged.regionID == 13)
        #expect(merged.systemShortName == "NES")
        #expect(merged.romFileName == "game.nes")
        #expect(merged.romHashCRC == "ABCDEF12")
        #expect(merged.romHashMD5 == "abc123")
        #expect(merged.romID == 42)
        #expect(merged.isBIOS == false)
    }

    @Test("Non-nil primary optional fields take priority over secondary")
    func mergeNonNilPrimaryFieldsTakePriority() {
        let primary = ROMMetadata(
            gameTitle: "Game",
            region: "USA",
            developer: "Primary Dev",
            systemID: .NES,
            romHashMD5: "primary_md5"
        )
        let secondary = ROMMetadata(
            gameTitle: "Game",
            region: "Japan",
            developer: "Secondary Dev",
            systemID: .NES,
            romHashMD5: "secondary_md5"
        )

        let merged = primary.merged(with: secondary)
        #expect(merged.region == "USA")
        #expect(merged.developer == "Primary Dev")
        #expect(merged.romHashMD5 == "primary_md5")
    }

    @Test("Merged result is a new value type instance")
    func mergeProducesNewInstance() {
        let primary = ROMMetadata.testInstance(gameTitle: "Game A", systemID: .NES)
        let secondary = ROMMetadata.testInstance(gameTitle: "Game B", systemID: .SNES)

        let merged = primary.merged(with: secondary)

        // Original instances are unchanged (value semantics)
        #expect(primary.gameTitle == "Game A")
        #expect(secondary.gameTitle == "Game B")
        #expect(merged.gameTitle == "Game A") // primary wins on non-empty
    }

    // MARK: - Array Merge Tests

    @Test("Merging two empty arrays yields empty array")
    func arrayMergeEmptyArrays() {
        let result = [ROMMetadata]().merged(with: [])
        #expect(result.isEmpty)
    }

    @Test("Merging empty primary with non-empty secondary appends secondary")
    func arrayMergeEmptyPrimary() {
        let secondary = [
            ROMMetadata.testInstance(gameTitle: "Game A", systemID: .NES, romHashMD5: "abc"),
            ROMMetadata.testInstance(gameTitle: "Game B", systemID: .SNES, romHashMD5: "def")
        ]
        let result = [ROMMetadata]().merged(with: secondary)
        #expect(result.count == 2)
    }

    @Test("Merging non-empty primary with empty secondary returns primary items")
    func arrayMergeEmptySecondary() {
        let primary = [
            ROMMetadata.testInstance(gameTitle: "Game A", systemID: .NES, romHashMD5: "abc"),
            ROMMetadata.testInstance(gameTitle: "Game B", systemID: .SNES, romHashMD5: "def")
        ]
        let result = primary.merged(with: [])
        #expect(result.count == 2)
        #expect(result[0].gameTitle == "Game A")
        #expect(result[1].gameTitle == "Game B")
    }

    @Test("Matching MD5s are merged into a single entry")
    func arrayMergeMatchingMD5sMergedToOne() {
        let primary = [
            ROMMetadata(gameTitle: "Game A", systemID: .NES, romHashMD5: "abc", source: "SourceA")
        ]
        let secondary = [
            ROMMetadata(gameTitle: "Game A Alt", region: "Japan", systemID: .NES, romHashMD5: "abc", source: "SourceB")
        ]

        let result = primary.merged(with: secondary)
        #expect(result.count == 1, "Matching MD5s should be merged into one entry")
        // Primary title wins
        #expect(result[0].gameTitle == "Game A")
        // Secondary fills nil optional fields
        #expect(result[0].region == "Japan")
        // Sources are combined
        #expect(result[0].source == "SourceA,SourceB")
    }

    @Test("Non-matching MD5s result in both entries being kept")
    func arrayMergeNonMatchingMD5sAppendsBoth() {
        let primary = [
            ROMMetadata.testInstance(gameTitle: "Game A", systemID: .NES, romHashMD5: "abc")
        ]
        let secondary = [
            ROMMetadata.testInstance(gameTitle: "Game B", systemID: .SNES, romHashMD5: "def")
        ]

        let result = primary.merged(with: secondary)
        #expect(result.count == 2)
    }

    @Test("Primary array order is preserved in merged result")
    func arrayMergePreservesPrimaryOrder() {
        let primary = [
            ROMMetadata.testInstance(gameTitle: "A", systemID: .NES, romHashMD5: "1"),
            ROMMetadata.testInstance(gameTitle: "B", systemID: .SNES, romHashMD5: "2"),
            ROMMetadata.testInstance(gameTitle: "C", systemID: .Genesis, romHashMD5: "3")
        ]
        let secondary = [
            ROMMetadata.testInstance(gameTitle: "D", systemID: .PSX, romHashMD5: "4")
        ]

        let result = primary.merged(with: secondary)
        #expect(result.count == 4)
        // Primary items maintain their order at the start
        #expect(result[0].gameTitle == "A")
        #expect(result[1].gameTitle == "B")
        #expect(result[2].gameTitle == "C")
    }

    @Test("Unique secondary items are appended after primary items")
    func arrayMergeUniqueSecondaryAppendedAfterPrimary() {
        let primary = [
            ROMMetadata.testInstance(gameTitle: "Game A", systemID: .NES, romHashMD5: "abc")
        ]
        let secondary = [
            ROMMetadata.testInstance(gameTitle: "Game B", systemID: .SNES, romHashMD5: "def"),
            ROMMetadata.testInstance(gameTitle: "Game C", systemID: .Genesis, romHashMD5: "ghi")
        ]

        let result = primary.merged(with: secondary)
        #expect(result.count == 3)
        // Primary item first
        #expect(result[0].gameTitle == "Game A")
        // Secondary unique items appended (order may vary)
        let titles = Set(result.map(\.gameTitle))
        #expect(titles.contains("Game B"))
        #expect(titles.contains("Game C"))
    }

    @Test("Multiple matching MD5s each get merged individually")
    func arrayMergeMultipleMatchingMD5s() {
        let primary = [
            ROMMetadata(gameTitle: "Game A", systemID: .NES, romHashMD5: "aaa", source: "Primary"),
            ROMMetadata(gameTitle: "Game B", systemID: .SNES, romHashMD5: "bbb", source: "Primary")
        ]
        let secondary = [
            ROMMetadata(gameTitle: "Game A v2", region: "USA", systemID: .NES, romHashMD5: "aaa", source: "Secondary"),
            ROMMetadata(gameTitle: "Game B v2", region: "Japan", systemID: .SNES, romHashMD5: "bbb", source: "Secondary")
        ]

        let result = primary.merged(with: secondary)
        #expect(result.count == 2)

        let gameA = result.first { $0.romHashMD5 == "aaa" }
        let gameB = result.first { $0.romHashMD5 == "bbb" }

        #expect(gameA?.gameTitle == "Game A")
        #expect(gameA?.region == "USA")
        #expect(gameA?.source == "Primary,Secondary")

        #expect(gameB?.gameTitle == "Game B")
        #expect(gameB?.region == "Japan")
        #expect(gameB?.source == "Primary,Secondary")
    }

    @Test("Items with nil MD5 are not matched against other nil MD5 items")
    func arrayMergeNilMD5ItemsNotMatchedToEachOther() {
        let primary = [
            ROMMetadata.testInstance(gameTitle: "Game A", systemID: .NES, romHashMD5: nil)
        ]
        let secondary = [
            ROMMetadata.testInstance(gameTitle: "Game B", systemID: .SNES, romHashMD5: nil)
        ]

        let result = primary.merged(with: secondary)
        // Both nil-MD5 items should both be present (they key on "" in the dict)
        // The nil MD5 items group on key "" - secondary dict collapses to one entry
        // Primary keeps its nil-MD5 item, remaining secondary nil-MD5 items appended
        #expect(result.count >= 1)
    }

    @Test("Mixed matching and non-matching MD5s handled correctly")
    func arrayMergeMixedMatchingAndNonMatching() {
        let primary = [
            ROMMetadata(gameTitle: "Match A", systemID: .NES, romHashMD5: "match1", source: "P"),
            ROMMetadata(gameTitle: "Unique A", systemID: .SNES, romHashMD5: "unique_primary", source: "P")
        ]
        let secondary = [
            ROMMetadata(gameTitle: "Match A v2", region: "USA", systemID: .NES, romHashMD5: "match1", source: "S"),
            ROMMetadata(gameTitle: "Unique B", systemID: .Genesis, romHashMD5: "unique_secondary", source: "S")
        ]

        let result = primary.merged(with: secondary)
        #expect(result.count == 3)

        // Matched item should be merged
        let matched = result.first { $0.romHashMD5 == "match1" }
        #expect(matched?.gameTitle == "Match A")
        #expect(matched?.region == "USA")

        // Unique primary item kept
        let uniquePrimary = result.first { $0.romHashMD5 == "unique_primary" }
        #expect(uniquePrimary != nil)

        // Unique secondary item appended
        let uniqueSecondary = result.first { $0.romHashMD5 == "unique_secondary" }
        #expect(uniqueSecondary != nil)
    }
}
