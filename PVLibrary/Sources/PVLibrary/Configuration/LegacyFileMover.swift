//
//  LegacyFileMover.swift
//
//
//  Created by Joseph Mattiello on 6/21/24.
//

import Foundation
import PVLogging
import PVFileSystem
import PVSystems

// MARK: Move legacy files

public extension PVEmulatorConfiguration {
    class func moveLegacyPaths() async {
        if URL.documentsPath != URL.documentsiCloudOrLocalPath {
            // TODO: Update PVGames and PVSaves for new paths for screenshots and saves

            await moveLegacyBIOSes()
            await moveLegacySaves()
            await moveLegacyScreenshots()
            await moveLegacyBatterySaves()

            // TODO: Move ROMS from old paths, also iCloud? @JoeMatt 7/24
        }

        // Migrate legacy RetroArch/system/ directories to Provenance System/<name>/ tree.
        // This is a one-time, idempotent app-level migration that complements the per-core
        // migration in PVThinLibretroCore+SystemFiles.swift.
        await migrateRetroArchSystemDirectories()
    }

    fileprivate class func moveLegacySaves() async {
        let fm = FileManager.default

        ILOG("Looking up legecy saves")
        if let saves = try? fm.contentsOfDirectory(at: Paths.Legacy.saveSavesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !saves.isEmpty {
            ILOG("Found (\(saves.count)) saves in old path")

            await saves.asyncForEach {
                let newPath = Paths.saveSavesPath.appendingPathComponent($0.lastPathComponent)
                do {
                    try fm.moveItem(at: $0, to: newPath)
                } catch {
                    ELOG("\(error)")
                }
            }
            // TODO: Remove old directory?
        }
    }
    
    fileprivate class func moveLegacyBatterySaves() async {
        let fm = FileManager.default

        ILOG("Looking up legecy battery saves")
        if let batterySaves = try? fm.contentsOfDirectory(at: Paths.Legacy.batterySavesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !batterySaves.isEmpty {
            ILOG("Found (\(batterySaves.count)) Battery Saves in old path")

            await batterySaves.asyncForEach {
                let newPath = Paths.batterySavesPath.appendingPathComponent($0.lastPathComponent)
                do {
                    try fm.moveItem(at: $0, to: newPath)
                } catch {
                    ELOG("\(error)")
                }
            }
        }
    }

    fileprivate class func moveLegacyBIOSes() async {
        let fm = FileManager.default

        ILOG("Looking up legecy bios")
        if let bioses = try? fm.contentsOfDirectory(at: Paths.Legacy.biosesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !bioses.isEmpty {
            ILOG("Found (\(bioses.count)) BIOSes in old path")

            await bioses.asyncForEach {
                let newPath = Paths.biosesPath.appendingPathComponent($0.lastPathComponent)
                do {
                    try fm.moveItem(at: $0, to: newPath)
                } catch {
                    ELOG("\(error)")
                }
            }
        }
    }

    fileprivate class func moveLegacyScreenshots() async {
        let fm = FileManager.default

        ILOG("Looking up legecy screenshots")
        if let screenshots = try? fm.contentsOfDirectory(at: Paths.Legacy.screenShotsPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !screenshots.isEmpty {
            ILOG("Found (\(screenshots.count)) Screenshots in old path")

            await screenshots.asyncForEach {
                let newPath = Paths.screenShotsPath.appendingPathComponent($0.lastPathComponent)
                do {
                    try fm.moveItem(at: $0, to: newPath)
                } catch {
                    ELOG("\(error)")
                }
            }
        }
    }

    // MARK: - Legacy RetroArch System Directory Migration
    //
    // Migrates per-system files from `Documents/RetroArch/system/<subdir>/`
    // into the Provenance canonical `Documents/System/<name>/<subdir>/` tree.
    //
    // This is an app-level complement to the per-core migration in
    // `PVThinLibretroCore+SystemFiles.swift`.  It runs once per app launch
    // during `moveLegacyPaths()` and is fully idempotent (never overwrites).
    //
    // Covered mappings:
    //   PSP/        → System/PSP/PSP/         (PPSSPP flash1/savedata)
    //   Sys/        → System/GC/Sys/          (Dolphin GameCube firmware)
    //   fbneo/      → System/NeoGeo/fbneo/    (FBNeo arcade ROMs)
    //   fbalpha/    → System/NeoGeo/fbalpha/  (FBAlpha arcade ROMs)
    //   MSX/…       → System/MSX/MSX/…        (BlueMSX/fMSX ROMs)
    //   mame/       → System/MAME/mame/       (MAME artwork/BIOS)
    //   C64/…       → System/C64/C64/…        (VICE machine ROMs)
    //   melonDS/    → System/NDS/melonDS/     (melonDS BIOS)
    //   NDS/        → System/NDS/NDS/         (flat NDS system dir)
    //   DC/         → System/DC/DC/           (Dreamcast BIOS)
    //   N64/        → System/N64/N64/         (N64 system files)

    /// Mapping of (subdirectory-in-RetroArch/system/, target-SystemIdentifier).
    /// Files are copied from `RetroArch/system/<source>/` to `System/<name>/<source>/`.
    private static let legacyRetroArchSubdirMappings: [(subdir: String, system: SystemIdentifier)] = [
        ("PSP",         .PSP),
        ("Sys",         .GameCube),
        ("fbneo",       .NeoGeo),
        ("fbalpha",     .NeoGeo),
        ("MSX",         .MSX),
        ("MSX2",        .MSX2),
        ("Machines",    .MSX),
        ("Databases",   .MSX),
        ("mame",        .MAME),
        ("mame2003-plus", .MAME),
        // VICE
        ("C64",         .C64),
        ("C64DTV",      .C64),
        ("C64SC",       .C64),
        ("C128",        .C64),
        ("VIC20",       .C64),
        ("PET",         .C64),
        ("CBM-II",      .C64),
        ("CBM-II-5x0",  .C64),
        ("PLUS4",       .C64),
        ("SCPU64",      .C64),
        // melonDS
        ("melonDS",     .DS),
        ("NDS",         .DS),
        // Dreamcast
        ("DC",          .Dreamcast),
        // N64
        ("N64",         .N64),
    ]

    /// App-level migration: copies subdirectories from the legacy
    /// `Documents/RetroArch/system/` directory into `System/<name>/<subdir>/`.
    ///
    /// Uses `Paths.systemPath(forSystem:)` so the target directory is always
    /// created even if the source doesn't exist.  Never overwrites existing files.
    fileprivate class func migrateRetroArchSystemDirectories() async {
        let fm = FileManager.default
        let legacySystemDir = URL.documentsPath.appendingPathComponent("RetroArch/system")

        guard fm.fileExists(atPath: legacySystemDir.path) else {
            DLOG("LegacyFileMover: no RetroArch/system directory — skipping migration")
            return
        }

        ILOG("LegacyFileMover: migrating RetroArch/system → System/<name>/")
        for (subdir, system) in legacyRetroArchSubdirMappings {
            guard let destRoot = Paths.systemPath(forSystem: system) else { continue }
            let src = legacySystemDir.appendingPathComponent(subdir)
            let dst = destRoot.appendingPathComponent(subdir)

            guard fm.fileExists(atPath: src.path) else { continue }
            guard !fm.fileExists(atPath: dst.path) else {
                DLOG("LegacyFileMover: already present, skipping \(subdir)")
                continue
            }
            do {
                try fm.createDirectory(at: dst.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try fm.copyItem(at: src, to: dst)
                ILOG("LegacyFileMover: migrated RetroArch/system/\(subdir) → System/\(system.systemDirectoryName ?? "?")/\(subdir)")
            } catch {
                WLOG("LegacyFileMover: failed to migrate \(subdir): \(error.localizedDescription)")
            }
        }
    }
}
