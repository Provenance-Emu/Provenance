//
//  File.swift
//  PVLibrary
//
//  Created by David Proskin on 11/5/24.
//

import Foundation
import PVSupport
import RealmSwift

protocol GameImporterFileServicing {
    func moveImportItem(toAppropriateSubfolder queueItem: ImportQueueItem) async throws
    func moveToConflictsFolder(_ queueItem: ImportQueueItem, conflictsPath: URL) async throws
}

class GameImporterFileService : GameImporterFileServicing {
    
    init() {
        
    }
    
    package func moveImportItem(toAppropriateSubfolder queueItem: ImportQueueItem) async throws {
        switch (queueItem.fileType) {
            
        case .bios:
            _ = try await handleBIOSItem(queueItem)
        case .artwork:
            //TODO: implement me
            return
        case .game:
            _ = try await handleROM(queueItem)
            return
        case .cdRom:
            _ = try await handleCDROMItem(queueItem)
        case .unknown:
            throw GameImporterError.unsupportedFile
        }
    }
    
    // MARK: - BIOS
    
    /// Ensures a BIOS file is copied to appropriate file destinations
    ///  Returns the array of PVSystems that this BIOS file applies to
    private func handleBIOSItem(_ queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType == .bios, let md5 = queueItem.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }
        
        let biosMatches = PVEmulatorConfiguration.biosEntries.filter("expectedMD5 == %@", md5).map({ $0 })
        
        guard !biosMatches.isEmpty else {
            //we shouldn't be here.
            throw GameImporterError.noBIOSMatchForBIOSFileType
        }
        
        for bios in biosMatches {
            if let system = bios.system {
                DLOG("Copying BIOS to system: \(system.name)")
                let biosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
                    .appendingPathComponent(bios.expectedFilename)
               
                queueItem.destinationUrl = try await moveFile(queueItem.url, to: biosPath)
            }
        }
    }
    //MARK: - Normal ROMs
    
    /// Moves a ROM to the appropriate subfolder
    internal func handleROM(_ queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType == .game else {
            throw GameImporterError.unsupportedFile
        }
        
        guard !queueItem.systems.isEmpty else {
            throw GameImporterError.noSystemMatched
        }
        
        let candidateSystems = queueItem.systems
        if (candidateSystems.count > 1 && queueItem.userChosenSystem == nil) {
            //conflict?
            throw GameImporterError.systemNotDetermined
        }
        
        let fileManager = FileManager.default
        let fileName = queueItem.url.lastPathComponent
        
        if let system = candidateSystems.first {
            let destinationFolder = system.romsDirectory
            let destinationPath = destinationFolder.appendingPathComponent(fileName)
            queueItem.destinationUrl = try await moveFile(queueItem.url, to: destinationPath)
        }
    }
    
    // MARK: - CDROM
    
    /// Ensures a BIOS file is copied to appropriate file destinations
    ///  Returns the array of PVSystems that this BIOS file applies to
    private func handleCDROMItem(_ queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType == .cdRom else {
            throw GameImporterError.unsupportedCDROMFile
        }
        
        guard !queueItem.systems.isEmpty else {
            throw GameImporterError.unsupportedCDROMFile
        }
        
        let candidateSystems = queueItem.systems
        if (candidateSystems.count > 1 && queueItem.userChosenSystem == nil) {
            //conflict?
            throw GameImporterError.systemNotDetermined
        }
        
        let fileManager = FileManager.default
        let fileName = queueItem.url.lastPathComponent
        
        if let system = candidateSystems.first {
            let destinationFolder = system.romsDirectory
            let destinationPath = destinationFolder.appendingPathComponent(fileName)
            
            // Check for M3U
            //TODO: implement handling for M3U and cue files
            #if false
            if let system = try await handleM3UFile(candidate) {
                DLOG("Moving M3U and referenced files to system: \(system.name)")
                // Move M3U and all referenced files to system directory
                let destinationDir = system.romsDirectory
                return try await moveM3UAndReferencedFiles(candidate, to: destinationDir)
            }
            
            // If cue file, try to match its bin file
            if `extension` == "cue" {
                if let binFile = try findAssociatedBinFile(for: candidate) {
                    DLOG("Found associated bin file, trying to match: \(binFile.lastPathComponent)")
                    let binCandidate = ImportCandidateFile(filePath: binFile)
                    if let system = try? await determineSystem(for: binCandidate) {
                        DLOG("Found system match from associated bin file: \(system.name)")
                        return system
                    }
                }
            }
            #endif
            
            do {
                queueItem.destinationUrl = try await moveFile(queueItem.url, to: destinationPath)
            } catch {
                throw GameImporterError.failedToMoveCDROM(error)
            }
        }
    }
    
    private func findAssociatedBinFile(for cueFileItem: ImportQueueItem) throws -> URL? {
        let cueContents = try String(contentsOf: cueFileItem.url, encoding: .utf8)
        let lines = cueContents.components(separatedBy: .newlines)
        
        // Look for FILE "something.bin" BINARY line
        for line in lines {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: "\"")
            guard components.count >= 2,
                  line.lowercased().contains("file") && line.lowercased().contains("binary") else {
                continue
            }
            
            let binFileName = components[1]
            let binPath = cueFileItem.url.deletingLastPathComponent().appendingPathComponent(binFileName)
            
            if FileManager.default.fileExists(atPath: binPath.path) {
                return binPath
            }
        }
        
        return nil
    }
    
    // MARK: - Utility
    
   
    /// Moves a file to the conflicts directory
    internal func moveToConflictsFolder(_ queueItem: ImportQueueItem, conflictsPath: URL) async throws {
        let destination = conflictsPath.appendingPathComponent(queueItem.url.lastPathComponent)
        queueItem.destinationUrl = try moveAndOverWrite(sourcePath: queueItem.url, destinationPath: destination)
    }
    
    /// Move a `URL` to a destination, creating the destination directory if needed
    private func moveFile(_ file: URL, to destination: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let destPath = destination.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.moveItem(at: file, to: destPath)
        DLOG("Moved file to: \(destPath.path)")
        return destPath
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
