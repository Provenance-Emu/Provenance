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
/// called from any thread.  `romsPathPrefix` / `savesPathPrefix` / `biosPathPrefix`
/// are snapshotted during `start()` to avoid iCloud-blocking calls on
/// notification-delivery threads.
public final class PVWebFileEventObserver: @unchecked Sendable {

    public static let shared = PVWebFileEventObserver()

    private let lock = NSLock()
    private var observations: [NSObjectProtocol] = []

    // Snapshotted at start() to avoid potentially iCloud-blocking path lookups
    // on arbitrary notification-delivery threads.
    private var romsPathPrefix: String = ""
    private var savesPathPrefix: String = ""
    private var biosPathPrefix: String  = ""

    private init() {}

    // MARK: Lifecycle

    /// Start listening.  Safe to call multiple times — subsequent calls are no-ops.
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard observations.isEmpty else { return }

        // Snapshot path prefixes once here (called from app launch on the main queue).
        let romsDir  = Paths.romsPath.path
        let savesDir = Paths.saveSavesPath.path
        let biosDir  = Paths.biosesPath.path
        romsPathPrefix  = romsDir.hasSuffix("/")  ? romsDir  : romsDir  + "/"
        savesPathPrefix = savesDir.hasSuffix("/") ? savesDir : savesDir + "/"
        biosPathPrefix  = biosDir.hasSuffix("/")  ? biosDir  : biosDir  + "/"

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
        let url = URL(fileURLWithPath: fullPath)
        let filename = url.lastPathComponent

        ILOG("PVWebFileEventObserver: file deleted — \(fullPath)")

        let romsPrefix  = romsPathPrefix
        let savesPrefix = savesPathPrefix
        let biosPrefix  = biosPathPrefix

        DispatchQueue.global(qos: .utility).async {
            do {
                let realm = try Realm()

                // ── ROM file ──────────────────────────────────────────────────────────
                if fullPath.hasPrefix(romsPrefix) {
                    let relative = String(fullPath.dropFirst(romsPrefix.count))

                    // Only query on the exact stored romPath — don't fall back to
                    // filename-only matching, which can collide across systems.
                    let game = realm.objects(PVGame.self)
                        .filter("romPath == %@", relative)
                        .first

                    if let game {
                        if game.cloudRecordID != nil {
                            // Soft offline: file deleted locally, CloudKit record survives.
                            try realm.write {
                                game.isDownloaded = false
                                game.requiresSync = true
                                game.lastCloudSyncDate = nil
                            }
                            ILOG("PVWebFileEventObserver: marked '\(game.title)' offline (CloudKit record retained)")
                        } else {
                            // No remote copy — delete related objects then the game.
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
        ILOG("PVWebFileEventObserver: file moved — \(fromPath) → \(toPath)")

        let prefix = romsPathPrefix

        guard fromPath.hasPrefix(prefix), toPath.hasPrefix(prefix) else {
            // Only ROM moves require a Realm path update; other file types don't
            // store absolute paths in the database.
            return
        }

        let oldRelative = String(fromPath.dropFirst(prefix.count))
        let newRelative = String(toPath.dropFirst(prefix.count))
        let newFilename = URL(fileURLWithPath: toPath).lastPathComponent

        DispatchQueue.global(qos: .utility).async {
            do {
                let realm = try Realm()
                guard let game = realm.objects(PVGame.self)
                    .filter("romPath == %@", oldRelative)
                    .first else {
                    WLOG("PVWebFileEventObserver: no game found for moved path '\(oldRelative)'")
                    return
                }

                try realm.write {
                    game.romPath = newRelative
                    // Keep game.file.partialPath in sync so path-resolution via
                    // PVFile.url returns the correct location.
                    if let pvFile = game.file {
                        pvFile.partialPath = newFilename
                    }
                }
                ILOG("PVWebFileEventObserver: updated romPath '\(oldRelative)' → '\(newRelative)' for '\(game.title)'")

            } catch {
                ELOG("PVWebFileEventObserver: Realm error on move — \(error.localizedDescription)")
            }
        }
    }
}
