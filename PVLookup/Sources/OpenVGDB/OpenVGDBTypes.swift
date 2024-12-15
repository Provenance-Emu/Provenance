import Foundation
import PVSystems

/// Internal representation of ROM metadata from the OpenVGDB database
internal struct OpenVGDBROMMetadata: Codable {
    let gameTitle: String
    let boxImageURL: String?
    let region: String?
    let gameDescription: String?
    let boxBackURL: String?
    let developer: String?
    let publisher: String?
    let serial: String?
    let releaseDate: String?
    let genres: String?
    let referenceURL: String?
    let releaseID: String?
    let language: String?
    let regionID: Int?
    let systemID: SystemIdentifier
    let systemShortName: String?
    let romFileName: String?
    let romHashCRC: String?
    let romHashMD5: String?
    let romID: Int?
}
