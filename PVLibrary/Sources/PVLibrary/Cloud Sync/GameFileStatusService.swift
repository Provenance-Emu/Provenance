//
//  GameFileStatusService.swift
//  PVLibrary
//
//  Centralized owner of `isDownloaded` / `hasCloudAssets` state on PVGame.
//  All code that needs to change a game's download status should go through
//  this service instead of directly writing to the Realm property.
//
//  ## Why this exists
//
//  Before this service, 15+ code paths across CloudKitRomsSyncer,
//  CloudSyncManager, iCloudDriveRomsSyncer, PVWebFileEventObserver, and
//  UI actions could independently set `isDownloaded = false`.  Race
//  conditions and stale snapshots caused locally-imported games to
//  intermittently show a cloud badge.
//
//  The invariant enforced here:
//  **`isDownloaded` is NEVER set to `false` when the file exists on disk.**
//
//  ## Smart batch refresh
//
//  ``refreshAllStatuses()`` uses `FileLocationResolver.buildLocalFileIndex()`
//  to scan the filesystem once (a single directory enumeration) and then
//  checks each game's `partialPath` against the resulting `Set<String>`.
//  This is O(n) total instead of O(n) individual `stat()` calls.
//
//  Created by Joseph Mattiello on 4/16/26.
//

import Foundation
import PVFileSystem
import PVRealm
import PVLogging
import RealmSwift

// MARK: - GameFileStatusService

public final class GameFileStatusService: @unchecked Sendable {

    public static let shared = GameFileStatusService()

    private let resolver = FileLocationResolver.shared

    private init() {}

    // MARK: - Single-Game Status Updates

