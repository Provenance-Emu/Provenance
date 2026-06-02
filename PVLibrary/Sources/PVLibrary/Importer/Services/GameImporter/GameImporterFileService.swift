//
//  GameImporterFileService.swift
//  PVLibrary
//
//  Created by David Proskin on 11/5/24.
//

import Foundation
import PVFileSystem
import PVSupport
import RealmSwift
import PVPrimitives
import PVHashing  // calculateMD5Async for same-name/different-content collision check

protocol GameImporterFileServicing {
    func moveImportItem(toAppropriateSubfolder queueItem: ImportQueueItem) async throws
    func moveToConflictsFolder(_ queueItem: ImportQueueItem, conflictsPath: URL) async throws
    func removeImportItemFile(_ importItem: ImportQueueItem) throws
}

class GameImporterFileService : GameImporterFileServicing {

    private let cdFileHandler: CDFileHandling

    init() {
        self.cdFileHandler = DefaultCDFileHandler()
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
        case .game, .cdRom, .zip, .folder:
            _ = try await processQueueItem(queueItem)
        case .patch:
            // Move the patch file to the dedicated patches directory and record the destination.
            // processQueueItem is intentionally NOT called here — it requires .game/.cdRom types
            // and handles ROM-specific logic (system matching, ROM directory placement).
            // The Realm PVPatch record is created by GameImporter.importPatchFile, which is
            // called by performImport immediately after this method returns.
            let patchesDir = Paths.patchesPath
            try FileManager.default.createDirectory(at: patchesDir, withIntermediateDirectories: true, attributes: nil)
            let srcURL = queueItem.url
            let baseName = srcURL.deletingPathExtension().lastPathComponent
            let ext = srcURL.pathExtension
            var destURL = patchesDir.appendingPathComponent(srcURL.lastPathComponent)
            // If a file with the same name already exists, check whether it's the same file
            // before generating a unique name. Same size + mtime → treat as re-import (idempotent).
            if FileManager.default.fileExists(atPath: destURL.path) {
                let srcAttrs = try? FileManager.default.attributesOfItem(atPath: srcURL.path)
                let dstAttrs = try? FileManager.default.attributesOfItem(atPath: destURL.path)
                let srcSize = (srcAttrs?[.size] as? NSNumber)?.uint64Value
                let dstSize = (dstAttrs?[.size] as? NSNumber)?.uint64Value
                let srcMtime = srcAttrs?[.modificationDate] as? Date
                let dstMtime = dstAttrs?[.modificationDate] as? Date
                if let srcSize = srcSize,
                   let dstSize = dstSize,
                   let srcMtime = srcMtime,
                   let dstMtime = dstMtime,
                   srcSize == dstSize,
                   srcMtime == dstMtime {
                    // Same size and modification date → likely the same patch; use existing file (idempotent re-import).
                    ILOG("Patch file already exists at destination with same size and mtime — using existing: \(destURL.path)")
                    queueItem.destinationUrl = destURL
                    // Clean up source from Imports folder to avoid duplicate watching.
                    let importsURL = Paths.romsImportPath.standardizedFileURL
                    let sourceURL = srcURL.standardizedFileURL
                    let importsComponents = importsURL.pathComponents
                    let sourceComponents = sourceURL.pathComponents
                    if sourceComponents.starts(with: importsComponents) {
                        try? await FileManager.default.removeItem(at: srcURL)
                    }
                    return
                } else {
                    // Different content — generate a unique filename to avoid overwriting.
                    let suffix = UUID().uuidString.prefix(8)
                    let uniqueName = ext.isEmpty ? "\(baseName)-\(suffix)" : "\(baseName)-\(suffix).\(ext)"
                    destURL = patchesDir.appendingPathComponent(uniqueName)
                }
            }
            try FileManager.default.moveItem(at: srcURL, to: destURL)
            queueItem.destinationUrl = destURL
            ILOG("Moved patch file to: \(destURL.path)")
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
        guard queueItem.fileType == .game || queueItem.fileType == .cdRom || queueItem.fileType == .folder else {
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

        // If the file is already in the correct location, clean CUE files and return
        if currentDirectory.path == destinationFolder.path {
            ILOG("ROM file \(fileName) is already in the correct location for system \(targetSystem.rawValue), skipping move")

            // Clean CUE files even if already in correct location
            if queueItem.url.pathExtension.lowercased() == "cue" {
                do {
                    try cdFileHandler.cleanCueFile(at: queueItem.url)
                } catch {
                    WLOG("Failed to clean CUE file \(fileName): \(error.localizedDescription)")
                }
            }

            queueItem.destinationUrl = queueItem.url

            // Check if there are child items that need to be processed
            if !queueItem.childQueueItems.isEmpty {
                try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
            }
            // Move any associated files (e.g. bin/cue for m3u) that may still be in Imports
            if !queueItem.resolvedAssociatedFileURLs.isEmpty {
                try await moveAssociatedFiles(forQueueItem: queueItem, to: destinationFolder)
            }
            return
        }

        // A file already exists at the destination path. Only treat it as a duplicate
        // (and delete the incoming source below) when the CONTENT is byte-identical.
        // A same-name / different-content file is a DIFFERENT ROM — deleting the source
        // there silently loses the user's new file (data-loss blocker). In that case,
        // import the new file under a unique deduped name instead.
        if FileManager.default.fileExists(atPath: expectedPath.path),
           await !Self.filesAreByteIdentical(queueItem.url, expectedPath) {
            let uniqueDest = Self.uniqueDestination(for: expectedPath)
            WLOG("ROM name collision with DIFFERENT content for \(fileName); importing as \(uniqueDest.lastPathComponent) to avoid data loss")
            do {
                queueItem.destinationUrl = try await moveFile(queueItem.url, toExplicitDestination: uniqueDest)
                if !queueItem.childQueueItems.isEmpty {
                    try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
                }
                if !queueItem.resolvedAssociatedFileURLs.isEmpty {
                    try await moveAssociatedFiles(forQueueItem: queueItem, to: destinationFolder)
                }
                return
            } catch {
                throw GameImporterError.failedToMoveROM(error)
            }
        }

        // If the file already exists at the destination, handle it specially
        if FileManager.default.fileExists(atPath: expectedPath.path) {
            ILOG("ROM file \(fileName) already exists at destination, skipping move and using existing file")

            // Clean CUE file at destination if it exists
            if expectedPath.pathExtension.lowercased() == "cue" {
                do {
                    try cdFileHandler.cleanCueFile(at: expectedPath)
                } catch {
                    WLOG("Failed to clean existing CUE file \(fileName): \(error.localizedDescription)")
                }
            }

            queueItem.destinationUrl = expectedPath

            // If the file is in the imports directory, delete it to avoid duplicates
            if queueItem.url.path.contains("/Imports/") {
                // Check if file still exists before trying to delete
                // It may have already been deleted by DirectoryWatcher or another process
                if FileManager.default.fileExists(atPath: queueItem.url.path) {
                    do {
                        // Add a small delay to ensure DirectoryWatcher has stopped watching
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        try await FileManager.default.removeItem(at: queueItem.url)
                        ILOG("Deleted duplicate file from imports directory: \(queueItem.url.path)")
                    } catch {
                        // If deletion fails, check if file still exists
                        // If it doesn't exist, that's fine - it was already deleted
                        if FileManager.default.fileExists(atPath: queueItem.url.path) {
                            WLOG("Failed to delete file from imports directory (may be locked by DirectoryWatcher): \(queueItem.url.path). Error: \(error.localizedDescription)")
                            // Don't throw - the import was successful, file just couldn't be cleaned up
                        } else {
                            ILOG("File already deleted from imports directory: \(queueItem.url.path)")
                        }
                    }
                } else {
                    ILOG("File no longer exists in imports directory (already deleted): \(queueItem.url.path)")
                }
            }

            // Process child items if needed
            if !queueItem.childQueueItems.isEmpty {
                try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
            }
            // Move any associated files (e.g. bin/cue for m3u) that may still be in Imports
            if !queueItem.resolvedAssociatedFileURLs.isEmpty {
                try await moveAssociatedFiles(forQueueItem: queueItem, to: destinationFolder)
            }
            return
        }

        // Clean CUE files before moving to fix encoding and formatting issues
        if queueItem.url.pathExtension.lowercased() == "cue" {
            do {
                try cdFileHandler.cleanCueFile(at: queueItem.url)
            } catch {
                WLOG("Failed to clean CUE file \(fileName): \(error.localizedDescription). Continuing with import.")
                // Don't throw - cleaning is best-effort, continue with import
            }
        }

        // If we get here, we need to move the file
        do {
            queueItem.destinationUrl = try await moveFile(queueItem.url, to: destinationFolder)

            // Clean CUE file again after moving (in case it was already in destination)
            if let destinationUrl = queueItem.destinationUrl,
               destinationUrl.pathExtension.lowercased() == "cue" {
                do {
                    try cdFileHandler.cleanCueFile(at: destinationUrl)
                } catch {
                    WLOG("Failed to clean CUE file after move \(fileName): \(error.localizedDescription)")
                }
            }

            try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
            // Move associated files (e.g. bin/cue files referenced by an m3u) to the same system dir
            try await moveAssociatedFiles(forQueueItem: queueItem, to: destinationFolder)
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

    /// Moves resolved associated files (e.g. .bin/.cue files for an .m3u) to the destination folder
    /// and updates their URLs in the queue item. This ensures disc image files accompany the primary
    /// file (e.g. m3u) in the system ROM directory and can be referenced correctly during playback.
    internal func moveAssociatedFiles(forQueueItem queueItem: ImportQueueItem, to destinationFolder: URL) async throws {
        guard !queueItem.resolvedAssociatedFileURLs.isEmpty else { return }

        var updatedURLs: [URL] = []
        for fileURL in queueItem.resolvedAssociatedFileURLs {
            // If the file no longer exists at the source (already moved), point to destination
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                let expectedDestination = destinationFolder.appendingPathComponent(fileURL.lastPathComponent)
                updatedURLs.append(expectedDestination)
                ILOG("Associated file already moved or missing: \(fileURL.lastPathComponent)")
                continue
            }
            do {
                let movedURL = try await moveFile(fileURL, to: destinationFolder)
                updatedURLs.append(movedURL)
                ILOG("Moved associated file \(fileURL.lastPathComponent) to system dir")
            } catch {
                ELOG("Failed to move associated file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                updatedURLs.append(fileURL) // keep original URL so callers can still reference it
            }
        }
        queueItem.resolvedAssociatedFileURLs = updatedURLs
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

    /// Returns `true` only when both files are byte-identical (same size AND same raw MD5).
    /// Conservative: returns `false` on any read failure so an inconclusive comparison never
    /// authorizes deleting the user's incoming source file. Raw MD5 (offset 0) — exact file
    /// identity, NOT ROM-identity (header-skipping), since we are deciding whether deleting
    /// the source is safe.
    private static func filesAreByteIdentical(_ a: URL, _ b: URL) async -> Bool {
        let fm = FileManager.default
        guard let sizeA = (try? fm.attributesOfItem(atPath: a.path)[.size]) as? NSNumber,
              let sizeB = (try? fm.attributesOfItem(atPath: b.path)[.size]) as? NSNumber,
              sizeA == sizeB else {
            return false
        }
        guard let md5A = try? await calculateMD5Async(of: a),
              let md5B = try? await calculateMD5Async(of: b) else {
            return false
        }
        return md5A == md5B
    }

    /// Returns a non-colliding destination URL by appending `_1`, `_2`, … before the
    /// extension until a free path is found in the same directory.
    private static func uniqueDestination(for url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        var n = 1
        while true {
            let name = ext.isEmpty ? "\(stem)_\(n)" : "\(stem)_\(n).\(ext)"
            let candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
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
