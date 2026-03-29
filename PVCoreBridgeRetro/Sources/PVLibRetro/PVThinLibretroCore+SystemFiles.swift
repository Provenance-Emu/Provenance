//
//  PVThinLibretroCore+SystemFiles.swift
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provides two complementary mechanisms for populating system files that
//  libretro cores need at runtime:
//
//  1. **Libretro buildbot download** — downloads zip packages from
//     https://buildbot.libretro.com/assets/system/ when required system
//     files are missing.  Downloads are asynchronous; emulation starts
//     immediately and the files are available on the next launch.
//
//  2. **Legacy RetroArch directory migration** — when a user upgrades from
//     the PVRetroArchCore backend to the thin wrapper, their existing files
//     in `Documents/RetroArch/system/` are copied (not moved) into the
//     thin-wrapper's canonical `Documents/System/<name>/` tree.  The copy
//     is idempotent, so re-launching the same game never re-copies.
//

import Foundation
import PVLogging
import PVArchiving

// MARK: - Libretro Buildbot System File Definitions

/// Describes a zip package of system files available from the libretro buildbot.
struct LibretroSystemFilePackage {
    /// Absolute URL for the zip to download.
    let url: URL
    /// A file whose presence indicates the package is already installed.
    /// Relative to `targetDirectory`.
    let sentinelFile: String
    /// Subdirectory relative to the system dir where files should be extracted.
    /// `nil` means extract directly into the system dir root.
    let subdirectory: String?

    init(url: URL, sentinelFile: String, subdirectory: String? = nil) {
        self.url = url
        self.sentinelFile = sentinelFile
        self.subdirectory = subdirectory
    }
}

/// Buildbot base URL and per-core package catalogue.
enum LibretroBuildbot {
    static let systemBaseURL = "https://buildbot.libretro.com/assets/system"

    /// Returns the zip packages that must be present for a given core ID.
    /// `coreID` should already be lowercased by the caller.
    static func packages(forCoreID coreID: String) -> [LibretroSystemFilePackage] {
        var result: [LibretroSystemFilePackage] = []

        // PrBoom — doom engine needs prboom.wad
        if coreID.contains("prboom") {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/prboom.zip")!,
                sentinelFile: "prboom.wad"
            ))
        }

        // ECWolf — Wolf3D engine needs ecwolf.pk3
        if coreID.contains("ecwolf") {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/ecwolf.zip")!,
                sentinelFile: "ecwolf.pk3"
            ))
        }

        // MSX / BlueMSX — needs MSX BIOS ROM set
        if coreID.contains("fmsx") || coreID.contains("bluemsx") {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/MSX.zip")!,
                sentinelFile: "MSX.ROM",
                subdirectory: "MSX"
            ))
        }

        // FBNeo / FBAlpha — NeoGeo BIOS for arcade emulation
        if coreID.contains("fbneo") || coreID.contains("fbalpha") {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/fbalpha2012_neogeo.zip")!,
                sentinelFile: "neogeo.zip",
                subdirectory: "fbneo"
            ))
        }

        // MAME — machine data / artwork / BIOS pack
        if coreID.contains("mame2003") {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/mame2003-plus.zip")!,
                sentinelFile: "mame2003-plus",
                subdirectory: "mame2003-plus"
            ))
        } else if coreID.contains("mame") {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/mame.zip")!,
                sentinelFile: "mame",
                subdirectory: "mame"
            ))
        }

        // Rick Dangerous — game data pack
        if coreID.contains("rick_dangerous") || coreID == "rick" {
            result.append(LibretroSystemFilePackage(
                url: URL(string: "\(systemBaseURL)/rick.zip")!,
                sentinelFile: "rick.pak"
            ))
        }

        return result
    }
}

// MARK: - System Files Extension

extension PVThinLibretroCore {

    // MARK: - Computed system directory helper

