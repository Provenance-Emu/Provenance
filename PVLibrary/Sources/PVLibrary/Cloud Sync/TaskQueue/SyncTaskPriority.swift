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

    /// Whether this priority includes the on-demand boost. Stored rather than
    /// inferred from `rawValue`: a boosted low tier (ROM download, 200 + 500)
    /// stays below the top standard tier, and a boosted DB artwork lookup
    /// (100 + 500) equals the save-state screenshot tier, so no threshold can
    /// tell them apart.
    public let isBoosted: Bool

    public init(_ rawValue: Int) {
        self.init(rawValue, isBoosted: false)
    }

    private init(_ rawValue: Int, isBoosted: Bool) {
        self.rawValue = rawValue
        self.isBoosted = isBoosted
    }

    public static func < (lhs: SyncTaskPriority, rhs: SyncTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Equality and hashing follow the ordering: two priorities with the same
    // value are equal whether or not one of them got there by boosting.
    public static func == (lhs: SyncTaskPriority, rhs: SyncTaskPriority) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
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

    /// Return a new priority boosted by the on-demand offset. Boosting an
    /// already boosted priority returns it unchanged.
    public func boosted() -> SyncTaskPriority {
        guard !isBoosted else { return self }
        return SyncTaskPriority(rawValue + Self.onDemandBoost, isBoosted: true)
    }

    /// Return the priority with the boost removed. An unboosted priority is
    /// returned unchanged.
    public func unboosted() -> SyncTaskPriority {
        guard isBoosted else { return self }
        return SyncTaskPriority(max(rawValue - Self.onDemandBoost, 0), isBoosted: false)
    }
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
