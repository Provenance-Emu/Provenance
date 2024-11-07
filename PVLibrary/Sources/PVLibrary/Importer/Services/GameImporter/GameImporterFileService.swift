//
//  GameImporterFileService.swift
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
               
                queueItem.destinationUrl = try await moveFile(queueItem.url, to: biosPath)
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
        
        let fileName = queueItem.url.lastPathComponent
        let destinationFolder = targetSystem.romsDirectory
        let destinationPath = destinationFolder.appendingPathComponent(fileName)
        
        do {
            queueItem.destinationUrl = try await moveFile(queueItem.url, to: destinationPath)
            try await moveChildImports(forQueueItem: queueItem, to: destinationFolder)
        } catch {
            throw GameImporterError.failedToMoveROM(error)
        }
    }
    
    // MARK: - Utility
    
    internal func moveChildImports(forQueueItem queueItem:ImportQueueItem, to destinationFolder:URL) async throws {
        guard !queueItem.childQueueItems.isEmpty else {
            return
        }
        
        for childQueueItem in queueItem.childQueueItems {
            let fileName = childQueueItem.url.lastPathComponent
            let destinationPath = destinationFolder.appendingPathComponent(fileName)
                    
            do {
                childQueueItem.destinationUrl = try await moveFile(childQueueItem.url, to: destinationPath)
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
