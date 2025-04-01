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
        case .artwork:
            //TODO: implement me
            return
        case .game,.cdRom:
            _ = try await processQueueItem(queueItem)
        case .unknown:
            throw GameImporterError.unsupportedFile
        }
    }

    // MARK: - BIOS

    /// Ensures a BIOS file is copied to appropriate file destinations
    ///  Returns the array of PVSystems that this BIOS file applies to
    private func handleBIOSItem(_ queueItem: ImportQueueItem) async throws {
        let filename = queueItem.url.lastPathComponent.lowercased()
        ILOG("Handling BIOS file: \(filename)")

        // Get all BIOS entries
        let biosEntries = PVEmulatorConfiguration.biosEntries
        var successfullyProcessedAny = false

        // First try to match by filename
        let filenameMatches = biosEntries.filter { bios in
            // Split expected filename by | to handle path specifications
            let expectedParts = bios.expectedFilename.components(separatedBy: "|")
            let expectedFilename = expectedParts[0].lowercased()
            return expectedFilename == filename
        }

        if !filenameMatches.isEmpty {
            ILOG("Found \(filenameMatches.count) BIOS matches by filename")

            // Filter to only process BIOS entries that don't have a file
            let missingBIOSMatches = filenameMatches.filter { $0.file == nil }
            ILOG("Of which \(missingBIOSMatches.count) are missing their BIOS file")

            for bios in missingBIOSMatches {
                if let system = bios.system {
                    ILOG("Processing BIOS for system: \(system.name)")
                    let biosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)

                    // Use the exact case from the expected filename
                    let expectedParts = bios.expectedFilename.components(separatedBy: "|")
                    let destinationPath = biosPath.appendingPathComponent(expectedParts[0])

                    ILOG("Moving BIOS file to: \(destinationPath.path)")

                    // Ensure the directory exists
                    try FileManager.default.createDirectory(at: biosPath, withIntermediateDirectories: true)

                    do {
                        // For multiple matches, we need to copy instead of move for all but the last one
                        if bios == missingBIOSMatches.last {
                            queueItem.destinationUrl = try await moveFile(queueItem.url, toExplicitDestination: destinationPath)
                        } else {
                            try FileManager.default.copyItem(at: queueItem.url, to: destinationPath)
                            // For copies, set the destination to the last copy we'll make
                            queueItem.destinationUrl = destinationPath
                        }
                        ILOG("Successfully copied/moved BIOS file to: \(destinationPath.path)")
                        successfullyProcessedAny = true
                    } catch {
                        ELOG("Failed to copy/move BIOS file to \(destinationPath.path): \(error)")
                        // Continue trying other matches even if one fails
                        continue
                    }
                } else {
                    ELOG("BIOS entry has no associated system")
                }
            }

            if successfullyProcessedAny {
                return
            }
        }

        // If no filename match or no missing files to process, try MD5
        if let md5 = queueItem.md5?.uppercased() {
            ILOG("Checking MD5: \(md5)")
            let md5Matches = biosEntries.filter("expectedMD5 == %@", md5).map({ $0 })

            if !md5Matches.isEmpty {
                ILOG("Found \(md5Matches.count) matching BIOS entries by MD5")

                // Filter to only process BIOS entries that don't have a file
                let missingMD5Matches = md5Matches.filter { $0.file == nil }
                ILOG("Of which \(missingMD5Matches.count) are missing their BIOS file")

                for bios in missingMD5Matches {
                    if let system = bios.system {
                        ILOG("Processing BIOS for system: \(system.name)")
                        let biosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
                        let destinationPath = biosPath.appendingPathComponent(bios.expectedFilename)

                        ILOG("Moving BIOS file to: \(destinationPath.path)")

                        // Ensure the directory exists
                        try FileManager.default.createDirectory(at: biosPath, withIntermediateDirectories: true)

                        do {
                            // For multiple matches, we need to copy instead of move for all but the last one
                            if bios == missingMD5Matches.last {
                                queueItem.destinationUrl = try await moveFile(queueItem.url, toExplicitDestination: destinationPath)
                            } else {
                                try FileManager.default.copyItem(at: queueItem.url, to: destinationPath)
                                // For copies, set the destination to the last copy we'll make
                                queueItem.destinationUrl = destinationPath
                            }
                            ILOG("Successfully copied/moved BIOS file to: \(destinationPath.path)")
                            successfullyProcessedAny = true
                        } catch {
                            ELOG("Failed to copy/move BIOS file to \(destinationPath.path): \(error)")
                            // Continue trying other matches even if one fails
                            continue
                        }
                    } else {
                        ELOG("BIOS entry has no associated system")
                    }
                }

                if successfullyProcessedAny {
                    return
                }
            }
        }

        ELOG("No BIOS matches found by filename or MD5, or all matching BIOS entries already have files")
        throw GameImporterError.noBIOSMatchForBIOSFileType
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
