//
//  SyncTaskPriority.swift
//  PVLibrary
//
//  Unified priority type for all sync operations.
//

import Foundation

/// Priority value for sync tasks. Higher numeric value = higher priority.
/// Supports arithmetic for on-demand boosting.
public struct SyncTaskPriority: Comparable, Sendable, Codable, Hashable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func < (lhs: SyncTaskPriority, rhs: SyncTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Predefined tiers

    /// ROM metadata sync — fast, must complete first so Realm has game records
    public static let metadataSync = SyncTaskPriority(1000)

    /// Artwork HTTP re-downloads — small images with known URLs
    public static let artworkRedownload = SyncTaskPriority(800)

    /// Save state screenshot sync
    public static let saveStateScreenshot = SyncTaskPriority(600)

    /// BIOS file sync
    public static let biosSync = SyncTaskPriority(400)

    /// ROM file downloads — large files, can wait
    public static let romDownload = SyncTaskPriority(200)

    /// Database artwork lookups — expensive SQLite queries, lowest priority
    public static let dbArtworkLookup = SyncTaskPriority(100)

    // MARK: - Boosting

    /// Offset added when a game is visible in the UI and needs immediate attention
    public static let onDemandBoost = 500

    /// Return a new priority boosted by the on-demand offset
    public func boosted() -> SyncTaskPriority {
        SyncTaskPriority(rawValue + Self.onDemandBoost)
    }

    /// Return the priority with the boost removed (floor at original tier)
    public func unboosted() -> SyncTaskPriority {
        SyncTaskPriority(max(rawValue - Self.onDemandBoost, 0))
    }

    /// Whether this priority includes the on-demand boost.
    /// True when the raw value exceeds the highest standard tier.
    public var isBoosted: Bool {
        rawValue > Self.highestStandardTier
    }

    /// The highest raw value among predefined (non-boosted) priority tiers.
    private static let highestStandardTier = metadataSync.rawValue
}

extension SyncTaskPriority: CustomStringConvertible {
    public var description: String {
        switch rawValue {
        case 1000: return "metadataSync"
        case 800: return "artworkRedownload"
        case 600: return "saveStateScreenshot"
        case 400: return "biosSync"
        case 200: return "romDownload"
        case 100: return "dbArtworkLookup"
        default: return "custom(\(rawValue))"
        }
    }
}
