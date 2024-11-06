//
//  GameImporter+Conflicts.swift
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
    /// Resolves conflicts with given solutions
//    public func resolveConflicts(withSolutions solutions: [URL: System]) async {
//        let importOperation = BlockOperation()
//        
//        await solutions.asyncForEach { filePath, system in
//            let subfolder = system.romsDirectory
//            
//            if !FileManager.default.fileExists(atPath: subfolder.path, isDirectory: nil) {
//                ILOG("Path <\(subfolder.path)> doesn't exist. Creating.")
//                do {
//                    try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true, attributes: nil)
//                } catch {
//                    ELOG("Error making conflicts dir <\(subfolder.path)>")
//                    assertionFailure("Error making conflicts dir <\(subfolder.path)>")
//                }
//            }
//            
//            let sourceFilename: String = filePath.lastPathComponent
//            let sourcePath: URL = filePath
//            let destinationPath: URL = subfolder.appendingPathComponent(sourceFilename, isDirectory: false)
//            
//            do {
//                try moveAndOverWrite(sourcePath: sourcePath, destinationPath: destinationPath)
//            } catch {
//                ELOG("\(error)")
//            }
//            
//            let relatedFileName: String = sourcePath.deletingPathExtension().lastPathComponent
//            
//            let conflictsDirContents = try? FileManager.default.contentsOfDirectory(at: conflictPath, includingPropertiesForKeys: nil, options: [])
//            conflictsDirContents?.forEach { file in
//                var fileWithoutExtension: String = file.deletingPathExtension().lastPathComponent
//                fileWithoutExtension = PVEmulatorConfiguration.stripDiscNames(fromFilename: fileWithoutExtension)
//                let relatedFileName = PVEmulatorConfiguration.stripDiscNames(fromFilename: relatedFileName)
//                
//                if fileWithoutExtension == relatedFileName {
//                    let isCueSheet = destinationPath.pathExtension == "cue"
//                    
//                    if isCueSheet {
//                        let cueSheetPath = destinationPath
//                        if var cuesheetContents = try? String(contentsOf: cueSheetPath, encoding: .utf8) {
//                            let range = (cuesheetContents as NSString).range(of: file.lastPathComponent, options: .caseInsensitive)
//                            
//                            if range.location != NSNotFound {
//                                if let subRange = Range<String.Index>(range, in: cuesheetContents) {
//                                    cuesheetContents.replaceSubrange(subRange, with: file.lastPathComponent)
//                                }
//                                
//                                do {
//                                    try cuesheetContents.write(to: cueSheetPath, atomically: true, encoding: .utf8)
//                                } catch {
//                                    ELOG("Unable to rewrite cuesheet \(destinationPath.path) because \(error.localizedDescription)")
//                                }
//                            } else {
//                                DLOG("Range of string <\(file)> not found in file <\(cueSheetPath.lastPathComponent)>")
//                            }
//                        }
//                    }
//                    
//                    do {
//                        let newDestinationPath = subfolder.appendingPathComponent(file.lastPathComponent, isDirectory: false)
//                        try moveAndOverWrite(sourcePath: file, destinationPath: newDestinationPath)
//                        NSLog("Moving \(file.lastPathComponent) to \(newDestinationPath)")
//                    } catch {
//                        ELOG("Unable to move related file from \(filePath.path) to \(subfolder.path) because: \(error.localizedDescription)")
//                    }
//                }
//            }
//            
//            importOperation.addExecutionBlock {
//                Task {
//                    ILOG("Import Files at \(destinationPath)")
//                    if let system = RomDatabase.systemCache[system.identifier] {
//                        RomDatabase.addFileSystemROMCache(system)
//                    }
//                    await self.getRomInfoForFiles(atPaths: [destinationPath], userChosenSystem: system)
//                }
//            }
//        }
//        
//        let completionOperation = BlockOperation {
//            if self.completionHandler != nil {
//                DispatchQueue.main.async(execute: { () -> Void in
//                    self.completionHandler?(false)
//                })
//            }
//        }
//        
//        completionOperation.addDependency(importOperation)
//        serialImportQueue.addOperation(importOperation)
//        serialImportQueue.addOperation(completionOperation)
//    }
//    
//    /// Handles a system conflict
//    internal func handleSystemConflict(path: URL, systems: [PVSystem]) async throws {
//        let candidate = ImportCandidateFile(filePath: path)
//        DLOG("Handling system conflict for path: \(path.lastPathComponent)")
//        DLOG("Possible systems: \(systems.map { $0.name }.joined(separator: ", "))")
//        
//        // Try to determine system using all available methods
//        if let system = try? await determineSystem(for: candidate) {
//            if systems.contains(system) {
//                DLOG("Found matching system: \(system.name)")
//                try importGame(path: path, system: system)
//                return
//            } else {
//                DLOG("Determined system \(system.name) not in possible systems list")
//            }
//        } else {
//            DLOG("Could not determine system automatically")
//        }
//        
//        // Fall back to multiple system handling
//        DLOG("Falling back to multiple system handling")
//        try handleMultipleSystemMatch(path: path, systems: systems)
//    }
//    
//    /// Handles a multiple system match
//    internal func handleMultipleSystemMatch(path: URL, systems: [PVSystem]) throws {
//        let filename = path.lastPathComponent
//        guard let existingGames = GameImporter.findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: filename) else {
//            self.encounteredConflicts = true
//            try moveToConflictsDirectory(path: path)
//            return
//        }
//        
//        if existingGames.count == 1 {
//            try importGame(path: path, system: systems.first!)
//        } else {
//            self.encounteredConflicts = true
//            try moveToConflictsDirectory(path: path)
//            let matchedSystems = systems.map { $0.identifier }.joined(separator: ", ")
//            let matchedGames = existingGames.map { $0.romPath }.joined(separator: ", ")
//            WLOG("Scanned game matched with multiple systems {\(matchedSystems)} and multiple existing games \(matchedGames) so we moved \(filename) to conflicts dir. You figure it out!")
//        }
//    }
}
