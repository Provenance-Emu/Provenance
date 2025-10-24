//
//  GameImporterFileService.swift
//  PVLibrary
//
//  Created by David Proskin on 11/5/24.
//

import Foundation
import PVSupport
import RealmSwift
import PVPrimitives

protocol GameImporterFileServicing {
    func moveImportItem(toAppropriateSubfolder queueItem: ImportQueueItem) async throws
    func moveToConflictsFolder(_ queueItem: ImportQueueItem, conflictsPath: URL) async throws
    func removeImportItemFile(_ importItem: ImportQueueItem) throws
}

class GameImporterFileService : GameImporterFileServicing {
    
    init() {
        
    }
    
    //    @MainActor
    package func moveImportItem(toAppropriateSubfolder queueItem: ImportQueueItem) async throws {
        switch (queueItem.fileType) {
            
        case .bios:
            _ = try await handleBIOSItem(queueItem)
        case .skin:
            
            // Nothing to do, skin manager handles this
            return
        case .artwork:
            //TODO: implement me
            return
        case .game,.cdRom, .zip: // TODO: Something different for zips?
            _ = try await processQueueItem(queueItem)
        case .unknown:
            throw GameImporterError.unsupportedFile
        }
    }
    
    // MARK: - BIOS
    
    /// Ensures a BIOS file is copied to appropriate file destinations and notifies BIOSWatcher.
    /// Sets queueItem.destinationUrl to the first successful new path for logging/legacy purposes.
    private func handleBIOSItem(_ queueItem: ImportQueueItem) async throws {
        let originalURL = queueItem.url
        let filename = originalURL.lastPathComponent
        let filenameLowercased = filename.lowercased()
        ILOG("Handling BIOS file: \(filename) from URL: \(originalURL.path)")

        // Standardize URLs for robust path comparison
        let standardizedOriginalURL = originalURL.standardizedFileURL
        let standardizedRomsImportPathURL = Paths.romsImportPath.standardizedFileURL
        let standardizedBiosesPathURL = Paths.biosesPath.standardizedFileURL

        // Consolidate all potential PVBIOS matches (by filename and MD5)
        var potentialBiosMatches = Set<PVBIOS>()
        let allBiosEntries = PVEmulatorConfiguration.biosEntries

        // 1. Match by filename
        allBiosEntries.filter { bios in
            let expectedParts = bios.expectedFilename.components(separatedBy: "|")
            return expectedParts.first?.lowercased() == filenameLowercased
        }.forEach { potentialBiosMatches.insert($0) }

        // 2. Match by MD5 (if available and different from filename matches)
        if let md5 = queueItem.md5?.uppercased() {
            allBiosEntries.filter { $0.expectedMD5.uppercased() == md5 }
                .forEach { potentialBiosMatches.insert($0) }
        }

        if potentialBiosMatches.isEmpty {
            ILOG("No PVBIOS definitions found for \(filename) (MD5: \(queueItem.md5 ?? "N/A")). Cannot process as BIOS.")
            // This might be an error or simply a file that looked like a BIOS but isn't defined.
            // Depending on desired behavior, could throw or just return.
            // For now, let's assume it might be handled as a generic game if no BIOS def exists.
            // throw GameImporterError.noBIOSMatch
            // Let's re-evaluate if this should throw. If determineImportType said .bios, a definition should exist.
            // For now, if no match, we can't proceed with BIOS-specific logic.
            return
        }

        ILOG("Found \(potentialBiosMatches.count) potential PVBIOS definitions for \(filename).")

        // Use standardized paths for comparison
        let isFromImportsFolder = standardizedOriginalURL.deletingLastPathComponent().resolvingSymlinksInPath() == standardizedRomsImportPathURL.resolvingSymlinksInPath()
        let isInBiosDir = standardizedOriginalURL.resolvingSymlinksInPath().path.hasPrefix(standardizedBiosesPathURL.resolvingSymlinksInPath().path) && standardizedOriginalURL.resolvingSymlinksInPath() != standardizedBiosesPathURL.resolvingSymlinksInPath()

        var successfullyProcessed = false
        var successfulNewURLs = [URL]()

        if isFromImportsFolder {
            ILOG("BIOS \(filename) is from Imports folder. Processing copy to system BIOS folders.")
            var allCopiesSucceeded = true // Assume success until a failure
            var attemptedAnyCopy = false

            for biosEntry in potentialBiosMatches {
                guard let system = biosEntry.system else {
                    WLOG("PVBIOS entry \(biosEntry.expectedFilename) has no associated system. Skipping.")
                    continue
                }

                let expectedFilenameForSystem = biosEntry.expectedFilename.components(separatedBy: "|").first ?? filename
                let systemBiosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
                let destinationURL = systemBiosPath.appendingPathComponent(expectedFilenameForSystem)

                do {
                    attemptedAnyCopy = true
                    try FileManager.default.createDirectory(at: systemBiosPath, withIntermediateDirectories: true)
                    
                    // Check if file already exists at destination, potentially from a previous partial import or manual copy
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        // If it's the same file (e.g. by comparing MD5 if available, or just assume if name matches here),
                        // still post notification to ensure DB is correct.
                        ILOG("BIOS file \(destinationURL.lastPathComponent) already exists at \(destinationURL.path) for system \(system.identifier). Notifying BIOSWatcher.")
                        NotificationCenter.default.post(name: .BIOSFileFound, object: destinationURL)
                        successfulNewURLs.append(destinationURL)
                        // No need to copy again if it's already there.
                    } else {
                        try FileManager.default.copyItem(at: originalURL, to: destinationURL)
                        ILOG("Successfully copied \(filename) to \(destinationURL.path) for system \(system.identifier).")
                        NotificationCenter.default.post(name: .BIOSFileFound, object: destinationURL)
                        successfulNewURLs.append(destinationURL)
                    }
                    successfullyProcessed = true // Mark as processed if at least one copy/notification happens
                } catch {
                    ELOG("Failed to copy \(filename) to \(destinationURL.path) for system \(system.identifier): \(error).")
                    allCopiesSucceeded = false
                }
            }

            if successfullyProcessed && allCopiesSucceeded && attemptedAnyCopy {
                ILOG("All copies of \(filename) from Imports succeeded. Deleting original from \(originalURL.path).")
                do {
                    try await FileManager.default.removeItem(at: originalURL)
                } catch {
                    ELOG("Failed to delete original BIOS file \(originalURL.path) from Imports: \(error).")
                }
            } else if attemptedAnyCopy && !allCopiesSucceeded {
                WLOG("Not all copies of \(filename) from Imports succeeded. Original file at \(originalURL.path) will NOT be deleted.")
            } else if !attemptedAnyCopy {
                ILOG("No valid systems found to copy BIOS \(filename) to.")
            }

        } else if isInBiosDir { // Already in some BIOS folder (e.g. root or system subfolder)
            ILOG("BIOS \(filename) is already in a BIOS directory: \(originalURL.path). Checking if it needs linking.")
            // File is already in a BIOS directory. We just need to ensure it's known to BIOSWatcher for linking.
            // The PVBIOS entries matched earlier are the candidates.
            // BIOSWatcher.checkBIOSFile (which is called by GameImporter before queuing)
            // should handle linking for files correctly placed but not yet in DB.
            // However, a direct notification here can also ensure it's processed if checkBIOSFile missed it or for robustness.
            var notifiedForThisPath = false
            for biosEntry in potentialBiosMatches {
                 // Only notify if the current file URL could satisfy this biosEntry for its system.
                 // This is a bit redundant if checkBIOSFile is perfect, but safe.
                 if let system = biosEntry.system {
                    let expectedFilenameForSystem = biosEntry.expectedFilename.components(separatedBy: "|").first ?? filename
                    let systemBiosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
                    let expectedDestinationURL = systemBiosPath.appendingPathComponent(expectedFilenameForSystem)
                    
                    // If the originalURL is indeed the expected final resting place for this BIOS entry for this system
                    if originalURL.standardizedFileURL == expectedDestinationURL.standardizedFileURL {
                        if !notifiedForThisPath { // Post notification only once for the given originalURL
                            ILOG("Notifying BIOSFileFound for already placed BIOS: \(originalURL.path) for potential linking with \(biosEntry.expectedFilename).")
                            NotificationCenter.default.post(name: .BIOSFileFound, object: originalURL)
                            successfulNewURLs.append(originalURL) // It's a 'new' URL in terms of DB state
                            notifiedForThisPath = true
                        }
                        successfullyProcessed = true
                    }
                 }
            }
            if !successfullyProcessed {
                 ILOG("BIOS \(filename) at \(originalURL.path) did not match an expected system path for any defined BIOS. No specific linking action taken here.")
            }
        } else {
            WLOG("BIOS file \(filename) at \(originalURL.path) did not fall into expected categories. isFromImportsFolder: \(isFromImportsFolder), isInBiosDir: \(isInBiosDir). No action taken.")
            // This case should ideally not happen if type is .bios and it's not in Imports.
            // Could throw an error if strictness is required.
            // throw GameImporterError.invalidBIOSLocation(path: originalURL.path)
        }

