//
//  RetroArchBatterySaveMigration.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provenance 3.3.x ran libretro cores inside the full RetroArch runtime, which wrote
//  battery saves (SAVE_RAM) to its own save directory: `<docs>/RetroArch/saves/<rom>.srm`,
//  where <docs> is the app container's Documents on iOS and Caches on tvOS
//  (3.3.1 retroarch.cfg `savefile_directory = "~/Documents/RetroArch/saves"`, sorting off;
//  platform_darwin.m DEFAULT_DIR_SRAM = <docs>/RetroArch/saves). `save_file_compression`
//  was "false", so the files are raw SAVE_RAM.
//
//  The thin wrapper reads `Battery States/<rom>/<rom>.srm` instead (PVThinLibretroFrontend
//  `loadBatterySaveData`: `batterySavesPath` = `Paths.batterySavesPath(forROM: game.url)`,
//  file name = the ROM file name without its extension). RetroArch named the file the
//  same way (content basename minus its last extension), so the mapping is by name.
//
//  Copies, never moves and never overwrites. Runs off the main thread after core
//  registration, and is marked done only when every .srm was copied or already had a
//  file at its destination. Files with no matching game (not imported yet), or whose copy
//  failed, keep it pending for the next launch.
//

import Foundation
import PVFileSystem
import PVLogging
import PVRealm

struct RetroArchBatterySaveJob: Sendable, Equatable {
    /// `.srm` files found in RetroArch's save directories, in processing order.
    let srmFiles: [URL]
    /// ROM file names without extension, for games in the library whose name matches an `.srm`.
    let knownRomBases: Set<String>
}

enum RetroArchBatterySaveMigration {
    static let doneKey = "RetroArchBatterySaveMigration.done"
    static let srmExtension = "srm"
    /// RetroArch's save directory, relative to its documents root.
    static let savesRelativePath = "RetroArch/saves"
    /// Prefix of the hidden temp file a copy goes through before its final rename.
    static let tempFilePrefix = ".retroarch-srm-migration-"

