//
//  PVWebFileEventObserver.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Observes PVWebServer file-lifecycle notifications (delete/move) and
//  updates Realm accordingly.  This decouples PVWebServer from PVLibrary
//  while keeping both database integrity and CloudKit-awareness intact.
//
//  Integration:
//    Call `PVWebFileEventObserver.shared.start()` during app launch
//    (after Realm is configured) to begin listening.
//

import Foundation
import RealmSwift
import PVLogging
import PVRealm
import PVFileSystem

// MARK: - Notification name mirrors
// These raw values mirror Notification.Name constants defined in
// PVWebServerProtocol.swift (PVWebServer module).  Duplicated here so
// PVLibrary does not need to import PVWebServer (avoiding a cross-tier dependency).
private extension Notification.Name {
    static let webFileDeleted = Notification.Name("PVWebServerFileDeletedNotification")
    static let webFileMoved   = Notification.Name("PVWebServerFileMovedNotification")
}

// MARK: - PVWebFileEventObserver

/// Singleton that bridges web-server file events to Realm library state.
///
/// Handles three file categories:
/// - **ROM files** — soft-offline when a CloudKit record exists; hard-delete otherwise.
/// - **Save states** — marked `isDownloaded = false` when the backing file disappears.
/// - **BIOS files** — `isDownloaded` toggled on delete/restore events.
///
/// Thread safety: `observations` is guarded by `lock`; `start()`/`stop()` may be
/// called from any thread.  Path lookups (potentially iCloud-blocking) are deferred
/// to the utility background queue used by each event handler.
///
/// `@unchecked Sendable` justification:
/// `[NSObjectProtocol]` is not `Sendable`, forcing the annotation.  The class is
/// safe because all mutable state follows a strict write-before-start discipline:
/// - `observations` — guarded by `lock`; written only inside `start()`/`stop()`.
/// - `realmConfiguration`, `_testOn*` closures, `_test*PathPrefix` strings — all
///   set once (by tests) before `start()` is called and never written afterward,
///   so concurrent event handlers observe a stable, read-only snapshot.
public final class PVWebFileEventObserver: @unchecked Sendable {

    public static let shared = PVWebFileEventObserver()

    private let lock = NSLock()
    private var observations: [NSObjectProtocol] = []

    /// Realm configuration used when opening a Realm in event handlers.
    /// Defaults to the process-default configuration; override in tests
    /// to supply an in-memory configuration.
    internal var realmConfiguration: Realm.Configuration = .defaultConfiguration

    // MARK: Test instrumentation
    // These properties are always `nil` in production. Tests set them before `start()`
    // to override path prefixes or observe handler delivery.
    // Because they are set before `start()` is called, no additional locking is
    // needed — they are read-only from the perspective of concurrent event handlers.

    /// Called at the start of `handleFileDeleted` with the full path of the deleted file.
    internal var _testOnDeleteHandlerInvoked: ((String) -> Void)?
    /// Called at the start of `handleFileMoved` with (fromPath, toPath).
    internal var _testOnMoveHandlerInvoked: ((String, String) -> Void)?

    /// Override the ROMs directory prefix used during delete/move classification.
    /// Nil in production — set in tests so handlers can classify paths against a
    /// temp directory rather than `Paths.romsPath` (which is iCloud-blocking).
    internal var _testRomsPathPrefix: String?
    /// Override the save-states directory prefix for delete classification.
    internal var _testSavesPathPrefix: String?
    /// Override the BIOS directory prefix for delete classification.
    internal var _testBiosPathPrefix: String?

    internal init() {}

    // MARK: Lifecycle

    /// Start listening.  Safe to call multiple times — subsequent calls are no-ops.
    /// May be called from any thread; no iCloud-blocking work is performed here.
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard observations.isEmpty else { return }

        let center = NotificationCenter.default

