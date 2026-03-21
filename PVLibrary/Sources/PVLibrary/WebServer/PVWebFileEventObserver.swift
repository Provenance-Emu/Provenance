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
public final class PVWebFileEventObserver: @unchecked Sendable {

    public static let shared = PVWebFileEventObserver()

    private var observations: [NSObjectProtocol] = []

    private init() {}

    // MARK: Lifecycle

    /// Start listening.  Safe to call multiple times — subsequent calls are no-ops.
    public func start() {
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
        observations.forEach { NotificationCenter.default.removeObserver($0) }
        observations.removeAll()
        ILOG("PVWebFileEventObserver: stopped")
    }

    // MARK: - Delete handler

    private func handleFileDeleted(at fullPath: String) {
        let url = URL(fileURLWithPath: fullPath)
        let filename = url.lastPathComponent

        ILOG("PVWebFileEventObserver: file deleted — \(fullPath)")

        DispatchQueue.global(qos: .utility).async {
            do {
                let realm = try Realm()

                // ── ROM file ──────────────────────────────────────────────────────────
                let romsDir = Paths.romsPath.path
                if fullPath.hasPrefix(romsDir) {
                    // romPath stored as "com.provenance.snes/Mario.sfc" (no leading slash).
                    let prefix = romsDir.hasSuffix("/") ? romsDir : romsDir + "/"
                    let relative = fullPath.hasPrefix(prefix)
                        ? String(fullPath.dropFirst(prefix.count))
                        : filename  // fallback to filename-only if path structure differs

                    let game = realm.objects(PVGame.self)
                        .filter("romPath == %@", relative)
                        .first
                        ?? realm.objects(PVGame.self)
                        .filter("romPath ENDSWITH %@", "/\(filename)")
                        .first
                        ?? realm.objects(PVGame.self)
                        .filter("romPath == %@", filename)
                        .first

                    if let game {
                        try realm.write {
                            if game.cloudRecordID != nil {
                                // Soft offline: file deleted locally, CloudKit record survives.
                                game.isDownloaded = false
                                ILOG("PVWebFileEventObserver: marked '\(game.title)' offline (CloudKit record retained)")
                            } else {
                                // No remote copy — mark linked save states unavailable then remove.
                                ILOG("PVWebFileEventObserver: hard-deleting '\(game.title)' (no CloudKit record)")
                                for saveState in game.saveStates {
                                    saveState.isDownloaded = false
                                }
                                realm.delete(game)
                            }
                        }
                        return
                    }
                }

                // ── Save state file ───────────────────────────────────────────────────
                let savesDir = Paths.saveSavesPath.path
                if fullPath.hasPrefix(savesDir) {
                    let allStates = Array(realm.objects(PVSaveState.self))
                    let matched = allStates.filter { $0.file?.url?.path == fullPath }
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
                let biosDir = Paths.biosesPath.path
                if fullPath.hasPrefix(biosDir) {
                    if let bios = realm.objects(PVBIOS.self)
                        .filter("expectedFilename == %@", filename)
                        .first {
                        try realm.write {
                            bios.isDownloaded = false
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

        let romsDir = Paths.romsPath.path
        let prefix = romsDir.hasSuffix("/") ? romsDir : romsDir + "/"

        guard fromPath.hasPrefix(prefix), toPath.hasPrefix(prefix) else {
            // Only ROM moves require a Realm path update; other file types don't
            // store absolute paths in the database.
            return
        }

        let oldRelative = String(fromPath.dropFirst(prefix.count))
        let newRelative = String(toPath.dropFirst(prefix.count))

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
                }
                ILOG("PVWebFileEventObserver: updated romPath '\(oldRelative)' → '\(newRelative)' for '\(game.title)'")

            } catch {
                ELOG("PVWebFileEventObserver: Realm error on move — \(error.localizedDescription)")
            }
        }
    }
}
