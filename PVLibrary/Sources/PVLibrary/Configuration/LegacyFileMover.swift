//
//  LegacyFileMover.swift
//
//
//  Created by Joseph Mattiello on 6/21/24.
//

import Foundation
import PVLogging
import PVFileSystem

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
}
