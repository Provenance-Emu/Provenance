import Foundation

/// Represents metadata for a ROM/game
public struct ROMMetadata: Codable, Sendable, Equatable {
    public let gameTitle: String
    public let boxImageURL: String?
    public let region: String?
    public let gameDescription: String?
    public let boxBackURL: String?
    public let developer: String?
    public let publisher: String?
    public let serial: String?
    public let releaseDate: String?
    public let genres: String?
    public let referenceURL: String?
    public let releaseID: String?
    public let language: String?
    public let regionID: Int?
    public let systemID: Int
    public let systemShortName: String?
    public let romFileName: String?
    public let romHashCRC: String?
    public let romHashMD5: String?
    public let romID: Int?

    public init(
        gameTitle: String,
        boxImageURL: String?,
        region: String?,
        gameDescription: String?,
        boxBackURL: String?,
        developer: String?,
        publisher: String?,
        serial: String?,
        releaseDate: String?,
        genres: String?,
        referenceURL: String?,
        releaseID: String?,
        language: String?,
        regionID: Int?,
        systemID: Int,
        systemShortName: String?,
        romFileName: String?,
        romHashCRC: String?,
        romHashMD5: String?,
        romID: Int?
    ) {
        self.gameTitle = gameTitle
        self.boxImageURL = boxImageURL
        self.region = region
        self.gameDescription = gameDescription
        self.boxBackURL = boxBackURL
        self.developer = developer
        self.publisher = publisher
        self.serial = serial
        self.releaseDate = releaseDate
        self.genres = genres
        self.referenceURL = referenceURL
        self.releaseID = releaseID
        self.language = language
        self.regionID = regionID
        self.systemID = systemID
        self.systemShortName = systemShortName
        self.romFileName = romFileName
        self.romHashCRC = romHashCRC
        self.romHashMD5 = romHashMD5
        self.romID = romID
    }
}
