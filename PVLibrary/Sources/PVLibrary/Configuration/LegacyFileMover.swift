//
//  LegacyFileMover.swift
//
//
//  Created by Joseph Mattiello on 6/21/24.
//

import Foundation

// MARK: Move legacy files

extension Array {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}

extension Array {
    func concurrentForEach(
        _ operation: @escaping (Element) async -> Void
    ) async {
        // A task group automatically waits for all of its
        // sub-tasks to complete, while also performing those
        // tasks in parallel:
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    await operation(element)
                }
            }
        }
    }
}

public extension PVEmulatorConfiguration {
    class func moveLegacyPaths() async {
        if await documentsPath != documentsiCloudOrLocalPath {
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
                let newPath = await Paths.saveSavesPath.appendingPathComponent($0.lastPathComponent)
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
                let newPath = await Paths.batterySavesPath.appendingPathComponent($0.lastPathComponent)
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
                let newPath = await Paths.biosesPath.appendingPathComponent($0.lastPathComponent)
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
                let newPath = await Paths.screenShotsPath.appendingPathComponent($0.lastPathComponent)
                do {
                    try fm.moveItem(at: $0, to: newPath)
                } catch {
                    ELOG("\(error)")
                }
            }
        }
    }
}
