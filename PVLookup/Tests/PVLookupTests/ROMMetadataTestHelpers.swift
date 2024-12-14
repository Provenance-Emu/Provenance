import PVLookupTypes

extension ROMMetadata {
    /// Convenience initializer for testing purposes
    /// - Parameters:
    ///   - gameTitle: Title of the game
    ///   - region: Optional region
    ///   - systemID: System ID (defaults to 0)
    ///   - romHashMD5: MD5 hash of the ROM
    ///   - additionalFields: Dictionary of additional fields to set
    static func forTesting(
        gameTitle: String,
        region: String? = nil,
        systemID: Int = 0,
        romHashMD5: String? = nil,
        additionalFields: [String: String]? = nil
    ) -> ROMMetadata {
        ROMMetadata(
            gameTitle: gameTitle,
            boxImageURL: nil,
            region: region,
            gameDescription: nil,
            boxBackURL: nil,
            developer: additionalFields?["developer"],
            publisher: additionalFields?["publisher"],
            serial: nil,
            releaseDate: additionalFields?["releaseDate"],
            genres: nil,
            referenceURL: nil,
            releaseID: nil,
            language: nil,
            regionID: nil,
            systemID: systemID,
            systemShortName: nil,
            romFileName: nil,
            romHashCRC: nil,
            romHashMD5: romHashMD5,
            romID: nil
        )
    }
}
