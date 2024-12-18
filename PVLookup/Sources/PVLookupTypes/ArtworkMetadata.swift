//
//  ArtworkMetadata.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/17/24.
//

import Foundation
import PVSystems

/// Represents a single piece of artwork with its metadata
public struct ArtworkMetadata: Codable, Sendable {
    /// The URL to the artwork image
    public let url: URL

    /// The type of artwork
    public let type: ArtworkType

    /// Optional resolution of the artwork (e.g., "1920x1080")
    public let resolution: String?

    /// Optional description or caption
    public let description: String?

    /// Source database or service that provided this artwork
    public let source: String

    /// System identifier associated with this artwork
    public let systemID: SystemIdentifier?

    public init(
        url: URL,
        type: ArtworkType,
        resolution: String? = nil,
        description: String? = nil,
        source: String,
        systemID: SystemIdentifier? = nil
    ) {
        self.url = url
        self.type = type
        self.resolution = resolution
        self.description = description
        self.source = source
        self.systemID = systemID
    }
}

extension ArtworkMetadata: Hashable {
    public static func == (lhs: ArtworkMetadata, rhs: ArtworkMetadata) -> Bool {
        lhs.url == rhs.url
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
