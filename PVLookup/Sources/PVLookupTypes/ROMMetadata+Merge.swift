import Foundation
import PVSystems
import PVPrimitives

public extension ROMMetadata {
    /// Merges two ROMMetadata objects, with the first one taking priority
    /// Only empty or nil values from the first will be replaced by non-empty values from the second
    /// - Parameter other: The secondary ROMMetadata to merge with
    /// - Returns: A new ROMMetadata with merged values
    func merged(with other: ROMMetadata?) -> ROMMetadata {
        guard let other = other else { return self }
        // Helper function to choose the best system ID
        func chooseBestSystemID(_ first: SystemIdentifier, _ second: SystemIdentifier) -> SystemIdentifier {
            if case .Unknown = first {
                return second
            }
            return first
        }

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
            systemID: chooseBestSystemID(systemID, other.systemID),
            systemShortName: systemShortName ?? other.systemShortName,
            romFileName: romFileName ?? other.romFileName,
            romHashCRC: romHashCRC ?? other.romHashCRC,
            romHashMD5: romHashMD5 ?? other.romHashMD5,
            romID: romID ?? other.romID,
            isBIOS: isBIOS ?? other.isBIOS,
            source: [source, other.source].compactMap(\.self).joined(separator: ",")
        )
    }

    /// Merges metadata while preserving fields the user has explicitly customized.
    /// Only empty/nil fields that are NOT in `preservedFields` will be filled from `other`.
    /// - Parameters:
    ///   - other: The secondary ROMMetadata to merge with
    ///   - preservedFields: Set of fields protected from overwrite
    /// - Returns: A new ROMMetadata with merged values, respecting user customizations
    func merged(with other: ROMMetadata?, preserving preservedFields: GameCustomizedFields) -> ROMMetadata {
        guard let other = other else { return self }

        let keepTitle = !preservedFields.isDisjoint(with: .title)
        let keepArtwork = !preservedFields.isDisjoint(with: .artwork)
        let keepDescription = !preservedFields.isDisjoint(with: .description)
        let keepDeveloper = !preservedFields.isDisjoint(with: .developer)
        let keepPublisher = !preservedFields.isDisjoint(with: .publisher)
        let keepGenres = !preservedFields.isDisjoint(with: .genres)
        let keepReleaseDate = !preservedFields.isDisjoint(with: .releaseDate)
        let keepBoxBack = !preservedFields.isDisjoint(with: .boxBackArt)
        let keepReferenceURL = !preservedFields.isDisjoint(with: .referenceURL)

        func chooseBestSystemID(_ first: SystemIdentifier, _ second: SystemIdentifier) -> SystemIdentifier {
            if case .Unknown = first { return second }
            return first
        }

        return ROMMetadata(
            gameTitle: (keepTitle || !gameTitle.isEmpty) ? gameTitle : other.gameTitle,
            boxImageURL: (keepArtwork || boxImageURL != nil) ? boxImageURL : other.boxImageURL,
            region: region ?? other.region,
            gameDescription: (keepDescription || gameDescription != nil) ? gameDescription : other.gameDescription,
            boxBackURL: (keepBoxBack || boxBackURL != nil) ? boxBackURL : other.boxBackURL,
            developer: (keepDeveloper || developer != nil) ? developer : other.developer,
            publisher: (keepPublisher || publisher != nil) ? publisher : other.publisher,
            serial: serial ?? other.serial,
            releaseDate: (keepReleaseDate || releaseDate != nil) ? releaseDate : other.releaseDate,
            genres: (keepGenres || genres != nil) ? genres : other.genres,
            referenceURL: (keepReferenceURL || referenceURL != nil) ? referenceURL : other.referenceURL,
            releaseID: releaseID ?? other.releaseID,
            language: language ?? other.language,
            regionID: regionID ?? other.regionID,
            systemID: chooseBestSystemID(systemID, other.systemID),
            systemShortName: systemShortName ?? other.systemShortName,
            romFileName: romFileName ?? other.romFileName,
            romHashCRC: romHashCRC ?? other.romHashCRC,
            romHashMD5: romHashMD5 ?? other.romHashMD5,
            romID: romID ?? other.romID,
            isBIOS: isBIOS ?? other.isBIOS,
            source: [source, other.source].compactMap(\.self).joined(separator: ",")
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
