//
//  ArtworkLookupOnlineService.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/17/24.
//

import PVSystems

/// Protocol for artwork lookup operations that require an online connection
public protocol ArtworkLookupOnlineService: ArtworkLookupService {
    /// Get artwork mappings for ROMs
    func getArtworkMappings() async throws -> ArtworkMapping
}
