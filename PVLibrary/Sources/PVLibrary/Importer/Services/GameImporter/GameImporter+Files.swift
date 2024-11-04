//
//  GameImporter+Files.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import Foundation
import PVSupport
import RealmSwift

extension GameImporter {
    /// Moves a CD-ROM to the appropriate subfolder
    internal func moveCDROM(toAppropriateSubfolder candidate: ImportCandidateFile) async throws -> [URL]? {
        guard isCDROM(candidate.filePath) else {
            return nil
        }
        
        let fileManager = FileManager.default
        let fileName = candidate.filePath.lastPathComponent
        
        guard let system = try? await determineSystem(for: candidate) else {
            throw GameImporterError.unsupportedSystem
        }
        
        let destinationFolder = system.romsDirectory
        let destinationPath = destinationFolder.appendingPathComponent(fileName)
        
        do {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true, attributes: nil)
            try fileManager.moveItem(at: candidate.filePath, to: destinationPath)
            let relatedFiles = try await moveRelatedFiles(for: candidate, to: destinationFolder)
            return [destinationPath] + relatedFiles
        } catch {
            throw GameImporterError.failedToMoveCDROM(error)
        }
    }
    
    /// Moves a ROM to the appropriate subfolder
    internal func moveROM(toAppropriateSubfolder candidate: ImportCandidateFile) async throws -> URL? {
        guard !isCDROM(candidate.filePath) else {
            return nil
        }
        
        let fileManager = FileManager.default
        let fileName = candidate.filePath.lastPathComponent
        
        // Check first if known BIOS
        if let system = try await handleBIOSFile(candidate) {
            DLOG("Moving BIOS file to system: \(system.name)")
            let destinationFolder = system.biosDirectory
            let destinationPath = destinationFolder.appendingPathComponent(fileName)
            return try await moveROMFile(candidate, to: destinationPath)
        }
        
        // Check for M3U
        if let system = try await handleM3UFile(candidate) {
            DLOG("Moving M3U and referenced files to system: \(system.name)")
            // Move M3U and all referenced files to system directory
            let destinationDir = system.romsDirectory
            return try await moveM3UAndReferencedFiles(candidate, to: destinationDir)
        }
        
        // CD-ROM handling
        if let system = try await handleCDROMFile(candidate) {
            DLOG("Moving CD-ROM files to system: \(system.name)")
            let destinationDir = system.romsDirectory
            return try await moveCDROMFiles(candidate, to: destinationDir)
        }
        
        // Regular ROM handling
        let (system, hasConflict) = try await handleRegularROM(candidate)
        let destinationDir = hasConflict ? self.conflictPath : system.romsDirectory
        
        DLOG("Moving ROM to \(hasConflict ? "conflicts" : "system") directory: \(system.name)")
        return try await moveROMFile(candidate, to: destinationDir)
    }
    
    private func handleBIOSFile(_ candidate: ImportCandidateFile) async throws -> PVSystem? {
        guard let md5 = candidate.md5?.uppercased() else {
            return nil
        }
        
        // Get all BIOS entries that match this MD5
        let matchingBIOSEntries = PVEmulatorConfiguration.biosEntries.filter { biosEntry in
            let frozenBiosEntry = biosEntry.isFrozen ? biosEntry : biosEntry.freeze()
            return frozenBiosEntry.expectedMD5.uppercased() == md5
        }
        
        if !matchingBIOSEntries.isEmpty {
            // Get the first matching system
            if let firstBIOSEntry = matchingBIOSEntries.first {
                let frozenBiosEntry = firstBIOSEntry.isFrozen ? firstBIOSEntry : firstBIOSEntry.freeze()
                
                // Move file to BIOS directory
                let destinationURL = frozenBiosEntry.expectedPath
                try await moveROMFile(candidate, to: destinationURL)
                
                // Update BIOS entry in Realm
                try await MainActor.run {
                    let realm = try Realm()
                    try realm.write {
                        if let thawedBios = frozenBiosEntry.thaw() {
                            let biosFile = PVFile(withURL: destinationURL)
                            thawedBios.file = biosFile
                        }
                    }
                }
                
                return frozenBiosEntry.system
            }
        }
        
        return nil
    }
    
    private func handleCDROMFile(_ candidate: ImportCandidateFile) async throws -> PVSystem? {
        let `extension` = candidate.filePath.pathExtension.lowercased()
        guard PVEmulatorConfiguration.supportedCDFileExtensions.contains(`extension`) else {
            return nil
        }
        
        DLOG("Handling CD-ROM file: \(candidate.filePath.lastPathComponent)")
        
        // First try MD5 matching
        if let system = try? await determineSystem(for: candidate) {
            DLOG("Found system match for CD-ROM by MD5: \(system.name)")
            return system
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
        
        // Try exact filename match
        if let system = await matchSystemByFileName(candidate.filePath.lastPathComponent) {
            DLOG("Found system match by filename: \(system.name)")
            return system
        }
        
        DLOG("No system match found for CD-ROM file")
        return nil
    }
    
    /// Move a `ImportCandidateFile` to a destination, creating the destination directory if needed
    private func moveROMFile(_ romFile: ImportCandidateFile, to destination: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let destPath = destination.appendingPathComponent(romFile.filePath.lastPathComponent)
        try FileManager.default.moveItem(at: romFile.filePath, to: destPath)
        DLOG("Moved ROM file to: \(destPath.path)")
        return destPath
    }
    
    private func findAssociatedBinFile(for cueFile: ImportCandidateFile) throws -> URL? {
        let cueContents = try String(contentsOf: cueFile.filePath, encoding: .utf8)
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
            let binPath = cueFile.filePath.deletingLastPathComponent().appendingPathComponent(binFileName)
            
            if FileManager.default.fileExists(atPath: binPath.path) {
                return binPath
            }
        }
        
        return nil
    }
    
    private func moveM3UAndReferencedFiles(_ m3uFile: ImportCandidateFile, to destination: URL) async throws -> URL {
        let contents = try String(contentsOf: m3uFile.filePath, encoding: .utf8)
        let files = contents.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        // Create destination directory if needed
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Move all referenced files
        for file in files {
            let sourcePath = m3uFile.filePath.deletingLastPathComponent().appendingPathComponent(file)
            let destPath = destination.appendingPathComponent(file)
            
            if FileManager.default.fileExists(atPath: sourcePath.path) {
                try FileManager.default.moveItem(at: sourcePath, to: destPath)
                DLOG("Moved M3U referenced file: \(file)")
            }
        }
        
        // Move M3U file itself
        let m3uDestPath = destination.appendingPathComponent(m3uFile.filePath.lastPathComponent)
        try FileManager.default.moveItem(at: m3uFile.filePath, to: m3uDestPath)
        DLOG("Moved M3U file to: \(m3uDestPath.path)")
        
        return m3uDestPath
    }
    
    private func moveCDROMFiles(_ cdFile: ImportCandidateFile, to destination: URL) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        let `extension` = cdFile.filePath.pathExtension.lowercased()
        let destPath = destination.appendingPathComponent(cdFile.filePath.lastPathComponent)
        
        // If it's a cue file, move both cue and bin
        if `extension` == "cue" {
            if let binPath = try findAssociatedBinFile(for: cdFile) {
                let binDestPath = destination.appendingPathComponent(binPath.lastPathComponent)
                try fileManager.moveItem(at: binPath, to: binDestPath)
                DLOG("Moved bin file to: \(binDestPath.path)")
            }
        }
        
        // Move the main CD-ROM file
        try fileManager.moveItem(at: cdFile.filePath, to: destPath)
        DLOG("Moved CD-ROM file to: \(destPath.path)")
        
        return destPath
    }
    
    /// Moves related files for a given candidate
    private func moveRelatedFiles(for candidate: ImportCandidateFile, to destinationFolder: URL) async throws -> [URL] {
        let fileManager = FileManager.default
        let fileName = candidate.filePath.deletingPathExtension().lastPathComponent
        let sourceFolder = candidate.filePath.deletingLastPathComponent()
        
        let relatedFiles = try fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil)
            .filter { $0.deletingPathExtension().lastPathComponent == fileName && $0 != candidate.filePath }
        
        return try await withThrowingTaskGroup(of: URL.self) { group in
            for file in relatedFiles {
                group.addTask {
                    let destination = destinationFolder.appendingPathComponent(file.lastPathComponent)
                    try fileManager.moveItem(at: file, to: destination)
                    return destination
                }
            }
            
            var movedFiles: [URL] = []
            for try await movedFile in group {
                movedFiles.append(movedFile)
            }
            return movedFiles
        }
    }
    
    /// Moves a file and overwrites if it already exists at the destination
    public func moveAndOverWrite(sourcePath: URL, destinationPath: URL) throws {
        let fileManager = FileManager.default
        
        // If file exists at destination, remove it first
        if fileManager.fileExists(atPath: destinationPath.path) {
            try fileManager.removeItem(at: destinationPath)
        }
        
        // Now move the file
        try fileManager.moveItem(at: sourcePath, to: destinationPath)
    }
    
    /// BIOS entry matching
    private func biosEntryMatching(candidateFile: ImportCandidateFile) -> [PVBIOS]? {
        let fileName = candidateFile.filePath.lastPathComponent
        var matchingBioses = Set<PVBIOS>()
        
        DLOG("Checking if file is BIOS: \(fileName)")
        
        // First try to match by filename
        if let biosEntry = PVEmulatorConfiguration.biosEntry(forFilename: fileName) {
            DLOG("Found BIOS match by filename: \(biosEntry.expectedFilename)")
            matchingBioses.insert(biosEntry)
        }
        
        // Then try to match by MD5
        if let md5 = candidateFile.md5?.uppercased(),
           let md5Entry = PVEmulatorConfiguration.biosEntry(forMD5: md5) {
            DLOG("Found BIOS match by MD5: \(md5Entry.expectedFilename)")
            matchingBioses.insert(md5Entry)
        }
        
        if !matchingBioses.isEmpty {
            let matches = Array(matchingBioses)
            DLOG("Found \(matches.count) BIOS matches")
            return matches
        }
        
        return nil
    }
}
