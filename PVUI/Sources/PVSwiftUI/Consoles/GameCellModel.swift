//
//  GameCellModel.swift
//  PVUI
//
//  Created by GPT-5.2 on 1/9/26.
//

import Foundation
import PVRealm
import PVSystems
import PVUIBase

/// Immutable snapshot of the subset of `PVGame` properties rendered by game cells.
/// Used to drive SwiftUI lists/grids without relying on Realm object identity.
public struct GameCellModel: Identifiable, Hashable {
    public let id: String
    public let md5: String

    // Display fields
    public let title: String
    public let publishDate: String?
    public let rating: Int
    public let lastPlayed: Date?
    public let playCount: Int
    public let systemShortName: String?

    // Artwork
    public let trueArtworkURL: String
    public let boxartAspectRatio: PVGameBoxArtAspectRatio

    // Cloud/library state
    public let isFavorite: Bool
    public let hasCloudAssets: Bool
    public let isDownloaded: Bool

    // Multi-disc indicator
    public let discCount: Int

    public init(
        id: String,
        md5: String,
        title: String,
        publishDate: String?,
        rating: Int,
        lastPlayed: Date?,
        playCount: Int,
        systemShortName: String?,
        trueArtworkURL: String,
        boxartAspectRatio: PVGameBoxArtAspectRatio,
        isFavorite: Bool,
        hasCloudAssets: Bool,
        isDownloaded: Bool,
        discCount: Int
    ) {
        self.id = id
        self.md5 = md5
        self.title = title
        self.publishDate = publishDate
        self.rating = rating
        self.lastPlayed = lastPlayed
        self.playCount = playCount
        self.systemShortName = systemShortName
        self.trueArtworkURL = trueArtworkURL
        self.boxartAspectRatio = boxartAspectRatio
        self.isFavorite = isFavorite
        self.hasCloudAssets = hasCloudAssets
        self.isDownloaded = isDownloaded
        self.discCount = discCount
    }

    public init(game: PVGame) {
        // Build from a frozen snapshot to avoid threading issues when mapped off-main.
        let g = game.isFrozen ? game : game.freeze()

        self.id = g.id
        /// Keep stored casing so contentless core identifiers resolve correctly
        self.md5 = g.md5Hash
        self.title = g.title
        self.publishDate = g.publishDate
        self.rating = g.rating
        self.lastPlayed = g.lastPlayed
        self.playCount = g.playCount
        self.systemShortName = g.systemShortName ?? g.system?.shortName

        self.trueArtworkURL = g.trueArtworkURL
        self.boxartAspectRatio = g.boxartAspectRatio

        self.isFavorite = g.isFavorite
        self.hasCloudAssets = g.hasCloudAssets
        self.isDownloaded = g.isDownloaded

        // Precompute disc count from related files.
        let paths = g.relatedFiles.toArray().compactMap { $0.url?.path }
        self.discCount = Set(paths).count
    }

    /// Key paths used by Realm notifications to rebuild models only when relevant fields change.
    public static let observedKeyPaths: [String] = [
        "id",
        "md5Hash",
        "title",
        "publishDate",
        "rating",
        "lastPlayed",
        "playCount",
        "system",
        "systemShortName",
        "systemIdentifier",
        "regionName",
        "customArtworkURL",
        "originalArtworkURL",
        "isFavorite",
        "hasCloudAssets",
        "isDownloaded",
        "relatedFiles"
    ]
}

extension GameCellModel: GameItemPresentable {
    public var isInvalidated: Bool { false }
}