    static func isDone(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: doneKey)
    }

    static func markDone(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: doneKey)
    }

    // MARK: Path mapping

    /// The ROM base name RetroArch encoded in a save file name: the name minus `.srm`.
    static func romBase(ofSRM srm: URL) -> String {
        srm.deletingPathExtension().lastPathComponent
    }

    /// Where the thin wrapper reads this game's battery save:
    /// `<batteryRoot>/<romBase>/<romBase>.srm`.
    static func destination(forRomBase romBase: String, batteryRoot: URL) -> URL {
        batteryRoot.appendingPathComponent(romBase, isDirectory: true)
            .appendingPathComponent(romBase)
            .appendingPathExtension(srmExtension)
    }

    /// RetroArch save directories under each documents root, de-duplicated (the roots can
    /// be the same folder, or one a symlink to another).
    static func savesDirectories(documentsRoots: [URL]) -> [URL] {
        var seen = Set<String>()
        return documentsRoots.compactMap { root in
            let saves = root.appendingPathComponent(savesRelativePath, isDirectory: true)
            let key = saves.standardizedFileURL.resolvingSymlinksInPath().path
            return seen.insert(key).inserted ? saves : nil
        }
    }

    /// Documents roots 3.3.x RetroArch could have used: the app container's Documents
    /// (iOS), Caches (tvOS, where Documents is not writable), and the library root.
    static func defaultDocumentsRoots(fileManager: FileManager = .default) -> [URL] {
        var roots = [URL]()
        roots += fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        roots += fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        roots.append(URL.documentsPath)
        return roots
    }

    /// `.srm` files directly in `savesDirectory`, then in its immediate subfolders (where
    /// RetroArch puts them when "sort saves by core/content" is on). Hidden files skipped.
    static func srmFiles(in savesDirectory: URL, fileManager: FileManager = .default) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(at: savesDirectory,
                                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                                 options: .skipsHiddenFiles) else { return [] }
        func isDirectory(_ url: URL) -> Bool {
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        func isSRM(_ url: URL) -> Bool {
            url.pathExtension.lowercased() == srmExtension && !isDirectory(url)
        }
        let sorted = entries.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var files = sorted.filter(isSRM)
        for folder in sorted where isDirectory(folder) {
            let nested = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                               options: .skipsHiddenFiles)) ?? []
            files += nested.filter(isSRM).sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        return files
    }

    // MARK: Migration

    /// What a pass did.
    struct Outcome: Equatable {
        /// One line per file copied or failed.
        var log: [String] = []
        var copied = 0
        /// The destination already had a file (an earlier pass, or a newer thin save).
        var alreadyPresent = 0
        /// Save files with no game of that name in the library.
        var unmatched: [String] = []
        var failed = 0

        /// Every file was copied or already had a destination.
        var isComplete: Bool { failed == 0 && unmatched.isEmpty }
    }

    /// Copies each `.srm` whose name matches a known ROM to the thin wrapper's path.
    static func migrate(srmFiles: [URL], knownRomBases: Set<String>, batteryRoot: URL,
                        fileManager: FileManager = .default) -> Outcome {
        var outcome = Outcome()
        for source in srmFiles {
            let base = romBase(ofSRM: source)
            guard knownRomBases.contains(base) else {
                outcome.unmatched.append(source.lastPathComponent)
                continue
            }
            let target = destination(forRomBase: base, batteryRoot: batteryRoot)
            if fileManager.fileExists(atPath: target.path) {
                outcome.alreadyPresent += 1
                continue
            }
            let folder = target.deletingLastPathComponent()
            let temp = folder.appendingPathComponent(tempFilePrefix + UUID().uuidString)
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                try fileManager.copyItem(at: source, to: temp)
                try fileManager.moveItem(at: temp, to: target)
                outcome.copied += 1
                outcome.log.append("copied \(source.lastPathComponent) to Battery States/\(base)/")
            } catch {
                try? fileManager.removeItem(at: temp)
                outcome.failed += 1
                outcome.log.append("could not copy \(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return outcome
    }

    /// The pending job, or nil when done or there is nothing to do. Reads Realm (call on
    /// the thread that owns `database`). With no RetroArch save directory at all there is
    /// nothing to migrate, ever, so that marks it done.
    static func pendingJob(in database: RomDatabase,
                           documentsRoots: [URL] = defaultDocumentsRoots(),
                           fileManager: FileManager = .default,
                           defaults: UserDefaults = .standard) -> RetroArchBatterySaveJob? {
        guard !isDone(defaults: defaults) else { return nil }
        let existing = savesDirectories(documentsRoots: documentsRoots).filter {
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: $0.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        guard !existing.isEmpty else {
            markDone(defaults: defaults)
            return nil
        }
        let files = existing.flatMap { srmFiles(in: $0, fileManager: fileManager) }
        guard !files.isEmpty else {
            markDone(defaults: defaults)
            return nil
        }
        let wanted = Set(files.map(romBase(ofSRM:)))
        let known = Set(database.all(PVGame.self).map { RetiredBatterySaveMigration.romBase(of: $0.romPath) })
        return RetroArchBatterySaveJob(srmFiles: files, knownRomBases: wanted.intersection(known))
    }

    /// File work; call off the main thread (the Paths roots may block on iCloud).
    static func run(_ job: RetroArchBatterySaveJob, batteryRoot: URL,
                    fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        let outcome = migrate(srmFiles: job.srmFiles, knownRomBases: job.knownRomBases,
                              batteryRoot: batteryRoot, fileManager: fileManager)
        for line in outcome.log {
            ILOG("RetroArchBatterySaveMigration: \(line)")
        }
        ILOG("RetroArchBatterySaveMigration: \(outcome.copied) copied, \(outcome.alreadyPresent) already present, "
             + "\(outcome.unmatched.count) unmatched, \(outcome.failed) failed")
        if !outcome.unmatched.isEmpty {
            // Not imported yet (or never will be); retried next launch.
            DLOG("RetroArchBatterySaveMigration: no matching game for \(outcome.unmatched.joined(separator: ", "))")
        }
        if outcome.isComplete {
            markDone(defaults: defaults)
        }
    }
}
