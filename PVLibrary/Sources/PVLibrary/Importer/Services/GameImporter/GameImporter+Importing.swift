//
//  GameImporter+Importing.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import Foundation
import PVSupport
import RealmSwift
import PVCoreLoader
import AsyncAlgorithms
import PVPlists
import PVLookup
import Systems
import PVMediaCache
import PVFileSystem
import PVLogging
import PVPrimitives
import PVRealm
import Perception
import SwiftUI

extension GameImporter {
    /// Imports files from given paths
    /// //goal is to make this private
//    public func importFiles(atPaths paths: [URL]) async throws -> [URL] {
//        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
//        var importedFiles: [URL] = []
//        
//        for path in sortedPaths {
//            do {
//                if let importedFile = try await importSingleFile(at: path) {
//                    importedFiles.append(importedFile)
//                }
//            } catch {
//                ELOG("Failed to import file at \(path.path): \(error.localizedDescription)")
//            }
//        }
//        
//        return importedFiles
//    }
    
//    /// Imports a single file from the given path
//    internal func importSingleFile(at path: URL) async throws -> URL? {
//        guard FileManager.default.fileExists(atPath: path.path) else {
//            WLOG("File doesn't exist at \(path.path)")
//            return nil
//        }
//        
//        if isCDROM(path) {
//            return try await handleCDROM(at: path)
//        } else if isArtwork(path) {
//            return try await handleArtwork(at: path)
//        } else {
//            return try await handleROM(at: path)
//        }
//    }
    
//    /// Handles importing a CD-ROM
//    internal func handleCDROM(at path: URL) async throws -> URL? {
//        let movedToPaths = try await moveCDROM(toAppropriateSubfolder: ImportCandidateFile(filePath: path))
//        if let movedToPaths = movedToPaths {
//            let pathsString = movedToPaths.map { $0.path }.joined(separator: ", ")
//            VLOG("Found a CD. Moved files to the following paths \(pathsString)")
//        }
//        return nil
//    }
    
//    /// Handles importing artwork
//    internal func handleArtwork(at path: URL) async throws -> URL? {
//        if let game = await GameImporter.importArtwork(fromPath: path) {
//            ILOG("Found artwork \(path.lastPathComponent) for game <\(game.title)>")
//        }
//        return nil
//    }
    
//    /// Handles importing a ROM
//    internal func handleROM(at path: URL) async throws -> URL? {
//        let candidate = ImportCandidateFile(filePath: path)
//        return try await moveROM(toAppropriateSubfolder: candidate)
//    }
    
//    /// Starts an import for the given paths
//    internal func startImport(forPaths paths: [URL]) async {
//        // Pre-sort
//        let paths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
//        let scanOperation = BlockOperation {
//            Task {
//                do {
//                    let newPaths = try await self.importFiles(atPaths: paths)
//                    await self.getRomInfoForFiles(atPaths: newPaths, userChosenSystem: nil)
//                } catch {
//                    ELOG("\(error)")
//                }
//            }
//        }
//        
//        let completionOperation = BlockOperation {
//            if self.completionHandler != nil {
//                DispatchQueue.main.sync(execute: { () -> Void in
//                    self.completionHandler?(self.encounteredConflicts)
//                })
//            }
//        }
//        
//        completionOperation.addDependency(scanOperation)
//        serialImportQueue.addOperation(scanOperation)
//        serialImportQueue.addOperation(completionOperation)
//    }
//    
//    /// Handles the import of a path
//    internal func _handlePath(path: URL, userChosenSystem chosenSystem: System?) async throws {
//        // Skip hidden files and directories
//        if path.lastPathComponent.hasPrefix(".") {
//            VLOG("Skipping hidden file or directory: \(path.lastPathComponent)")
//            return
//        }
//        
//        let isDirectory = path.hasDirectoryPath
//        let filename = path.lastPathComponent
//        let fileExtensionLower = path.pathExtension.lowercased()
//        
//        // Handle directories
//        //TODO: strangle this back to the importer queue somehow...
//        if isDirectory {
//            try await handleDirectory(path: path, chosenSystem: chosenSystem)
//            return
//        }
//        
//        // Handle files
//        let systems = try determineSystems(for: path, chosenSystem: chosenSystem)
//        
//        // Handle conflicts
//        if systems.count > 1 {
//            try await handleSystemConflict(path: path, systems: systems)
//            return
//        }
//        
//        //this is the case where there was no matching system - should this even happne?
//        guard let system = systems.first else {
//            ELOG("No system matched extension {\(fileExtensionLower)}")
//            try moveToConflictsDirectory(path: path)
//            return
//        }
//        
//        try importGame(path: path, system: system)
//    }
    
//    /// Handles a directory
//    /// //TODO: strangle this back to the importer queue
//    internal func handleDirectory(path: URL, chosenSystem: System?) async throws {
//        guard chosenSystem == nil else { return }
//        
//        do {
//            let subContents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
//            if subContents.isEmpty {
//                try await FileManager.default.removeItem(at: path)
//                ILOG("Deleted empty import folder \(path.path)")
//            } else {
//                ILOG("Found non-empty folder in imports dir. Will iterate subcontents for import")
//                for subFile in subContents {
//                    try await self._handlePath(path: subFile, userChosenSystem: nil)
//                }
//            }
//        } catch {
//            ELOG("Error handling directory: \(error)")
//            throw error
//        }
//    }
    
//    internal func handleM3UFile(_ candidate: ImportCandidateFile) async throws -> PVSystem? {
//        guard candidate.filePath.pathExtension.lowercased() == "m3u" else {
//            return nil
//        }
//        
//        DLOG("Handling M3U file: \(candidate.filePath.lastPathComponent)")
//        
//        // First try to match the M3U file itself by MD5
//        if let system = try? await determineSystem(for: candidate) {
//            DLOG("Found system match for M3U by MD5: \(system.name)")
//            return system
//        }
//        
//        // Read M3U contents
//        let contents = try String(contentsOf: candidate.filePath, encoding: .utf8)
//        let files = contents.components(separatedBy: .newlines)
//            .map { $0.trimmingCharacters(in: .whitespaces) }
//            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
//        
//        DLOG("Found \(files.count) entries in M3U")
//        
//        // Try to match first valid file in M3U
//        for file in files {
//            let filePath = candidate.filePath.deletingLastPathComponent().appendingPathComponent(file)
//            guard FileManager.default.fileExists(atPath: filePath.path) else { continue }
//            
//            let candidateFile = ImportCandidateFile(filePath: filePath)
//            if let system = try? await determineSystem(for: candidateFile) {
//                DLOG("Found system match from M3U entry: \(file) -> \(system.name)")
//                return system
//            }
//        }
//        
//        DLOG("No system match found for M3U or its contents")
//        return nil
//    }
    
//    internal func handleRegularROM(_ candidate: ImportCandidateFile) async throws -> (PVSystem, Bool) {
//        DLOG("Handling regular ROM file: \(candidate.filePath.lastPathComponent)")
//        
//        // 1. Try MD5 match first
//        if let md5 = candidate.md5?.uppercased() {
//            if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: md5),
//               !results.isEmpty {
//                let matchingSystems = results.compactMap { result -> PVSystem? in
//                    guard let sysID = (result["systemID"] as? NSNumber).map(String.init) else { return nil }
//                    return PVEmulatorConfiguration.system(forIdentifier: sysID)
//                }
//                
//                if matchingSystems.count == 1 {
//                    DLOG("Found single system match by MD5: \(matchingSystems[0].name)")
//                    return (matchingSystems[0], false)
//                } else if matchingSystems.count > 1 {
//                    DLOG("Found multiple system matches by MD5, moving to conflicts")
//                    return (matchingSystems[0], true) // Return first with conflict flag
//                }
//            }
//        }
//        
//        let fileName = candidate.filePath.lastPathComponent
//        let fileExtension = candidate.filePath.pathExtension.lowercased()
//        let possibleSystems = PVEmulatorConfiguration.systems(forFileExtension: fileExtension) ?? []
//        
//        // 2. Try exact filename match
//        if let system = await matchSystemByFileName(fileName) {
//            DLOG("Found system match by exact filename: \(system.name)")
//            return (system, false)
//        }
//        
//        // 3. Try extension match
//        if possibleSystems.count == 1 {
//            DLOG("Single system match by extension: \(possibleSystems[0].name)")
//            return (possibleSystems[0], false)
//        } else if possibleSystems.count > 1 {
//            DLOG("Multiple systems match extension, trying partial name match")
//            
//            // 4. Try partial filename system identifier match
//            if let system = matchSystemByPartialName(fileName, possibleSystems: possibleSystems) {
//                DLOG("Found system match by partial name: \(system.name)")
//                return (system, false)
//            }
//            
//            DLOG("No definitive system match, moving to conflicts")
//            return (possibleSystems[0], true)
//        }
//        
//        throw GameImporterError.systemNotDetermined
//    }
}
