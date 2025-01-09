import Foundation
import PVSystems

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
    public let systemID: SystemIdentifier
    public let systemShortName: String?
    public let romFileName: String?
    public let romHashCRC: String?
    public let romHashMD5: String?
    public let romID: Int?
    public let isBIOS: Bool?
    public let source: String?

    public init(
        gameTitle: String,
        boxImageURL: String? = nil,
        region: String? = nil,
        gameDescription: String? = nil,
        boxBackURL: String? = nil,
        developer: String? = nil,
        publisher: String? = nil,
        serial: String? = nil,
        releaseDate: String? = nil,
        genres: String? = nil,
        referenceURL: String? = nil,
        releaseID: String? = nil,
        language: String? = nil,
        regionID: Int? = nil,
        systemID: SystemIdentifier,
        systemShortName: String? = nil,
        romFileName: String? = nil,
        romHashCRC: String? = nil,
        romHashMD5: String? = nil,
        romID: Int? = nil,
        isBIOS: Bool? = nil,
        source: String? = nil
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
        self.isBIOS = isBIOS
        self.source = source
    }

    /// Creates a copy with a new title
    func copy(gameTitle: String) -> ROMMetadata {
        return ROMMetadata(
            gameTitle: gameTitle,
            boxImageURL: self.boxImageURL,
            region: self.region,
            gameDescription: self.gameDescription,
            boxBackURL: self.boxBackURL,
            developer: self.developer,
            publisher: self.publisher,
            serial: self.serial,
            releaseDate: self.releaseDate,
            genres: self.genres,
            referenceURL: self.referenceURL,
            releaseID: self.releaseID,
            language: self.language,
            regionID: self.regionID,
            systemID: self.systemID,
            systemShortName: self.systemShortName,
            romFileName: self.romFileName,
            romHashCRC: self.romHashCRC,
            romHashMD5: self.romHashMD5,
            romID: self.romID,
            isBIOS: self.isBIOS,
            source: self.source
        )
    }
}

// For backward compatibility
public extension ROMMetadata {
    /// Get the OpenVGDB system ID (deprecated)
    @available(*, deprecated, message: "Use systemID directly")
    var openVGDBSystemID: Int {
        return systemID.openVGDBID
    }
}
