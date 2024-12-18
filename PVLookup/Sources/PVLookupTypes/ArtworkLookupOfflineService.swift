//
//  ArtworkLookupOfflineService.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/17/24.
//

/// Protocol specifically for artwork lookup operations that are fully offline
public protocol ArtworkLookupOfflineService: ArtworkLookupService {
    /// Get artwork mappings for ROMs
    func getArtworkMappings() async throws -> ArtworkMapping
}
