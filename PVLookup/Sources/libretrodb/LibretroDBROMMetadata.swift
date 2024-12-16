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
}
