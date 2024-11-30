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
               
                queueItem.destinationUrl = try await moveFile(queueItem.url, toExplicitDestination: biosPath)
            }
        }
    }
    //MARK: - Normal ROMs and CDROMs
    
    /// Moves an ImportQueueItem to the appropriate subfolder
    internal func processQueueItem(_ queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType == .game || queueItem.fileType == .cdRom else {
            throw GameImporterError.unsupportedFile
        }
        
        //this might not be needed...
        guard !queueItem.systems.isEmpty else {
            throw GameImporterError.noSystemMatched
        }
        
        guard let targetSystem = queueItem.targetSystem() else {
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
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: destination)
        DLOG("Moved file to: \(destination.path)")
        return destination
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
