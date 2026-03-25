//
//  ArchiveZipSupportChecker.swift
//  PVLibrary
//
//  Created on 12/14/24.
//

import Foundation
import PVLogging
import PVSystems
import PVLookup
import PVPrimitives

/// Feature flag to enable/disable zip-as-ROM support checking
/// Set to false to disable this feature if bugs are found
#if DEBUG
public var ENABLE_ZIP_AS_ROM_SUPPORT: Bool = true
#else
public var ENABLE_ZIP_AS_ROM_SUPPORT: Bool = true
#endif

/// Service to check if an archive (zip) should be kept as-is instead of extracted
/// for systems that support archives directly (e.g., MAME)
public actor ArchiveZipSupportChecker {
    public static let shared = ArchiveZipSupportChecker()

    private let lookup: PVLookup

    private init() {
        self.lookup = PVLookup.shared
    }

    /// Checks if an archive should be kept as-is instead of extracted
    /// - Parameter archiveURL: The URL of the archive file
    /// - Returns: Tuple containing (shouldKeepAsIs: Bool, matchingSystemID: SystemIdentifier?)
    public func shouldKeepArchiveAsIs(_ archiveURL: URL) async -> (shouldKeep: Bool, systemID: SystemIdentifier?) {
        guard ENABLE_ZIP_AS_ROM_SUPPORT else {
            return (false, nil)
        }

        let fileExtension = archiveURL.pathExtension.lowercased()

        // Only check zip files for now (can be extended to other archive types)
        guard fileExtension == "zip" else {
            return (false, nil)
        }

        // Determine potential systems for this archive
        let systems: [SystemIdentifier]
        do {
            systems = try await determineSystemsForArchive(archiveURL)
        } catch {
            WLOG("Failed to determine systems for archive \(archiveURL.lastPathComponent): \(error.localizedDescription)")
            return (false, nil)
        }

        // Optimize: If we have a known system from path/extension, check it directly
        // Otherwise, do a single unfiltered query and filter results
        if systems.count == 1, let systemID = systems.first {
            // Single system known - check it directly
            if let pvSystem = PVSystem.all.first(where: { $0.identifier == systemID.rawValue }),
               pvSystem.supportedExtensions.contains("zip"),
               await checkLibretroDatabaseMatch(archiveURL: archiveURL, systemID: systemID) {
                ILOG("Archive \(archiveURL.lastPathComponent) matches known system \(systemID.rawValue) that supports zip directly")
                return (true, systemID)
            }
        } else if systems.isEmpty || systems.count > 3 {
            // No known systems OR too many systems - do single unfiltered query (much faster)
            let filename = archiveURL.lastPathComponent.lowercased()
            let searchName = filename // Keep extension for zip files

            do {
                // Single unfiltered query (no systemID) - much faster than N queries
                if let results = try await lookup.searchDatabase(usingFilename: searchName, systemID: nil),
                   !results.isEmpty {
                    // Filter results to only systems that support zip
                    let zipSupportingSystems = Set(PVSystem.all
                        .filter { $0.supportedExtensions.contains("zip") }
                        .compactMap { SystemIdentifier(rawValue: $0.identifier) })

                    // Find matching systems from results
                    var matchingSystems: [(systemID: SystemIdentifier, priority: Int)] = []
                    for result in results {
                        let resultSystemID = result.systemID
                        if zipSupportingSystems.contains(resultSystemID) {
                            let priority = systemPriority(for: resultSystemID)
                            matchingSystems.append((systemID: resultSystemID, priority: priority))
                        }
                    }

                    if !matchingSystems.isEmpty {
                        // Sort by priority and return best match
                        matchingSystems.sort { $0.priority < $1.priority }
                        let bestMatch = matchingSystems.first!
                        ILOG("Archive \(archiveURL.lastPathComponent) matches system \(bestMatch.systemID.rawValue) via unfiltered query (checked \(results.count) results)")
                        return (true, bestMatch.systemID)
                    }
                }
            } catch {
                WLOG("Failed unfiltered database query for archive \(archiveURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Fallback: Check each system individually (only if we have a small number of known systems)
        if !systems.isEmpty && systems.count <= 3 {
            var matchingSystems: [(systemID: SystemIdentifier, priority: Int)] = []

            for systemID in systems {
                if let pvSystem = PVSystem.all.first(where: { $0.identifier == systemID.rawValue }),
                   pvSystem.supportedExtensions.contains("zip"),
                   await checkLibretroDatabaseMatch(archiveURL: archiveURL, systemID: systemID) {
                    let priority = systemPriority(for: systemID)
                    matchingSystems.append((systemID: systemID, priority: priority))
                }
            }

            if !matchingSystems.isEmpty {
                matchingSystems.sort { $0.priority < $1.priority }
                let bestMatch = matchingSystems.first!
                ILOG("Archive \(archiveURL.lastPathComponent) matches system \(bestMatch.systemID.rawValue) via individual checks")
                return (true, bestMatch.systemID)
            }
        }

        return (false, nil)
    }

    /// Checks if a folder should be treated as a MAME ROM set.
    ///
    /// MAME ROM sets are sometimes distributed as unpacked folders rather than ZIP archives.
    /// A folder named `mk` is equivalent to `mk.zip` for MAME — both contain the same ROM files.
    ///
    /// Detection strategy: look up `<folderName>.zip` in the libretro database for the MAME system.
    /// If found, the folder is a recognised MAME ROM set.
    ///
    /// - Parameter folderURL: URL of the directory to check.
    /// - Returns: `.MAME` (or another arcade system identifier) if the folder matches a known ROM set, `nil` otherwise.
    public func shouldTreatFolderAsMameRom(_ folderURL: URL) async -> SystemIdentifier? {
        guard ENABLE_ZIP_AS_ROM_SUPPORT else { return nil }

        let folderName = folderURL.lastPathComponent.lowercased()
        guard !folderName.isEmpty else { return nil }

        // Search the libretro database using "<folderName>.zip" — that is how MAME ROMs are stored.
        let searchName = "\(folderName).zip"
        do {
            if let results = try await lookup.searchDatabase(usingFilename: searchName, systemID: .MAME),
               !results.isEmpty {
                ILOG("Folder '\(folderName)' matches MAME ROM set via libretro DB (searched as '\(searchName)')")
                return .MAME
            }
        } catch {
            WLOG("Failed to query libretro DB for MAME folder '\(folderName)': \(error.localizedDescription)")
        }

        // Also check other arcade systems that use ZIP-named ROM sets (CPS1/2/3).
        let arcadeSystems: [SystemIdentifier] = [.CPS1, .CPS2, .CPS3]
        for systemID in arcadeSystems {
            do {
                if let results = try await lookup.searchDatabase(usingFilename: searchName, systemID: systemID),
                   !results.isEmpty {
                    ILOG("Folder '\(folderName)' matches \(systemID.rawValue) ROM set via libretro DB")
                    return systemID
                }
            } catch {
                WLOG("Failed to query libretro DB for folder '\(folderName)' against \(systemID.rawValue): \(error.localizedDescription)")
            }
        }

        return nil
    }

    /// Returns priority for system matching (lower number = higher priority)
    /// MAME gets highest priority since it's the general arcade emulator
    private func systemPriority(for systemID: SystemIdentifier) -> Int {
        switch systemID {
        case .MAME:
            return 0
        case .CPS1, .CPS2, .CPS3:
            return 1
        default:
            return 2
        }
    }

    /// Determines which systems could potentially use this archive
    private func determineSystemsForArchive(_ archiveURL: URL) async throws -> [SystemIdentifier] {
        let filename = archiveURL.lastPathComponent
        let fileExtension = archiveURL.pathExtension.lowercased()

        // Use the same logic as GameImporterSystemsService
        // Step 1: Check if file is already in a system directory
        if let system = SystemIdentifier(rawValue: archiveURL.deletingLastPathComponent().lastPathComponent) {
            return [system]
        }

        // Step 2: Extension-based filtering
        let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) ?? []
        let systemIdentifiers = systems.compactMap { $0.systemIdentifier }

        // If we have systems from extension, return them
        if !systemIdentifiers.isEmpty {
            return systemIdentifiers
        }

        // Step 3: Try filename-based matching
        let filenameBasedSystems = findSystemsByNameInFilename(filename)
        if !filenameBasedSystems.isEmpty {
            return filenameBasedSystems
        }

        return []
    }

    /// Checks libretro database for a match (case-insensitive filename matching)
    private func checkLibretroDatabaseMatch(archiveURL: URL, systemID: SystemIdentifier) async -> Bool {
        let filename = archiveURL.lastPathComponent.lowercased()

        // For zip files, search with extension included since libretro database stores them with extension
        // (e.g., "mk.zip" is stored as "mk.zip" in the roms.name column)
        let searchName: String
        if archiveURL.pathExtension.lowercased() == "zip" {
            // Search with extension for zip files (MAME ROMs are stored as "mk.zip" in database)
            searchName = filename
        } else {
            // For other archives, search without extension
            searchName = archiveURL.deletingPathExtension().lastPathComponent.lowercased()
        }

        do {
            // Search libretro database for matching ROM
            if let results = try await lookup.searchDatabase(usingFilename: searchName, systemID: systemID),
               !results.isEmpty {
                // Found match in database - archive should be kept as-is
                ILOG("Found libretro DB match for archive \(archiveURL.lastPathComponent) (searched as '\(searchName)') in system \(systemID.rawValue)")
                return true
            } else {
                VLOG("No libretro DB match found for archive \(archiveURL.lastPathComponent) (searched as '\(searchName)') in system \(systemID.rawValue)")
            }
        } catch {
            // If lookup fails, err on the side of extraction (safer)
            WLOG("Failed to check libretro database for archive \(archiveURL.lastPathComponent): \(error.localizedDescription)")
        }

        return false
    }

    /// Find systems by looking for system names in the filename
    private func findSystemsByNameInFilename(_ filename: String) -> [SystemIdentifier] {
        let normalizedFilename = " \(filename.lowercased()) "
        var matchingSystems = [SystemIdentifier]()

        for system in SystemIdentifier.allCases {
            if system == .Unknown {
                continue
            }

            let shortName = system.systemName
                .components(separatedBy: " - ")
                .last?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

            if shortName.isEmpty {
                continue
            }

            let patterns = [
                " \(shortName) ",
                "(\(shortName))",
                "[\(shortName)]",
                "{\(shortName)}"
            ]

            for pattern in patterns {
                if normalizedFilename.contains(pattern.lowercased()) {
                    matchingSystems.append(system)
                    break
                }
            }
        }

        return matchingSystems
    }
}
