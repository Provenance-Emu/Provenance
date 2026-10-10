//
//  RetiredBatterySaveMigration.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Puts battery saves that retired native cores left on disk where their libretro
//  replacements read them: `Battery States/<rom>/<rom>.srm` (thin wrapper SAVE_RAM),
//  and for the legacy libretro bridge, which answered GET_SAVE_DIRECTORY with the Save
//  States folder, back into Battery States. Copies (never overwrites); moves only out of
//  Save States. Runs once per retired core, off the main thread, after core registration.
//

import Foundation
import PVLogging
import PVRealm

struct RetiredBatterySaveJob: Sendable, Equatable {
    let retiredID: String
    let rules: [RetiredBatterySaveRule]
    /// ROM file names without extension: each has `<root>/<romBase>/` folders.
    let romBases: [String]
}

enum RetiredBatterySaveMigration {
    static let srmExtension = "srm"
    static let doneKeyPrefix = "RetiredBatterySaveMigration."

    static func romBase(of romPath: String) -> String {
        URL(fileURLWithPath: romPath).deletingPathExtension().lastPathComponent
    }

    static func isDone(_ retiredID: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: doneKeyPrefix + retiredID)
    }

    static func markDone(_ retiredID: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: doneKeyPrefix + retiredID)
    }

    /// What one ROM's pass did.
    struct Outcome: Equatable {
        /// One line per file moved or copied, or that failed.
        var log: [String] = []
        /// A source file for some rule existed (even if already migrated).
        var foundSource = false
        var failed = false
    }

    /// Applies `rules` to one ROM. Returns one line per file moved or copied.
    @discardableResult
    static func migrate(romBase: String, rules: [RetiredBatterySaveRule], batteryRoot: URL, saveStatesRoot: URL,
                        fileManager: FileManager = .default) -> [String] {
        migrateOutcome(romBase: romBase, rules: rules, batteryRoot: batteryRoot,
                       saveStatesRoot: saveStatesRoot, fileManager: fileManager).log
    }

    static func migrateOutcome(romBase: String, rules: [RetiredBatterySaveRule], batteryRoot: URL, saveStatesRoot: URL,
                               fileManager: FileManager = .default) -> Outcome {
        var outcome = Outcome()
        let batteryFolder = batteryRoot.appendingPathComponent(romBase, isDirectory: true)
        func file(in folder: URL, _ ext: String) -> URL {
            folder.appendingPathComponent(romBase).appendingPathExtension(ext)
        }
        for rule in rules {
            let sourceFolder = rule.location == .batterySaves
                ? batteryFolder
                : saveStatesRoot.appendingPathComponent(romBase, isDirectory: true)
            var current = file(in: sourceFolder, rule.fileExtension)
            if fileManager.fileExists(atPath: current.path) { outcome.foundSource = true }

            if rule.moveToBatterySaves, sourceFolder != batteryFolder {
                let destination = file(in: batteryFolder, rule.fileExtension)
                if fileManager.fileExists(atPath: current.path), !fileManager.fileExists(atPath: destination.path) {
                    do {
                        try fileManager.createDirectory(at: batteryFolder, withIntermediateDirectories: true)
                        try fileManager.moveItem(at: current, to: destination)
                        outcome.log.append("moved \(current.lastPathComponent) from Save States to Battery States")
                    } catch {
                        outcome.log.append("could not move \(current.lastPathComponent): \(error.localizedDescription)")
                        outcome.failed = true
                        continue
                    }
                }
                current = destination
                if fileManager.fileExists(atPath: current.path) { outcome.foundSource = true }
            }

            guard rule.copyToSRM, fileManager.fileExists(atPath: current.path) else { continue }
            let srm = file(in: batteryFolder, srmExtension)
            guard !fileManager.fileExists(atPath: srm.path) else { continue }
            do {
                try fileManager.createDirectory(at: batteryFolder, withIntermediateDirectories: true)
                try fileManager.copyItem(at: current, to: srm)
                outcome.log.append("copied \(current.lastPathComponent) to \(srm.lastPathComponent)")
            } catch {
                outcome.log.append("could not copy \(current.lastPathComponent) to .\(srmExtension): \(error.localizedDescription)")
                outcome.failed = true
            }
        }
        return outcome
    }

    /// Jobs for active retired cores with battery rules that haven't run yet. Reads Realm
    /// only (call on the thread that owns `database`); games are matched through the retired
    /// core row's supported systems, which the stale-core prune keeps.
    static func pendingJobs(in database: RomDatabase,
                            retiredCores: [String: RetiredCore] = PVCore.activeRetiredCores,
                            defaults: UserDefaults = .standard) -> [RetiredBatterySaveJob] {
        retiredCores.sorted { $0.key < $1.key }.compactMap { retiredID, retired in
            guard !retired.batterySaves.isEmpty, !isDone(retiredID, defaults: defaults),
                  let core = database.realm.object(ofType: PVCore.self, forPrimaryKey: retiredID) else { return nil }
            let systems = Array(core.supportedSystems.map(\.identifier))
            let bases = database.all(PVGame.self).filter("systemIdentifier IN %@", systems).map { romBase(of: $0.romPath) }
            return RetiredBatterySaveJob(retiredID: retiredID, rules: retired.batterySaves, romBases: Array(Set(bases)).sorted())
        }
    }

    /// File work; call off the main thread (the Paths roots may block on iCloud).
    /// A retired core is marked done only when nothing failed and either a source file was
    /// found or there are no candidate games. Otherwise (a failed move, a not-yet-downloaded
    /// iCloud file, a game imported later) `pendingJobs` returns it again next launch.
    static func run(_ jobs: [RetiredBatterySaveJob], batteryRoot: URL, saveStatesRoot: URL,
                    fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        for job in jobs {
            var found = false
            var failed = false
            for romBase in job.romBases {
                let outcome = migrateOutcome(romBase: romBase, rules: job.rules, batteryRoot: batteryRoot,
                                             saveStatesRoot: saveStatesRoot, fileManager: fileManager)
                for line in outcome.log {
                    ILOG("RetiredBatterySaveMigration: \(job.retiredID) \(romBase): \(line)")
                }
                found = found || outcome.foundSource
                failed = failed || outcome.failed
            }
            if !failed, found || job.romBases.isEmpty {
                markDone(job.retiredID, defaults: defaults)
            }
        }
    }
}
