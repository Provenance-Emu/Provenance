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

        // Check if any system supports zip directly
        guard let systems = try? await determineSystemsForArchive(archiveURL),
              !systems.isEmpty else {
            return (false, nil)
        }

        // Collect all systems that support zip and have a database match
        var matchingSystems: [(systemID: SystemIdentifier, priority: Int)] = []

        for systemID in systems {
            // Find PVSystem from PVSystem.all by matching identifier
            if let pvSystem = PVSystem.all.first(where: { $0.identifier == systemID.rawValue }),
               pvSystem.supportedExtensions.contains("zip") {

                // Try to find match in libretro database
                if await checkLibretroDatabaseMatch(archiveURL: archiveURL, systemID: systemID) {
                    let priority = systemPriority(for: systemID)
                    matchingSystems.append((systemID: systemID, priority: priority))
                }
            }
        }

        // If no matches found, return false
        guard !matchingSystems.isEmpty else {
            return (false, nil)
        }

        // Sort by priority (lower number = higher priority) and return the best match
        matchingSystems.sort { $0.priority < $1.priority }
        let bestMatch = matchingSystems.first!

        ILOG("Archive \(archiveURL.lastPathComponent) matches system \(bestMatch.systemID.rawValue) that supports zip directly - keeping as-is (checked \(matchingSystems.count) matching systems)")
        return (true, bestMatch.systemID)
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
