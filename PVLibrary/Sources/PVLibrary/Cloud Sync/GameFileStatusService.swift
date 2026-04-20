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

    /// In-flight batch refresh, used to coalesce concurrent callers so we
    /// don't run a dozen full directory scans in parallel.
    private actor RefreshGate {
        var inflight: Task<RefreshResult, Never>?
        func current() -> Task<RefreshResult, Never>? { inflight }
        func set(_ task: Task<RefreshResult, Never>?) { inflight = task }
    }
    private let refreshGate = RefreshGate()

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

                // Resolve file existence. If partialPath doesn't resolve, fall
                // back to filename matching within the system directory — the
                // importer may have written the file under a different partial
                // path than CloudKit expected, and we still want to recognize
                // it as locally available.
                let resolution = Self.locate(game: game, resolver: resolver)
                let fileExistsLocally = resolution.url != nil

                let newDownloaded = fileExistsLocally
                let cloudChanged = hasCloudAssets != nil && game.hasCloudAssets != hasCloudAssets

                // If we found the file via filename fallback, repair the
                // stored partialPath so the fast path works next time.
                let partialPathFix: String?
                if let foundURL = resolution.url,
                   let recovered = resolver.relativePath(for: foundURL),
                   game.file?.partialPath != recovered {
                    partialPathFix = recovered
                } else {
                    partialPathFix = nil
                }

                // Skip no-op writes
                if game.isDownloaded == newDownloaded && !cloudChanged && partialPathFix == nil {
                    return
                }

                try realm.write {
                    game.isDownloaded = newDownloaded
                    if let cloud = hasCloudAssets {
                        game.hasCloudAssets = cloud
                    }
                    if let fix = partialPathFix {
                        game.file?.partialPath = fix
                    }
                }
                let repairNote = partialPathFix != nil ? " (partialPath repaired)" : ""
                DLOG("GameFileStatusService: \(game.title) isDownloaded=\(newDownloaded)\(repairNote)")
            }
        } catch {
            ELOG("GameFileStatusService.refreshStatus failed for \(upperMD5): \(error)")
        }
    }

    // MARK: - File Location Helpers

    /// Resolve a game's local file, trying partialPath first and falling
    /// back to filename-under-system-dir matching.
    private static func locate(game: PVGame, resolver: FileLocationResolver) -> FileResolution {
        resolver.resolve(partialPath: game.file?.partialPath,
                         systemIdentifier: game.systemIdentifier,
                         candidateFilenames: candidateFilenames(for: game))
    }

    /// Filenames to try when a game's stored `partialPath` doesn't resolve.
    static func candidateFilenames(for game: PVGame) -> [String] {
        [
            game.file?.fileName,
            game.romPath.isEmpty ? nil : (game.romPath as NSString).lastPathComponent
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
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
        if let inflight = await refreshGate.current() {
            return await inflight.value
        }
        let task = Task<RefreshResult, Never> { [weak self] in
            guard let self else { return RefreshResult() }
            let result = await self.runRefreshAllStatuses()
            await self.refreshGate.set(nil)
            return result
        }
        await refreshGate.set(task)
        return await task.value
    }

    private func runRefreshAllStatuses() async -> RefreshResult {
        let basePath = resolver.localBaseURL.path
        let cloudPath = resolver.iCloudBaseURL?.path ?? "<none>"
        ILOG("GameFileStatusService: starting batch refresh — local=\(basePath) cloud=\(cloudPath) iCloudDrive=\(resolver.isICloudDriveMode)")

        // Step 1: Build file index from a single directory enumeration. In
        // iCloud Drive mode, this also includes the ubiquity container's
        // Documents folder so cloud-resident files count as "downloaded".
        let localIndex = resolver.buildAvailabilityIndex()
        ILOG("GameFileStatusService: indexed \(localIndex.count) reachable files")
        // Sample the first few entries so we can see the relative-path shape
        // (e.g. "ROMs/com.provenance.jaguar/Game.j64" vs other layouts).
        let sample = Array(localIndex.prefix(8)).joined(separator: " | ")
        ILOG("GameFileStatusService: index sample → \(sample)")

        // Step 2: Derive a filename → [relativePaths] multimap from the same
        // scan so we can recover games whose stored partialPath no longer
        // matches on disk (e.g. imported under a different relative path
        // than CloudKit expected). No extra filesystem calls.
        let filenameMultimap = Self.buildFilenameMultimap(from: localIndex)

        var result = RefreshResult()

        do {
            try await RealmContext.withBackgroundRealm { realm in
                let allGames = realm.objects(PVGame.self)
                result.totalGames = allGames.count

                // SAFETY: if the index is impossibly small relative to game
                // count, the directory scan failed (wrong base URL, sandbox
                // weirdness, App Group mismatch, …). Bail before we shred
                // every game's isDownloaded flag.
                let suspiciouslyEmpty = localIndex.count < max(10, allGames.count / 100)
                if allGames.count > 50 && suspiciouslyEmpty {
                    ELOG("GameFileStatusService: ABORT — index has \(localIndex.count) files vs \(allGames.count) games. Refusing to downgrade. Bad localBase=\(basePath)")
                    return
                }

                var plan = ReconciliationPlan()
                for game in allGames {
                    Self.reconcile(game: game,
                                   localIndex: localIndex,
                                   filenameMultimap: filenameMultimap,
                                   into: &plan)
                }

                try Self.apply(plan: plan, in: realm)

                result.upgraded = plan.upgrades.count
                result.downgraded = plan.downgrades.count
                result.partialPathRepaired = plan.partialPathFixes.count
            }
        } catch {
            ELOG("GameFileStatusService.refreshAllStatuses failed: \(error)")
        }

        let summary = "\(result.upgraded) upgraded, \(result.downgraded) downgraded, "
            + "\(result.partialPathRepaired) path-repaired out of \(result.totalGames)"
        DLOG("GameFileStatusService: batch refresh complete — \(summary)")
        return result
    }

    // MARK: - Batch Refresh Helpers

    /// Aggregated mutations produced by scanning all games. Applied in one
    /// Realm write transaction.
    private struct ReconciliationPlan {
        var upgrades: [String] = []          // MD5s to set isDownloaded = true
        var downgrades: [String] = []        // MD5s to set isDownloaded = false
        var partialPathFixes: [String: String] = [:] // md5 -> corrected relative path
        var hasChanges: Bool {
            !upgrades.isEmpty || !downgrades.isEmpty || !partialPathFixes.isEmpty
        }
    }

    /// Build `lowercased filename → [relativePaths]` from a pre-scanned index.
    private static func buildFilenameMultimap(from index: Set<String>) -> [String: [String]] {
        var multimap: [String: [String]] = [:]
        for path in index {
            let filename = (path as NSString).lastPathComponent.lowercased()
            multimap[filename, default: []].append(path)
        }
        return multimap
    }

    /// Normalize a stored partialPath for membership lookup in a local index.
    private static func normalized(partialPath: String?) -> String? {
        guard let stored = partialPath, !stored.isEmpty else { return nil }
        var normalized = stored
        if normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }
        return normalized.replacingOccurrences(of: "//", with: "/")
    }

    /// Filename-scoped fallback: look up the game's filename(s) in the
    /// multimap and return the first match under the game's system prefix.
    private static func findByFilenameFallback(game: PVGame,
                                               filenameMultimap: [String: [String]]) -> String? {
        let systemID = game.systemIdentifier
        guard !systemID.isEmpty else {
            return nil
        }

        let candidateNames: [String] = [
            game.file?.fileName,
            game.romPath.isEmpty ? nil : (game.romPath as NSString).lastPathComponent
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .map { $0.lowercased() }

        // ROM files live under "ROMs/<systemID>/" relative to Documents, but
        // some legacy partialPaths omit the "ROMs/" prefix. Accept either
        // layout (and the very rare case where a file genuinely sits at
        // "<systemID>/...") so the reconcile catches them all.
        let acceptedPrefixes = [
            "ROMs/" + systemID + "/",
            systemID + "/"
        ]
        for name in candidateNames {
            guard let paths = filenameMultimap[name] else { continue }
            for prefix in acceptedPrefixes {
                if let scoped = paths.first(where: { $0.hasPrefix(prefix) }) {
                    return scoped
                }
            }
        }
        return nil
    }

    /// Reconcile a single game against the pre-built indexes, appending any
    /// required mutations to `plan`.
    private static func reconcile(game: PVGame,
                                  localIndex: Set<String>,
                                  filenameMultimap: [String: [String]],
                                  into plan: inout ReconciliationPlan) {
        let md5 = game.md5Hash
        let normalizedStored = normalized(partialPath: game.file?.partialPath)
        let existsAtStored = normalizedStored.map { localIndex.contains($0) } ?? false

        if existsAtStored {
            if !game.isDownloaded {
                plan.upgrades.append(md5)
            }
            return
        }

        if let fixed = findByFilenameFallback(game: game, filenameMultimap: filenameMultimap) {
            if !game.isDownloaded {
                plan.upgrades.append(md5)
            }
            if normalizedStored != fixed {
                plan.partialPathFixes[md5] = fixed
            }
        } else if game.isDownloaded {
            plan.downgrades.append(md5)
        } else {
            // Game has cloud icon (isDownloaded=false) and we couldn't find it
            // anywhere — log so we can diagnose why the reconcile missed.
            let stored = game.file?.partialPath ?? "<nil>"
            let candidates = candidateFilenames(for: game).joined(separator: ",")
            DLOG("GameFileStatusService: NO MATCH for \(game.title) sysID=\(game.systemIdentifier) stored=\(stored) candidates=[\(candidates)]")
        }
    }

    /// Apply a reconciliation plan in a single Realm write transaction.
    private static func apply(plan: ReconciliationPlan, in realm: Realm) throws {
        guard plan.hasChanges else { return }
        try realm.write {
            for md5 in plan.upgrades {
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
                    game.isDownloaded = true
                    ILOG("GameFileStatusService: upgraded \(game.title) → isDownloaded=true")
                }
            }
            for md5 in plan.downgrades {
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
                    game.isDownloaded = false
                    WLOG("GameFileStatusService: downgraded \(game.title) → isDownloaded=false (no local file)")
                }
            }
            for (md5, fix) in plan.partialPathFixes {
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
                    let old = game.file?.partialPath ?? "nil"
                    game.file?.partialPath = fix
                    ILOG("GameFileStatusService: repaired \(game.title) partialPath '\(old)' → '\(fix)'")
                }
            }
        }
    }

    /// Summary of a batch refresh operation.
    public struct RefreshResult: Sendable {
        /// Total games checked.
        public var totalGames: Int = 0
        /// Games that were marked isDownloaded = true (file found on disk).
        public var upgraded: Int = 0
        /// Games that were marked isDownloaded = false (file not found).
        public var downgraded: Int = 0
        /// Games whose stored `partialPath` was corrected via filename fallback.
        public var partialPathRepaired: Int = 0
    }
}