    /// Refresh `isDownloaded` for a single game by checking file existence.
    ///
    /// Call this from sync backends instead of directly writing
    /// `game.isDownloaded = false`.  The service will only downgrade
    /// `isDownloaded` if the file truly doesn't exist locally.
    ///
    /// - Parameters:
    ///   - md5: The game's MD5 (primary key, uppercased).
    ///   - hasCloudAssets: If non-nil, also updates `hasCloudAssets`.
    public func refreshStatus(forGameMD5 md5: String, hasCloudAssets: Bool? = nil) async {
        let upperMD5 = md5.uppercased()

        do {
            try await RealmContext.withBackgroundRealm { [resolver] realm in
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: upperMD5) else {
                    DLOG("GameFileStatusService: game \(upperMD5) not found")
                    return
                }

                let fileExistsLocally: Bool
                if let partialPath = game.file?.partialPath, !partialPath.isEmpty {
                    fileExistsLocally = resolver.resolve(partialPath) != .notFound
                } else {
                    fileExistsLocally = false
                }

                let newDownloaded = fileExistsLocally
                let cloudChanged = hasCloudAssets != nil && game.hasCloudAssets != hasCloudAssets

                // Skip no-op writes
                if game.isDownloaded == newDownloaded && !cloudChanged {
                    return
                }

                try realm.write {
                    game.isDownloaded = newDownloaded
                    if let cloud = hasCloudAssets {
                        game.hasCloudAssets = cloud
                    }
                }
                DLOG("GameFileStatusService: \(game.title) isDownloaded=\(newDownloaded)")
            }
        } catch {
            ELOG("GameFileStatusService.refreshStatus failed for \(upperMD5): \(error)")
        }
    }

    /// Mark a game as downloaded after a successful file write.
    ///
    /// Call this after importing, downloading, or copying a file into place.
    /// The service verifies the file actually exists before writing.
    ///
    /// - Parameters:
    ///   - md5: The game's MD5 (primary key).
    ///   - url: The URL where the file was written.
    public func markDownloaded(md5: String, at url: URL) async {
        let upperMD5 = md5.uppercased()

        // Verify the file actually exists before trusting the caller
        guard FileManager.default.fileExists(atPath: url.path) else {
            WLOG("GameFileStatusService.markDownloaded: file doesn't exist at \(url.path)")
            return
        }

        do {
            try await RealmContext.withBackgroundRealm { realm in
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: upperMD5) else {
                    return
                }
                guard !game.isDownloaded else { return } // already correct
                try realm.write {
                    game.isDownloaded = true
                }
                DLOG("GameFileStatusService: marked \(game.title) as downloaded")
            }
        } catch {
            ELOG("GameFileStatusService.markDownloaded failed for \(upperMD5): \(error)")
        }
    }

    /// Mark a game as not downloaded after a **confirmed** file deletion.
    ///
    /// Only call this when you've verified the file no longer exists.
    /// For speculative checks (background sync), use ``refreshStatus(forGameMD5:hasCloudAssets:)``
    /// instead — it will verify file existence before downgrading.
    ///
    /// - Parameters:
    ///   - md5: The game's MD5 (primary key).
    ///   - requiresSync: Whether to flag the game for re-download.
    public func markRemoved(md5: String, requiresSync: Bool = false) async {
        let upperMD5 = md5.uppercased()

        do {
            try await RealmContext.withBackgroundRealm { [resolver] realm in
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: upperMD5) else {
                    return
                }

                // Safety: double-check the file really is gone
                if let partialPath = game.file?.partialPath, !partialPath.isEmpty {
                    if resolver.resolve(partialPath) != .notFound {
                        WLOG("GameFileStatusService.markRemoved: refusing — file still exists for \(game.title)")
                        return
                    }
                }

                guard game.isDownloaded || game.requiresSync != requiresSync else { return }
                try realm.write {
                    game.isDownloaded = false
                    game.requiresSync = requiresSync
                    if requiresSync {
                        game.lastCloudSyncDate = nil
                    }
                }
                DLOG("GameFileStatusService: marked \(game.title) as removed (requiresSync=\(requiresSync))")
            }
        } catch {
            ELOG("GameFileStatusService.markRemoved failed for \(upperMD5): \(error)")
        }
    }

    // MARK: - Batch Refresh (Smart Directory Scan)

    /// Refresh `isDownloaded` for all games using a single directory scan.
    ///
    /// Instead of calling `FileManager.fileExists` for every game (N
    /// individual `stat()` syscalls), this method:
    ///
    /// 1. Enumerates the local directory tree once → `Set<String>` of
    ///    relative paths that exist on disk.
    /// 2. Queries all PVGame objects from Realm.
    /// 3. For each game, checks `partialPath` membership in the set.
    /// 4. Only writes to Realm when the status actually changed.
    ///
    /// This is O(n) for the scan + O(1) per game lookup = O(n) total,
    /// compared to O(n) individual filesystem calls.
    ///
    /// - Returns: A summary of how many games were updated.
    @discardableResult
    public func refreshAllStatuses() async -> RefreshResult {
        DLOG("GameFileStatusService: starting batch refresh")

        // Step 1: Build file index from a single directory enumeration
        let localIndex = resolver.buildLocalFileIndex()
        DLOG("GameFileStatusService: indexed \(localIndex.count) local files")

        var result = RefreshResult()

        do {
            try await RealmContext.withBackgroundRealm { realm in
                let allGames = realm.objects(PVGame.self)
                result.totalGames = allGames.count

                // Collect changes before writing (minimize write transaction duration)
                var upgrades: [String] = []  // MD5s to set isDownloaded = true
                var downgrades: [String] = [] // MD5s to set isDownloaded = false

                for game in allGames {
                    guard let partialPath = game.file?.partialPath, !partialPath.isEmpty else {
                        // No file record — can't be "downloaded"
                        if game.isDownloaded {
                            downgrades.append(game.md5Hash)
                        }
                        continue
                    }

                    // Normalize path for index lookup
                    var normalized = partialPath
                    if normalized.hasPrefix("/") {
                        normalized = String(normalized.dropFirst())
                    }
                    normalized = normalized.replacingOccurrences(of: "//", with: "/")

                    let existsLocally = localIndex.contains(normalized)

                    if existsLocally && !game.isDownloaded {
                        upgrades.append(game.md5Hash)
                    } else if !existsLocally && game.isDownloaded {
                        downgrades.append(game.md5Hash)
                    }
                }

                // Step 2: Apply changes in a single write transaction
                if !upgrades.isEmpty || !downgrades.isEmpty {
                    try realm.write {
                        for md5 in upgrades {
                            if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
                                game.isDownloaded = true
                            }
                        }
                        for md5 in downgrades {
                            if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
                                game.isDownloaded = false
                            }
                        }
                    }
                }

                result.upgraded = upgrades.count
                result.downgraded = downgrades.count
            }
        } catch {
            ELOG("GameFileStatusService.refreshAllStatuses failed: \(error)")
        }

        DLOG("GameFileStatusService: batch refresh complete — \(result.upgraded) upgraded, \(result.downgraded) downgraded out of \(result.totalGames)")
        return result
    }

    /// Summary of a batch refresh operation.
    public struct RefreshResult: Sendable {
        /// Total games checked.
        public var totalGames: Int = 0
        /// Games that were marked isDownloaded = true (file found on disk).
        public var upgraded: Int = 0
        /// Games that were marked isDownloaded = false (file not found).
        public var downgraded: Int = 0
    }
}
