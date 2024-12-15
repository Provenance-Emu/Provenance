import Foundation
import PVLookupTypes
import Systems

extension ROMMetadata {
    /// Creates a test instance with minimal required fields
    static func testInstance(
        gameTitle: String = "Test Game",
        systemID: SystemIdentifier = .Unknown,
        romHashMD5: String? = nil
    ) -> ROMMetadata {
        ROMMetadata(
            gameTitle: gameTitle,
            boxImageURL: nil,
            region: nil,
            gameDescription: nil,
            boxBackURL: nil,
            developer: nil,
            publisher: nil,
            serial: nil,
            releaseDate: nil,
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
            romID: nil,
            isBIOS: nil
        )
    }
}