        observations.append(
            center.addObserver(forName: .webFileDeleted, object: nil, queue: nil) { [weak self] note in
                guard let filePath = note.userInfo?["filePath"] as? String else { return }
                self?.handleFileDeleted(at: filePath)
            }
        )

        observations.append(
            center.addObserver(forName: .webFileMoved, object: nil, queue: nil) { [weak self] note in
                guard
                    let fromPath = note.userInfo?["fromPath"] as? String,
                    let toPath   = note.userInfo?["toPath"]   as? String
                else { return }
                self?.handleFileMoved(from: fromPath, to: toPath)
            }
        )

        ILOG("PVWebFileEventObserver: started")
    }

    /// Stop listening and release observers.
    public func stop() {
        lock.lock()
        let toRemove = observations
        observations.removeAll()
        lock.unlock()

        toRemove.forEach { NotificationCenter.default.removeObserver($0) }
        ILOG("PVWebFileEventObserver: stopped")
    }

    // MARK: - Delete handler

    private func handleFileDeleted(at fullPath: String) {
        _testOnDeleteHandlerInvoked?(fullPath)
        let url = URL(fileURLWithPath: fullPath)
        let filename = url.lastPathComponent

        ILOG("PVWebFileEventObserver: file deleted — \(fullPath)")

        let config = realmConfiguration
        // Snapshot test overrides before entering the background queue so the
        // closure captures value-type Strings (no actor-isolation concerns).
        let testRoms  = _testRomsPathPrefix
        let testSaves = _testSavesPathPrefix
        let testBios  = _testBiosPathPrefix
        DispatchQueue.global(qos: .utility).async {
            // Helper: ensure a directory path ends with "/" for prefix matching.
            func ensureSlash(_ path: String) -> String { path.hasSuffix("/") ? path : path + "/" }
            // Compute potentially iCloud-blocking paths here on the background thread,
            // falling back to test overrides when provided (avoids iCloud I/O in tests).
            // ensureSlash applied to both branches so caller doesn't need to add "/".
            let romsPrefix  = ensureSlash(testRoms  ?? Paths.romsPath.path)
            let savesPrefix = ensureSlash(testSaves ?? Paths.saveSavesPath.path)
            let biosPrefix  = ensureSlash(testBios  ?? Paths.biosesPath.path)

            do {
                let realm = try Realm(configuration: config)

                // ── ROM file ──────────────────────────────────────────────────────────
                if fullPath.hasPrefix(romsPrefix) {
                    let relative = String(fullPath.dropFirst(romsPrefix.count))

                    // Only query on the exact stored romPath — don't fall back to
                    // filename-only matching, which can collide across systems.
                    let game = realm.objects(PVGame.self)
                        .filter("romPath == %@", relative)
                        .first

                    if let game {
                        let hasCloudRecord = !(game.cloudRecordID?.isEmpty ?? true)
                        if hasCloudRecord {
                            // Soft offline: file deleted locally, CloudKit record survives.
                            try realm.write {
                                game.isDownloaded = false
                                game.requiresSync = true
                                game.lastCloudSyncDate = nil
                            }
                            ILOG("PVWebFileEventObserver: marked '\(game.title)' offline (CloudKit record retained)")
                        } else {
                            // No remote copy — delete related Realm objects then the game.
                            // NOTE: We do NOT call RomDatabase.delete(game:) here because
                            // that method also tries to remove the physical ROM file from disk.
                            // The file is already gone (we're reacting to its deletion), so
                            // calling it would log a spurious ELOG and attempt unneeded FS work.
                            // We replicate the Realm-side cleanup manually instead.
                            ILOG("PVWebFileEventObserver: hard-deleting '\(game.title)' (no CloudKit record)")
                            let saveStatesToDelete = Array(game.saveStates)
                            let cheatsToDelete = Array(game.cheats)
                            let recentPlaysToDelete = Array(game.recentPlays)
                            let screenShotsToDelete = Array(game.screenShots)
                            try realm.write {
                                realm.delete(saveStatesToDelete)
                                realm.delete(cheatsToDelete)
                                realm.delete(recentPlaysToDelete)
                                realm.delete(screenShotsToDelete)
                                realm.delete(game)
                            }
                            // Remove from Spotlight so the game no longer appears in system search.
#if canImport(CoreSpotlight) && !os(tvOS)
                            RomDatabase.sharedInstance.deleteFromSpotlight(game: game)
#endif
                            // Invalidate the in-memory games cache so stale entries
                            // (e.g. gamesCache[romPath]) don't survive the hard-delete.
                            RomDatabase.reloadGamesCache()
                        }
                        return
                    } else {
                        WLOG("PVWebFileEventObserver: no game matched romPath '\(relative)' — skipping delete")
                    }
                }

                // ── Save state file ───────────────────────────────────────────────────
                if fullPath.hasPrefix(savesPrefix) {
                    // Filter by filename suffix first to reduce the candidate set,
                    // then confirm the full URL matches in memory.
                    let candidates = realm.objects(PVSaveState.self)
                        .filter("file.partialPath ENDSWITH %@", filename)
                    let matched = candidates.filter { $0.file?.url?.path == fullPath }
                    if !matched.isEmpty {
                        try realm.write {
                            for state in matched {
                                state.isDownloaded = false
                            }
                        }
                        ILOG("PVWebFileEventObserver: marked \(matched.count) save state(s) unavailable")
                        return
                    }
                }

                // ── BIOS file ─────────────────────────────────────────────────────────
                if fullPath.hasPrefix(biosPrefix) {
                    if let bios = realm.objects(PVBIOS.self)
                        .filter("expectedFilename == %@", filename)
                        .first {
                        try realm.write {
                            bios.isDownloaded = false
                            bios.file = nil
                        }
                        ILOG("PVWebFileEventObserver: marked BIOS '\(filename)' unavailable")
                    }
                }

            } catch {
                ELOG("PVWebFileEventObserver: Realm error on delete — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Move handler

    private func handleFileMoved(from fromPath: String, to toPath: String) {
        _testOnMoveHandlerInvoked?(fromPath, toPath)
        ILOG("PVWebFileEventObserver: file moved — \(fromPath) → \(toPath)")

        let config = realmConfiguration
        let testRoms = _testRomsPathPrefix
        DispatchQueue.global(qos: .utility).async {
            func ensureSlash(_ path: String) -> String { path.hasSuffix("/") ? path : path + "/" }
            // Compute potentially iCloud-blocking path here on the background thread,
            // falling back to test override when provided.
            let prefix = ensureSlash(testRoms ?? Paths.romsPath.path)

            guard fromPath.hasPrefix(prefix), toPath.hasPrefix(prefix) else {
                // Only ROM moves require a Realm path update; other file types don't
                // store absolute paths in the database.
                return
            }

            let oldRelative = String(fromPath.dropFirst(prefix.count))
            let newRelative = String(toPath.dropFirst(prefix.count))

            do {
                let realm = try Realm(configuration: config)
                guard let game = realm.objects(PVGame.self)
                    .filter("romPath == %@", oldRelative)
                    .first else {
                    WLOG("PVWebFileEventObserver: no game found for moved path '\(oldRelative)'")
                    return
                }

                try realm.write {
                    game.romPath = newRelative
                    // Keep game.file.partialPath in sync so path-resolution via
                    // PVFile.url returns the correct location.  partialPath is a
                    // relative path (including any system subdirectory), not just
                    // the bare filename, so use the full relative path here.
                    if let pvFile = game.file {
                        pvFile.partialPath = newRelative
                    }
                }
                ILOG("PVWebFileEventObserver: updated romPath '\(oldRelative)' → '\(newRelative)' for '\(game.title)'")

            } catch {
                ELOG("PVWebFileEventObserver: Realm error on move — \(error.localizedDescription)")
            }
        }
    }
}
