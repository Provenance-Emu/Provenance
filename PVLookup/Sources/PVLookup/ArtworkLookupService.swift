//
//  ArtworkLookupService.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/15/24.
//

import Foundation
import ROMMetadataProvider
import PVLookupTypes
import PVSystems

/// Protocol specifically for artwork lookup operations
public protocol ArtworkLookupService {
    /// Get artwork mappings for ROMs
    func getArtworkMappings() async throws -> ArtworkMapping

    /// Get possible URLs for a ROM
    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]?
}
