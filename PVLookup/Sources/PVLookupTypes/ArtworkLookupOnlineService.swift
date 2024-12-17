//
//  ArtworkLookupOnlineService.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/17/24.
//

import PVSystems

/// Protocol for artwork lookup operations that require an online connection
public protocol ArtworkLookupOnlineService: ArtworkLookupService {
    func searchArtwork(byGameName name: String, systemID: SystemIdentifier?, artworkTypes: [ArtworkType]?) async throws -> [ArtworkMetadata]?
}