    /// Canonical thin-wrapper system directory for the current core, derived from `BIOSPath`.
    ///
    /// For systems that have a dedicated short name (PSP → `System/PSP`, DC → `System/DC`, etc.)
    /// returns `<docs>/System/<shortName>`.  For all others falls back to `BIOSPath`.
    /// Returns `nil` when `BIOSPath` is unavailable.
    var thinSystemFilesDirectory: String? {
        guard let biosPath = BIOSPath, !biosPath.isEmpty else { return nil }
        // BIOSPath = <docs>/BIOS/<systemIdentifier> — strip 2 components → <docs>
        let docsDir = URL(fileURLWithPath: biosPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        guard docsDir != "/" && !docsDir.isEmpty else { return nil }

        if let sysID = systemIdentifier,
           let shortName = PVSystemDirectoryHelper.systemDirectoryName(forIdentifier: sysID),
           !shortName.isEmpty {
            return URL(fileURLWithPath: docsDir)
                .appendingPathComponent("System/\(shortName)")
                .path
        }
        return biosPath
    }

    /// The base documents root derived from `BIOSPath` (<docs>/BIOS/<sysID> → <docs>).
    var thinDocsDirectory: String? {
        guard let biosPath = BIOSPath, !biosPath.isEmpty else { return nil }
        let docs = URL(fileURLWithPath: biosPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        guard docs != "/" && !docs.isEmpty else { return nil }
        return docs
    }

    // MARK: - Buildbot system file download

    /// Download any missing system-file packages from the libretro buildbot.
    ///
    /// Called from `applyPlatformDefaults()` during core startup.  Downloads run
    /// asynchronously — emulation is not blocked.  Files will be present on the
    /// next game launch.
    func downloadBuildBotSystemFilesIfNeeded() {
        guard let coreID = coreIdentifier?.lowercased(), !coreID.isEmpty else { return }

        let packages = LibretroBuildbot.packages(forCoreID: coreID)
        guard !packages.isEmpty else { return }

        guard let sysDir = thinSystemFilesDirectory else {
            WLOG("ThinCore[SystemFiles]: cannot download — system dir unavailable for \(coreID)")
            return
        }

        let fm = FileManager.default
        for package in packages {
            let targetDir: String
            if let sub = package.subdirectory {
                targetDir = URL(fileURLWithPath: sysDir).appendingPathComponent(sub).path
            } else {
                targetDir = sysDir
            }
            let sentinelPath = URL(fileURLWithPath: targetDir)
                .appendingPathComponent(package.sentinelFile).path

            if fm.fileExists(atPath: sentinelPath) {
                DLOG("ThinCore[SystemFiles]: '\(package.sentinelFile)' present — skipping download")
                continue
            }

            ILOG("ThinCore[SystemFiles]: fetching \(package.url.lastPathComponent) for \(coreID)")
            downloadAndExtractPackage(from: package.url, toDirectory: targetDir)
        }
    }

    /// Asynchronously download a zip from `url` and extract it into `destDir`.
    private func downloadAndExtractPackage(from url: URL, toDirectory destDir: String) {
        let downloadTask = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            if let error = error {
                ELOG("ThinCore[SystemFiles]: download error (\(url.lastPathComponent)): \(error.localizedDescription)")
                return
            }
            guard let tempURL = tempURL else {
                ELOG("ThinCore[SystemFiles]: no temp URL for \(url.lastPathComponent)")
                return
            }

            let fm = FileManager.default
            do {
                try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
            } catch {
                ELOG("ThinCore[SystemFiles]: could not create dir \(destDir): \(error.localizedDescription)")
                try? fm.removeItem(at: tempURL)
                return
            }

            do {
                try Self.unzipFile(at: tempURL, to: URL(fileURLWithPath: destDir))
                ILOG("ThinCore[SystemFiles]: extracted \(url.lastPathComponent) → \(destDir)")
            } catch {
                ELOG("ThinCore[SystemFiles]: extraction failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
            try? fm.removeItem(at: tempURL)
        }
        downloadTask.resume()
    }

    // MARK: - Legacy RetroArch directory migration

    /// Copy system files from the legacy `Documents/RetroArch/system/` directory
    /// into the thin-wrapper's canonical `Documents/System/<name>/` tree.
    ///
    /// This enables a seamless upgrade path: users who already have system files
    /// populated by the old PVRetroArchCore backend can switch to the thin wrapper
    /// without manually reinstalling BIOS/system data.
    ///
    /// Copies are idempotent — existing destination files are never overwritten.
    /// The source RetroArch directory is left intact so it can still be used if the
    /// user switches back.
    func migrateRetroArchSystemDirectoryIfNeeded() {
        guard let docsDir = thinDocsDirectory else { return }
        let legacySystemDir = URL(fileURLWithPath: docsDir)
            .appendingPathComponent("RetroArch/system")
            .path

        let fm = FileManager.default
        guard fm.fileExists(atPath: legacySystemDir) else {
            DLOG("ThinCore[SystemFiles]: no legacy RetroArch/system dir at \(legacySystemDir)")
            return
        }

        guard let coreID = coreIdentifier?.lowercased(), !coreID.isEmpty,
              let destDir = thinSystemFilesDirectory else { return }

        DLOG("ThinCore[SystemFiles]: checking legacy RetroArch/system for \(coreID)")

        // 1. Migrate whole subdirectories (e.g. PSP/, Sys/ for Dolphin, MSX/)
        for subDir in legacySubdirectories(forCoreID: coreID) {
            copyLegacyItem(
                at: URL(fileURLWithPath: legacySystemDir).appendingPathComponent(subDir).path,
                to: URL(fileURLWithPath: destDir).appendingPathComponent(subDir).path,
                fm: fm
            )
        }

        // 2. Migrate individual root-level files (e.g. prboom.wad, ecwolf.pk3)
        for fileName in legacyRootFiles(forCoreID: coreID) {
            copyLegacyItem(
                at: URL(fileURLWithPath: legacySystemDir).appendingPathComponent(fileName).path,
                to: URL(fileURLWithPath: destDir).appendingPathComponent(fileName).path,
                fm: fm
            )
        }
    }

    /// Copy a single file or directory from `src` to `dst` if:
    /// - `src` exists, AND
    /// - `dst` does not already exist.
    private func copyLegacyItem(at src: String, to dst: String, fm: FileManager) {
        guard fm.fileExists(atPath: src) else { return }
        guard !fm.fileExists(atPath: dst) else {
            DLOG("ThinCore[SystemFiles]: already present, skip migration: \(URL(fileURLWithPath: dst).lastPathComponent)")
            return
        }
        do {
            let dstParent = URL(fileURLWithPath: dst).deletingLastPathComponent().path
            try fm.createDirectory(atPath: dstParent, withIntermediateDirectories: true)
            try fm.copyItem(atPath: src, toPath: dst)
            ILOG("ThinCore[SystemFiles]: migrated legacy → \(URL(fileURLWithPath: dst).lastPathComponent)")
        } catch {
            WLOG("ThinCore[SystemFiles]: migration failed \(URL(fileURLWithPath: src).lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Subdirectory names that live under `RetroArch/system/<sub>/` for a given core.
    private func legacySubdirectories(forCoreID coreID: String) -> [String] {
        if coreID.contains("ppsspp") {
            return ["PSP"]
        }
        if coreID.contains("dolphin") {
            // Dolphin stores GC/Wii firmware under RetroArch/system/Sys/
            return ["Sys"]
        }
        if coreID.contains("bluemsx") {
            return ["MSX", "MSX2", "MSX2+", "Machines", "Databases"]
        }
        if coreID.contains("fmsx") {
            return ["MSX"]
        }
        if coreID.contains("fbneo") || coreID.contains("fbalpha") {
            return ["fbneo", "fbalpha"]
        }
        if coreID.contains("mame2003") {
            return ["mame2003-plus"]
        }
        if coreID.contains("mame") {
            return ["mame"]
        }
        // VICE Commodore emulator — each machine variant stores its ROMs in a
        // machine-named subdirectory directly under the RetroArch system root.
        // e.g. RetroArch/system/C64/ → System/C64/C64/
        if coreID.contains("vice") {
            return ["C64", "C64DTV", "C64SC", "C128", "VIC20",
                    "PET", "CBM-II", "CBM-II-5x0", "PLUS4", "SCPU64"]
        }
        // melonDS — some RetroArch installations place DS system files in a
        // melonDS/ subdirectory to keep them separate from other cores.
        if coreID.contains("melonds") {
            return ["melonDS"]
        }
        return []
    }

    /// Individual file names at `RetroArch/system/` root that belong to a given core.
    private func legacyRootFiles(forCoreID coreID: String) -> [String] {
        if coreID.contains("prboom") {
            return ["prboom.wad"]
        }
        if coreID.contains("ecwolf") {
            return ["ecwolf.pk3"]
        }
        if coreID.contains("fmsx") {
            // fMSX expects ROM files at the system root
            return ["MSX.ROM", "MSX2.ROM", "MSX2EXT.ROM", "MSX2P.ROM", "MSX2PEXT.ROM",
                    "DISK.ROM", "DOS1.ROM", "DOS2.ROM"]
        }
        if coreID.contains("rick_dangerous") || coreID == "rick" {
            return ["rick.pak"]
        }
        // VICE — machine-specific config files live at the RetroArch system root.
        if coreID.contains("vice") {
            // Each VICE variant writes a per-machine config file to the system root.
            return ["vice-c64.cfg", "vice-c64dtv.cfg", "vice-c64sc.cfg",
                    "vice-c128.cfg", "vice-xvic.cfg", "vice-xpet.cfg",
                    "vice-xcbm2.cfg", "vice-xcbm5x0.cfg", "vice-xplus4.cfg",
                    "vice-xscpu64.cfg"]
        }
        // melonDS — BIOS/firmware files may live at the RetroArch system root
        // when the melonDS/ subdirectory layout is NOT used.
        if coreID.contains("melonds") {
            return ["bios7.bin", "bios9.bin", "firmware.bin",
                    "dsi_bios7.bin", "dsi_bios9.bin", "dsi_firmware.bin", "dsi_nand.bin"]
        }
        return []
    }

    private static func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        try ArchiveManager.shared.unzipFile(at: sourceURL, to: destinationURL)
    }
}
