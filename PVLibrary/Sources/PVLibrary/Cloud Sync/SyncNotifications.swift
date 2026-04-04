//
//  SyncNotifications.swift
//  PVLibrary
//
//  Well-known notification names for cloud sync events.
//

import Foundation

public extension Notification.Name {
    /// Posted when artwork is cached during sync backfill or artwork search.
    /// `userInfo` contains `[SyncNotification.gameIDsKey: Set<String>]`.
    static let artworkDidCache = Notification.Name("PVLibraryArtworkDidCache")
}

/// Keys for sync notification `userInfo` dictionaries.
public enum SyncNotification {
    /// Key for `Set<String>` of game IDs (md5) whose artwork was just cached.
    public static let gameIDsKey = "gameIds"
}
