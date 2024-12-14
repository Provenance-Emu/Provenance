import Foundation

public extension ROMMetadata {
    /// Merges two ROMMetadata objects, with the first one taking priority
    /// Only empty or nil values from the first will be replaced by non-empty values from the second
    /// - Parameter other: The secondary ROMMetadata to merge with
    /// - Returns: A new ROMMetadata with merged values
    func merged(with other: ROMMetadata) -> ROMMetadata {
        return ROMMetadata(
            gameTitle: gameTitle.isEmpty ? other.gameTitle : gameTitle,
            boxImageURL: boxImageURL ?? other.boxImageURL,
            region: region ?? other.region,
            gameDescription: gameDescription ?? other.gameDescription,
            boxBackURL: boxBackURL ?? other.boxBackURL,
            developer: developer ?? other.developer,
            publisher: publisher ?? other.publisher,
            serial: serial ?? other.serial,
            releaseDate: releaseDate ?? other.releaseDate,
            genres: genres ?? other.genres,
            referenceURL: referenceURL ?? other.referenceURL,
            releaseID: releaseID ?? other.releaseID,
            language: language ?? other.language,
            regionID: regionID ?? other.regionID,
            systemID: systemID == 0 ? other.systemID : systemID,
            systemShortName: systemShortName ?? other.systemShortName,
            romFileName: romFileName ?? other.romFileName,
            romHashCRC: romHashCRC ?? other.romHashCRC,
            romHashMD5: romHashMD5 ?? other.romHashMD5,
            romID: romID ?? other.romID
        )
    }
}

public extension Array where Element == ROMMetadata {
    /// Merges two arrays of ROMMetadata, combining entries with matching MD5s and appending unique ones
    /// - Parameter other: The secondary array to merge with
    /// - Returns: A new array with merged ROMMetadata
    func merged(with other: [ROMMetadata]) -> [ROMMetadata] {
        var result: [ROMMetadata] = []
        var otherDict = Dictionary(grouping: other, by: { $0.romHashMD5 ?? "" })
            .mapValues { $0.first! }

        // Process primary array
        for metadata in self {
            if let md5 = metadata.romHashMD5,
               let otherMetadata = otherDict.removeValue(forKey: md5) {
                // Merge matching entries
                result.append(metadata.merged(with: otherMetadata))
            } else {
                // Keep unique entries from primary array
                result.append(metadata)
            }
        }

        // Append remaining unique entries from secondary array
        result.append(contentsOf: otherDict.values)

        return result
    }
}
