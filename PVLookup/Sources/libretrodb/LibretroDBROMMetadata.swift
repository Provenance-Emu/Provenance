import PVLookupTypes
import PVSystems

/// Internal representation of ROM metadata from the libretrodb database
struct LibretroDBROMMetadata: Codable {
    let gameTitle: String
    let fullName: String?
    let releaseYear: Int?
    let releaseMonth: Int?
    let developer: String?
    let publisher: String?
    let rating: String?
    let franchise: String?
    let region: String?
    let genre: String?
    let romName: String?
    let romMD5: String?
    let platform: String?
    let manufacturer: String?
    let genres: [String]?
    let romFileName: String?

    /// Convert platform ID to SystemIdentifier
    var systemID: SystemIdentifier? {
        guard let platformID = platform,
              let databaseId = Int(platformID) else { return nil }
        return SystemIdentifier.fromLibretroDatabaseID(databaseId)
    }
}
