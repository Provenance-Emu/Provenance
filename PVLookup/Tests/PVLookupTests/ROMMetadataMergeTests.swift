import Testing
import PVLookupTypes
import Systems

struct ROMMetadataMergeTests {
    @Test
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

    @Test
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
}
