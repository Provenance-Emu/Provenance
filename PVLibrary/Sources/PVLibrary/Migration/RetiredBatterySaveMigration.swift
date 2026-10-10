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

    /// Applies `rules` to one ROM. Returns one line per file moved or copied.
    @discardableResult
    static func migrate(romBase: String, rules: [RetiredBatterySaveRule], batteryRoot: URL, saveStatesRoot: URL,
                        fileManager: FileManager = .default) -> [String] {
        var log: [String] = []
        let batteryFolder = batteryRoot.appendingPathComponent(romBase, isDirectory: true)
        func file(in folder: URL, _ ext: String) -> URL {
            folder.appendingPathComponent(romBase).appendingPathExtension(ext)
        }
        for rule in rules {
            let sourceFolder = rule.location == .batterySaves
                ? batteryFolder
                : saveStatesRoot.appendingPathComponent(romBase, isDirectory: true)
            var current = file(in: sourceFolder, rule.fileExtension)

            if rule.moveToBatterySaves, sourceFolder != batteryFolder {
                let destination = file(in: batteryFolder, rule.fileExtension)
                if fileManager.fileExists(atPath: current.path), !fileManager.fileExists(atPath: destination.path) {
                    do {
                        try fileManager.createDirectory(at: batteryFolder, withIntermediateDirectories: true)
                        try fileManager.moveItem(at: current, to: destination)
                        log.append("moved \(current.lastPathComponent) from Save States to Battery States")
                    } catch {
                        log.append("could not move \(current.lastPathComponent): \(error.localizedDescription)")
                        continue
                    }
                }
                current = destination
            }

            guard rule.copyToSRM, fileManager.fileExists(atPath: current.path) else { continue }
            let srm = file(in: batteryFolder, srmExtension)
            guard !fileManager.fileExists(atPath: srm.path) else { continue }
            do {
                try fileManager.createDirectory(at: batteryFolder, withIntermediateDirectories: true)
                try fileManager.copyItem(at: current, to: srm)
                log.append("copied \(current.lastPathComponent) to \(srm.lastPathComponent)")
            } catch {
                log.append("could not copy \(current.lastPathComponent) to .\(srmExtension): \(error.localizedDescription)")
            }
        }
        return log
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
    static func run(_ jobs: [RetiredBatterySaveJob], batteryRoot: URL, saveStatesRoot: URL,
                    fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        for job in jobs {
            for romBase in job.romBases {
                for line in migrate(romBase: romBase, rules: job.rules, batteryRoot: batteryRoot,
                                    saveStatesRoot: saveStatesRoot, fileManager: fileManager) {
                    ILOG("RetiredBatterySaveMigration: \(job.retiredID) \(romBase): \(line)")
                }
            }
            markDone(job.retiredID, defaults: defaults)
        }
    }
}