        if !successfulNewURLs.isEmpty {
            queueItem.destinationUrl = successfulNewURLs.first // Set for logging or legacy use
            // queueItem.status should be set to .success by the caller if successfullyProcessed is true
        } else if !isFromImportsFolder && !originalURL.path.contains(Paths.biosesPath.path) {
             // If it wasn't from imports and not in a BIOS path, but was type .bios, it's an issue.
        }
        
        // The caller (GameImporterDatabaseService) will set the final item status.
        // This function primarily handles file operations and notifications.
        // If successfullyProcessed is true, it implies the operation specific to this function was done.
        if !successfullyProcessed {
            // If determined .bios but no PVBIOS entry matches or no valid system, what to do?
            // This could be a new/unexpected BIOS file. For now, let's assume this means it can't be handled as a defined BIOS.
            // If we want to be strict, and it was type .bios, throw an error.
            // throw GameImporterError.biosProcessingFailed(filename: filename)
            ILOG("BIOS file \(filename) could not be successfully processed according to PVBIOS definitions or placed correctly.")
        }
    }
    
    //MARK: - Normal ROMs and CDROMs
    
    /// Moves an ImportQueueItem to the appropriate subfolder
    //    @MainActor
    internal func processQueueItem(_ queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType == .game || queueItem.fileType == .cdRom else {
            throw GameImporterError.unsupportedFile
        }
        
        //this might not be needed...
        guard await !queueItem.systems.isEmpty else {
            throw GameImporterError.noSystemMatched
        }
        
        guard let targetSystem = await queueItem.targetSystem() else {
            throw GameImporterError.systemNotDetermined
        }
        
        let destinationFolder = targetSystem.romsDirectory
        
        // Check if the file is already in the correct system directory
        let currentDirectory = queueItem.url.deletingLastPathComponent()
        let fileName = queueItem.url.lastPathComponent
        let expectedPath = destinationFolder.appendingPathComponent(fileName)
        
        // If the file is already in the correct location, just set the destination URL and return
        if currentDirectory.path == destinationFolder.path {
            ILOG("ROM file \(fileName) is already in the correct location for system \(targetSystem.rawValue), skipping move")
            queueItem.destinationUrl = queueItem.url
            
            // Check if there are child items that need to be processed
            if !queueItem.childQueueItems.isEmpty {
                try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
            }
            return
        }
        
        // If the file already exists at the destination, handle it specially
        if FileManager.default.fileExists(atPath: expectedPath.path) {
            ILOG("ROM file \(fileName) already exists at destination, skipping move and using existing file")
            queueItem.destinationUrl = expectedPath
            
            // If the file is in the imports directory, delete it to avoid duplicates
            if queueItem.url.path.contains("/Imports/") {
                try await FileManager.default.removeItem(at: queueItem.url)
                ILOG("Deleted duplicate file from imports directory: \(queueItem.url.path)")
            }
            
            // Process child items if needed
            if !queueItem.childQueueItems.isEmpty {
                try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
            }
            return
        }
        
        // If we get here, we need to move the file
        do {
            queueItem.destinationUrl = try await moveFile(queueItem.url, to: destinationFolder)
            try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
        } catch {
            throw GameImporterError.failedToMoveROM(error)
        }
    }
    
    // MARK: - Utility
    
    internal func moveChildImports(forQueueItem queueItem: ImportQueueItem, to destinationFolder: URL) async throws {
        guard !queueItem.childQueueItems.isEmpty else {
            return
        }
        
        for childQueueItem in queueItem.childQueueItems {
            let fileName = childQueueItem.url.lastPathComponent
            
            do {
                childQueueItem.destinationUrl = try await moveFile(childQueueItem.url, to: destinationFolder)
                //call recursively to keep moving child items to the target directory as a unit
                try await moveChildImports(forQueueItem: childQueueItem, to: destinationFolder)
            } catch {
                throw GameImporterError.failedToMoveCDROM(error)
            }
        }
    }
    
    
    /// Moves a file to the conflicts directory
    internal func moveToConflictsFolder(_ queueItem: ImportQueueItem, conflictsPath: URL) async throws {
        let destination = conflictsPath.appendingPathComponent(queueItem.url.lastPathComponent)
        DLOG("Moving \(queueItem.url.lastPathComponent) to conflicts folder")
        //when moving the conflicts folder, we actually want to update the import item's source url to match
        queueItem.url = try moveAndOverWrite(sourcePath: queueItem.url, destinationPath: destination)
        for childQueueItem in queueItem.childQueueItems {
            try await moveToConflictsFolder(childQueueItem, conflictsPath: conflictsPath)
        }
    }
    
    /// Move a `URL` to a destination, creating the destination directory if needed
    private func moveFile(_ file: URL, to destinationDirectory: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let destPath = destinationDirectory.appendingPathComponent(file.lastPathComponent)
        
        if file.standardizedFileURL == destPath.standardizedFileURL {
            // We don't need to move the file, probably a re-import
            return destPath
        } else {
            try FileManager.default.moveItem(at: file, to: destPath)
            DLOG("Moved file to: \(destPath.path)")
            return destPath
        }
    }
    
    /// Move a `URL` to a destination, creating the destination directory if needed
    private func moveFile(_ file: URL, toExplicitDestination destination: URL) async throws -> URL {
        let destinationDirectory = destination.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        // Create destination directory if it doesn't exist
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        
        do {
            // Try to move the file
            try fileManager.moveItem(at: file, to: destination)
            DLOG("Moved file to: \(destination.path)")
            return destination
        } catch {
            // Check if the error is because a file with the same name already exists
            if fileManager.fileExists(atPath: destination.path) {
                WLOG("File already exists at destination: \(destination.path). Deleting source file.")
                
                // If the file is in the imports directory, delete it
                if file.path.contains("/Imports/") {
                    try await fileManager.removeItem(at: file)
                    ILOG("Deleted duplicate file from imports directory: \(file.path)")
                }
                
                // Return the destination since the file already exists there
                return destination
            } else {
                // If it's a different error, rethrow it
                throw error
            }
        }
    }
    
    func removeImportItemFile(_ importItem: ImportQueueItem) throws {
        let fileManager = FileManager.default
        
        // If file exists at destination, remove it first
        if fileManager.fileExists(atPath: importItem.url.path) {
            try fileManager.removeItem(at: importItem.url)
        }
        
        //recursively call this on any children
        for item in importItem.childQueueItems {
            try removeImportItemFile(item)
        }
    }
    
    /// Moves a file and overwrites if it already exists at the destination
    public func moveAndOverWrite(sourcePath: URL, destinationPath: URL) throws -> URL  {
        let fileManager = FileManager.default
        
        // If file exists at destination, remove it first
        if fileManager.fileExists(atPath: destinationPath.path) {
            try fileManager.removeItem(at: destinationPath)
        }
        
        // Now move the file
        try fileManager.moveItem(at: sourcePath, to: destinationPath)
        return destinationPath
    }
}
