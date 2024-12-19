import SQLite
import Foundation

private actor DatabaseConnection {
    private var connection: Connection?

    func execute(path: String, query: String) throws -> [LibretroDBROMMetadata] {
        if connection == nil {
            connection = try Connection(path, readonly: true)
        }
        guard let db = connection else {
            throw LibretroDBError.databaseError("Failed to create database connection")
        }

        let stmt = try db.prepare(query)
        var results: [LibretroDBROMMetadata] = []
        for row in stmt {
            var dict: [String: Any] = [:]
            for (index, name) in stmt.columnNames.enumerated() {
                dict[name] = row[index]
            }

            if let metadata = try? convertDictToLibretroMetadata(dict) {
                results.append(metadata)
            }
        }
        return results
    }

    private func convertDictToLibretroMetadata(_ dict: [String: Any]) throws -> LibretroDBROMMetadata {
        guard let gameTitle = dict["game_title"] as? String else {
            throw LibretroDBError.invalidMetadata
        }

        // Convert comma-separated genres string to array
        let genresArray: [String]?
        if let genresString = dict["genres"] as? String {
            genresArray = genresString.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            genresArray = nil
        }

        return LibretroDBROMMetadata(
            gameTitle: gameTitle,
            fullName: dict["full_name"] as? String,
            releaseYear: (dict["release_year"] as? NSNumber)?.intValue,
            releaseMonth: (dict["release_month"] as? NSNumber)?.intValue,
            developer: dict["developer_name"] as? String,
            publisher: dict["publisher_name"] as? String,
            rating: dict["rating_name"] as? String,
            franchise: dict["franchise_name"] as? String,
            region: dict["region_name"] as? String,
            genre: dict["genre_name"] as? String,
            romName: dict["rom_name"] as? String,
            romMD5: dict["rom_md5"] as? String,
            platform: (dict["platform_id"] as? NSNumber)?.stringValue,
            manufacturer: dict["manufacturer_name"] as? String,
            genres: genresArray,
            romFileName: dict["rom_name"] as? String
        )
    }
}
