//
//  SkinCatalog.swift
//  PVUIBase
//
//  Created for Provenance (GitHub issue #2514)
//

import Foundation
import PVPrimitives

// MARK: - Catalog Root

/// Root catalog object fetched from the remote skin catalog.
/// Contains metadata about the catalog itself and an array of available skin entries.
public struct SkinCatalog: Codable, Sendable {
    /// The catalog schema version
    public let version: Int

    /// When the catalog was last updated on the server
    public let lastUpdated: Date

    /// All skins listed in the catalog
    public let skins: [SkinCatalogEntry]

    public init(version: Int, lastUpdated: Date, skins: [SkinCatalogEntry]) {
        self.version = version
        self.lastUpdated = lastUpdated
        self.skins = skins
    }
}

// MARK: - Catalog Entry

/// A single skin listed in the remote catalog.
/// Each entry describes a downloadable controller skin with metadata for filtering,
/// sorting, and displaying in the skin browser UI.
public struct SkinCatalogEntry: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier for this skin (e.g. "com.author.skin-name")
    public let id: String

    /// Human-readable skin name
    public let name: String

    /// The skin author / creator
    public let author: String

    /// System short codes this skin supports (e.g. "gba", "snes", "nes")
    public let systems: [String]

    /// Optional game type identifier URN (e.g. "com.rileytestut.delta.game.gba")
    public let gameTypeIdentifier: String?

    /// Semantic version of the skin (e.g. "1.2.0")
    public let version: String?

    /// URL to download the .deltaskin file
    public let downloadURL: URL

    /// URL for a thumbnail image
    public let thumbnailURL: URL?

    /// URLs for full-size screenshot images
    public let screenshotURLs: [URL]?

    /// Searchable tags (e.g. "retro", "dark", "minimal")
    public let tags: [String]?

    /// Device support tokens (e.g. "iphone", "ipad", "tv")
    public let deviceSupport: [String]?

    /// Number of times this skin has been downloaded
    public let downloadCount: Int?

    /// Average user rating (0.0 - 5.0)
    public let rating: Double?

    /// When this particular skin was last updated
    public let lastUpdated: Date?

    /// Size of the downloadable file in bytes
    public let fileSize: Int?

    /// Source attribution or repository URL string
    public let source: String?

    public init(
        id: String,
        name: String,
        author: String,
        systems: [String],
        gameTypeIdentifier: String? = nil,
        version: String? = nil,
        downloadURL: URL,
        thumbnailURL: URL? = nil,
        screenshotURLs: [URL]? = nil,
        tags: [String]? = nil,
        deviceSupport: [String]? = nil,
        downloadCount: Int? = nil,
        rating: Double? = nil,
        lastUpdated: Date? = nil,
        fileSize: Int? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.systems = systems
        self.gameTypeIdentifier = gameTypeIdentifier
        self.version = version
        self.downloadURL = downloadURL
        self.thumbnailURL = thumbnailURL
        self.screenshotURLs = screenshotURLs
        self.tags = tags
        self.deviceSupport = deviceSupport
        self.downloadCount = downloadCount
        self.rating = rating
        self.lastUpdated = lastUpdated
        self.fileSize = fileSize
        self.source = source
    }
}

// MARK: - Sort Options

/// Sorting options for skin catalog queries.
public enum SkinSortOption: String, CaseIterable, Sendable {
    /// Sort by download count (descending)
    case popular
    /// Sort by last updated date (most recent first)
    case recent
    /// Sort alphabetically by name
    case alphabetical
    /// Sort by user rating (highest first)
    case rating
}
