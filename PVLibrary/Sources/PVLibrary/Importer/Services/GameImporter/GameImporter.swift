//
//  GameImporter.swift
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
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

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/*
 
 Logic how the importer should work:
 
 1. Detect if special file (BIOS, Artwork)
 1. Detect if the file is artwork
 2. Detect if file is a BIOS
 1. if single match, move to BIOS for system
 2. if multiple matches, move to all matching systems
 2. Detect if the file is a CD-ROM (bin/cue) or m3u
 3. Detect if the file is m3u
 1. Match by filename of m3u or md5 of
 1. If m3u matches, move all files in m3u to the system that's matched
 4. Detect if the file is a CD-ROM (bin/cue)
 1. match cue by md5
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 2. match by exact filename
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 3. Detect if single file ROM
 1. match by md5
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 2. match by exact filename
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 3. Match by extension
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 4. Match by partial filename contains system identifier
 1. if single match, move to system
 2. if multiple matches, move to conflicts
 
 */

/// Import Coodinator
private actor ImportCoordinator {
    private var activeImports: Set<String> = []
    
    func checkAndRegisterImport(md5: String) -> Bool {
        guard !activeImports.contains(md5) else { return false }
        activeImports.insert(md5)
        return true
    }
    
    func completeImport(md5: String) {
        activeImports.remove(md5)
    }
}

/// Merges two dictionaries
public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    var combined = lhs
    
    for (k, v) in rhs {
        combined[k] = v
    }
    
    return combined
}

/// Type alias for a closure that handles the start of game import
public typealias GameImporterImportStartedHandler = (_ path: String) -> Void
/// Type alias for a closure that handles the completion of game import
public typealias GameImporterCompletionHandler = (_ encounteredConflicts: Bool) -> Void
/// Type alias for a closure that handles the finish of importing a game
public typealias GameImporterFinishedImportingGameHandler = (_ md5Hash: String, _ modified: Bool) -> Void
/// Type alias for a closure that handles the finish of getting artwork
public typealias GameImporterFinishedGettingArtworkHandler = (_ artworkURL: String?) -> Void


// Enum to define the possible statuses of each import
public enum ImportStatus: String {
    case queued
    case processing
    case success
    case failure
    case conflict  // Indicates additional action needed by user after successful import
    
    public var description: String {
        switch self {
            case .queued: return "Queued"
            case .processing: return "Processing"
            case .success: return "Completed"
            case .failure: return "Failed"
            case .conflict: return "Conflict"
        }
    }
        
    public var color: Color {
        switch self {
            case .queued: return .gray
            case .processing: return .blue
            case .success: return .green
            case .failure: return .red
            case .conflict: return .yellow
        }
    }
}

// Enum to define file types for each import
public enum FileType {
    case bios, artwork, game, cdRom, unknown
}

// Enum to track processing state
public enum ProcessingState {
    case idle
    case processing
}

// ImportItem model to hold each file's metadata and progress
@Observable
public class ImportItem: Identifiable, ObservableObject {
    public let id = UUID()
    public let url: URL
    public let fileType: FileType
    public let system: String  // Can be set to the specific system type
    
    // Observable status for individual imports
    public var status: ImportStatus = .queued
    
    public init(url: URL, fileType: FileType, system: String) {
        self.url = url
        self.fileType = fileType
        self.system = system
    }
}



#if !os(tvOS)
@Observable
#else
@Perceptible
#endif
public final class GameImporter: ObservableObject {
    /// Closure called when import starts
    public var importStartedHandler: GameImporterImportStartedHandler?
    /// Closure called when import completes
    public var completionHandler: GameImporterCompletionHandler?
    /// Closure called when a game finishes importing
    public var finishedImportHandler: GameImporterFinishedImportingGameHandler?
    /// Closure called when artwork finishes downloading
    public var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler?
    /// Flag indicating if conflicts were encountered during import
    public private(set) var encounteredConflicts = false
    
    /// Spotlight Handerls
    /// Closure called when spotlight completes
    public var spotlightCompletionHandler: GameImporterCompletionHandler?
    /// Closure called when a game finishes importing
    public var spotlightFinishedImportHandler: GameImporterFinishedImportingGameHandler?
    
    /// Singleton instance of GameImporter
    public static let shared: GameImporter = GameImporter()
    
    /// Instance of OpenVGDB for database operations
    var openVGDB = OpenVGDB.init()
    
    /// Queue for handling import work
    let workQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "romImporterWorkQueue"
        q.maxConcurrentOperationCount = 3 //OperationQueue.defaultMaxConcurrentOperationCount
        return q
    }()
    
    /// Queue for handling serial import operations
    public private(set) var serialImportQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "org.provenance-emu.provenance.serialImportQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    /// Map of system identifiers to their ROM paths
    public private(set) var systemToPathMap = [String: URL]()
    /// Map of ROM extensions to their corresponding system identifiers
    public private(set) var romExtensionToSystemsMap = [String: [String]]()
    
    // MARK: - Queue
    
    public var importStatus: String = ""
    
    public var importQueue: [ImportItem] = []
    
    public var processingState: ProcessingState = .idle  // Observable state for processing status

    // Adds an ImportItem to the queue without starting processing
    public func addImport(_ item: ImportItem) {
        importQueue.append(item)
        
        startProcessing()
    }

    // Public method to manually start processing if needed
    public func startProcessing() {
        // Only start processing if it's not already active
        guard processingState == .idle else { return }
        Task {
            await processQueue()
        }
    }

    // Processes each ImportItem in the queue sequentially
    private func processQueue() async {
        DispatchQueue.main.async {
            self.processingState = .processing
        }
        
        for item in importQueue where item.status == .queued {
            await processItem(item)
        }
        
        DispatchQueue.main.async {
            self.processingState = .idle  // Reset processing status when queue is fully processed
        }
    }

    // Process a single ImportItem and update its status
    private func processItem(_ item: ImportItem) async {
        item.status = .processing
        updateStatus("Importing \(item.url.lastPathComponent) for \(item.system)")

        do {
            // Simulate file processing
            try await performImport(for: item)
            item.status = .success
            updateStatus("Completed \(item.url.lastPathComponent) for \(item.system)")
        } catch {
            if error.localizedDescription.contains("Conflict") {
                item.status = .conflict
                updateStatus("Conflict for \(item.url.lastPathComponent). User action needed.")
            } else {
                item.status = .failure
                updateStatus("Failed \(item.url.lastPathComponent) with error: \(error.localizedDescription)")
            }
        }
    }

    private func performImport(for item: ImportItem) async throws {
        try await Task.sleep(nanoseconds: 5_000_000_000)
    }

    // General status update for GameImporter
    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.importStatus = message
        }
    }
    

    
    // MARK: - Paths
    
    /// Path to the documents directory
    public var documentsPath: URL { get { URL.documentsPath }}
    /// Path to the ROM import directory
    public var romsImportPath: URL { Paths.romsImportPath }
    /// Path to the ROMs directory
    public var romsPath: URL { get { Paths.romsPath }}
    /// Path to the BIOS directory
    public var biosPath: URL { get { Paths.biosesPath }}
    
    /// Path to the conflicts directory
    public let conflictPath: URL = URL.documentsPath.appendingPathComponent("Conflicts/", isDirectory: true)
    
    /// Returns the path for a given system identifier
    public func path(forSystemID systemID: String) -> URL? {
        return systemToPathMap[systemID]
    }
    
    /// Returns the system identifiers for a given ROM path
    public func systemIDsForRom(at path: URL) -> [String]? {
        let fileExtension: String = path.pathExtension.lowercased()
        return romExtensionToSystemsMap[fileExtension]
    }
    
    /// Checks if a given ROM file is a CD-ROM
    internal func isCDROM(_ romFile: ImportCandidateFile) -> Bool {
        return isCDROM(romFile.filePath)
    }
    
    /// Checks if a given path is a CD-ROM
    private func isCDROM(_ path: URL) -> Bool {
        let cdromExtensions: Set<String> = Extensions.discImageExtensions.union(Extensions.playlistExtensions)
        let fileExtension = path.pathExtension.lowercased()
        return cdromExtensions.contains(fileExtension)
    }
    
    /// Checks if a given path is artwork
    private func isArtwork(_ path: URL) -> Bool {
        let artworkExtensions = Extensions.artworkExtensions
        let fileExtension = path.pathExtension.lowercased()
        return artworkExtensions.contains(fileExtension)
    }
    
    /// Bundle for this module
    fileprivate let ThisBundle: Bundle = Bundle.module
    /// Token for notifications
    fileprivate var notificationToken: NotificationToken?
    /// DispatchGroup for initialization
    public let initialized = DispatchGroup()
    
    private let importCoordinator = ImportCoordinator()
    
    /// Initializes the GameImporter
    fileprivate init() {
        let fm = FileManager.default
        createDefaultDirectories(fm: fm)
    }
    
    /// Creates default directories
    private func createDefaultDirectories(fm: FileManager) {
        createDefaultDirectory(fm, url: conflictPath)
        createDefaultDirectory(fm, url: romsPath)
        createDefaultDirectory(fm, url: romsImportPath)
        createDefaultDirectory(fm, url: biosPath)
    }
    
    /// Creates a default directory at the given URL
    fileprivate func createDefaultDirectory(_ fm: FileManager, url: URL) {
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            ILOG("Path <\(url)> doesn't exist. Creating.")
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Error making conflicts dir <\(url)>")
                assertionFailure("Error making conflicts dir <\(url)>")
            }
        }
    }
    
    /// Initializes the systems
    public func initSystems() async {
        initialized.enter()
        await self.initCorePlists()
        
        /// Updates the system to path map
        @Sendable func updateSystemToPathMap() async -> [String: URL] {
            let systems = PVSystem.all
            return await systems.async.reduce(into: [String: URL]()) {partialResult, system in
                partialResult[system.identifier] = system.romsDirectory
            }
        }
        
        /// Updates the ROM extension to systems map
        @Sendable func updateromExtensionToSystemsMap() -> [String: [String]] {
            return PVSystem.all.reduce([String: [String]](), { (dict, system) -> [String: [String]] in
                let extensionsForSystem = system.supportedExtensions
                // Make a new dict of [ext : systemID] for each ext in extions for that ID, then merge that dictionary with the current one,
                // if the dictionary already has that key, the arrays are joined so you end up with a ext mapping to multpiple systemIDs
                let extsToCurrentSystemID = extensionsForSystem.reduce([String: [String]](), { (dict, ext) -> [String: [String]] in
                    var dict = dict
                    dict[ext] = [system.identifier]
                    return dict
                })
                
                return dict.merging(extsToCurrentSystemID, uniquingKeysWith: { var newArray = $0; newArray.append(contentsOf: $1); return newArray })
                
            })
        }
        
        Task.detached { @MainActor in
            let systems = PVSystem.all
            
            self.notificationToken = systems.observe { [unowned self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    Task.detached {
                        ILOG("RealmCollection changed state to .initial")
                        self.systemToPathMap = await updateSystemToPathMap()
                        self.romExtensionToSystemsMap = updateromExtensionToSystemsMap()
                        self.initialized.leave()
                    }
                case .update:
                    Task.detached {
                        ILOG("RealmCollection changed state to .update")
                        self.systemToPathMap = await updateSystemToPathMap()
                        self.romExtensionToSystemsMap = updateromExtensionToSystemsMap()
                    }
                case let .error(error):
                    ELOG("RealmCollection changed state to .error")
                    fatalError("\(error)")
                }
            }
        }
    }
    
    /// Initializes core plists
    fileprivate func initCorePlists() async {
        let corePlists: [EmulatorCoreInfoPlist]  = CoreLoader.getCorePlists()
        let bundle = ThisBundle
        await PVEmulatorConfiguration.updateSystems(fromPlists: [bundle.url(forResource: "systems", withExtension: "plist")!])
        await PVEmulatorConfiguration.updateCores(fromPlists: corePlists)
    }
    
    /// Deinitializer
    deinit {
        notificationToken?.invalidate()
    }
}

// MARK: - Importing Functions

extension GameImporter {
    /// Imports files from given paths
    public func importFiles(atPaths paths: [URL]) async throws -> [URL] {
        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        var importedFiles: [URL] = []
        
        for path in sortedPaths {
            do {
                if let importedFile = try await importSingleFile(at: path) {
                    importedFiles.append(importedFile)
                }
            } catch {
                ELOG("Failed to import file at \(path.path): \(error.localizedDescription)")
            }
        }
        
        return importedFiles
    }
    
    /// Imports a single file from the given path
    private func importSingleFile(at path: URL) async throws -> URL? {
        guard FileManager.default.fileExists(atPath: path.path) else {
            WLOG("File doesn't exist at \(path.path)")
            return nil
        }
        
        if isCDROM(path) {
            return try await handleCDROM(at: path)
        } else if isArtwork(path) {
            return try await handleArtwork(at: path)
        } else {
            return try await handleROM(at: path)
        }
    }
    
    /// Handles importing a CD-ROM
    private func handleCDROM(at path: URL) async throws -> URL? {
        let movedToPaths = try await moveCDROM(toAppropriateSubfolder: ImportCandidateFile(filePath: path))
        if let movedToPaths = movedToPaths {
            let pathsString = movedToPaths.map { $0.path }.joined(separator: ", ")
            VLOG("Found a CD. Moved files to the following paths \(pathsString)")
        }
        return nil
    }
    
    /// Handles importing artwork
    private func handleArtwork(at path: URL) async throws -> URL? {
        if let game = await GameImporter.importArtwork(fromPath: path) {
            ILOG("Found artwork \(path.lastPathComponent) for game <\(game.title)>")
        }
        return nil
    }
    
    /// Handles importing a ROM
    private func handleROM(at path: URL) async throws -> URL? {
        let candidate = ImportCandidateFile(filePath: path)
        return try await moveROM(toAppropriateSubfolder: candidate)
    }
    
    /// Starts an import for the given paths
    public func startImport(forPaths paths: [URL]) async {
        // Pre-sort
        let paths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        let scanOperation = BlockOperation {
            Task {
                do {
                    let newPaths = try await self.importFiles(atPaths: paths)
                    await self.getRomInfoForFiles(atPaths: newPaths, userChosenSystem: nil)
                } catch {
                    ELOG("\(error)")
                }
            }
        }
        
        let completionOperation = BlockOperation {
            if self.completionHandler != nil {
                DispatchQueue.main.sync(execute: { () -> Void in
                    self.completionHandler?(self.encounteredConflicts)
                })
            }
        }
        
        completionOperation.addDependency(scanOperation)
        serialImportQueue.addOperation(scanOperation)
        serialImportQueue.addOperation(completionOperation)
    }
}

// MARK: - Moving Functions

extension GameImporter {
    /// Moves a CD-ROM to the appropriate subfolder
    private func moveCDROM(toAppropriateSubfolder candidate: ImportCandidateFile) async throws -> [URL]? {
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
    private func moveROM(toAppropriateSubfolder candidate: ImportCandidateFile) async throws -> URL? {
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

// MARK: - Conflict Resolution

extension GameImporter {
    /// Resolves conflicts with given solutions
    public func resolveConflicts(withSolutions solutions: [URL: System]) async {
        let importOperation = BlockOperation()
        
        await solutions.asyncForEach { filePath, system in
            let subfolder = system.romsDirectory
            
            if !FileManager.default.fileExists(atPath: subfolder.path, isDirectory: nil) {
                ILOG("Path <\(subfolder.path)> doesn't exist. Creating.")
                do {
                    try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    ELOG("Error making conflicts dir <\(subfolder.path)>")
                    assertionFailure("Error making conflicts dir <\(subfolder.path)>")
                }
            }
            
            let sourceFilename: String = filePath.lastPathComponent
            let sourcePath: URL = filePath
            let destinationPath: URL = subfolder.appendingPathComponent(sourceFilename, isDirectory: false)
            
            do {
                try moveAndOverWrite(sourcePath: sourcePath, destinationPath: destinationPath)
            } catch {
                ELOG("\(error)")
            }
            
            let relatedFileName: String = sourcePath.deletingPathExtension().lastPathComponent
            
            let conflictsDirContents = try? FileManager.default.contentsOfDirectory(at: conflictPath, includingPropertiesForKeys: nil, options: [])
            conflictsDirContents?.forEach { file in
                var fileWithoutExtension: String = file.deletingPathExtension().lastPathComponent
                fileWithoutExtension = PVEmulatorConfiguration.stripDiscNames(fromFilename: fileWithoutExtension)
                let relatedFileName = PVEmulatorConfiguration.stripDiscNames(fromFilename: relatedFileName)
                
                if fileWithoutExtension == relatedFileName {
                    let isCueSheet = destinationPath.pathExtension == "cue"
                    
                    if isCueSheet {
                        let cueSheetPath = destinationPath
                        if var cuesheetContents = try? String(contentsOf: cueSheetPath, encoding: .utf8) {
                            let range = (cuesheetContents as NSString).range(of: file.lastPathComponent, options: .caseInsensitive)
                            
                            if range.location != NSNotFound {
                                if let subRange = Range<String.Index>(range, in: cuesheetContents) {
                                    cuesheetContents.replaceSubrange(subRange, with: file.lastPathComponent)
                                }
                                
                                do {
                                    try cuesheetContents.write(to: cueSheetPath, atomically: true, encoding: .utf8)
                                } catch {
                                    ELOG("Unable to rewrite cuesheet \(destinationPath.path) because \(error.localizedDescription)")
                                }
                            } else {
                                DLOG("Range of string <\(file)> not found in file <\(cueSheetPath.lastPathComponent)>")
                            }
                        }
                    }
                    
                    do {
                        let newDestinationPath = subfolder.appendingPathComponent(file.lastPathComponent, isDirectory: false)
                        try moveAndOverWrite(sourcePath: file, destinationPath: newDestinationPath)
                        NSLog("Moving \(file.lastPathComponent) to \(newDestinationPath)")
                    } catch {
                        ELOG("Unable to move related file from \(filePath.path) to \(subfolder.path) because: \(error.localizedDescription)")
                    }
                }
            }
            
            importOperation.addExecutionBlock {
                Task {
                    ILOG("Import Files at \(destinationPath)")
                    if let system = RomDatabase.systemCache[system.identifier] {
                        RomDatabase.addFileSystemROMCache(system)
                    }
                    await self.getRomInfoForFiles(atPaths: [destinationPath], userChosenSystem: system)
                }
            }
        }
        
        let completionOperation = BlockOperation {
            if self.completionHandler != nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.completionHandler?(false)
                })
            }
        }
        
        completionOperation.addDependency(importOperation)
        serialImportQueue.addOperation(importOperation)
        serialImportQueue.addOperation(completionOperation)
    }
}

// MARK: - Artwork Handling

public extension GameImporter {
    /// Imports artwork from a given path
    class func importArtwork(fromPath imageFullPath: URL) async -> PVGame? {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: imageFullPath.path, isDirectory: &isDirectory)
        if !fileExists || isDirectory.boolValue {
            WLOG("File doesn't exist or is directory at \(imageFullPath)")
            return nil
        }
        
        var success = false
        
        defer {
            if success {
                do {
                    try FileManager.default.removeItem(at: imageFullPath)
                } catch {
                    ELOG("Failed to delete image at path \(imageFullPath) \n \(error.localizedDescription)")
                }
            }
        }
        
        let gameFilename: String = imageFullPath.deletingPathExtension().lastPathComponent
        let gameExtension = imageFullPath.deletingPathExtension().pathExtension
        let database = RomDatabase.sharedInstance
        
        if gameExtension.isEmpty {
            ILOG("Trying to import artwork that didn't contain the extension of the system")
            let games = database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [gameFilename]))
            
            if games.count == 1, let game = games.first {
                ILOG("File for image didn't have extension for system but we found a single match for image \(imageFullPath.lastPathComponent) to game \(game.title) on system \(game.systemIdentifier)")
                guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
                    return nil
                }
                
                do {
                    try database.writeTransaction {
                        game.customArtworkURL = hash
                    }
                    success = true
                    ILOG("Set custom artwork of game \(game.title) from file \(imageFullPath.lastPathComponent)")
                } catch {
                    ELOG("Couldn't update game \(game.title) with new artwork URL \(hash)")
                }
                
                return game
            } else {
                VLOG("Database search returned \(games.count) results")
            }
        }
        
        guard let systems: [PVSystem] = PVEmulatorConfiguration.systemsFromCache(forFileExtension: gameExtension), !systems.isEmpty else {
            ELOG("No system for extension \(gameExtension)")
            return nil
        }
        
        let cdBasedSystems = PVEmulatorConfiguration.cdBasedSystems
        let couldBelongToCDSystem = !Set(cdBasedSystems).isDisjoint(with: Set(systems))
        
        if (couldBelongToCDSystem && PVEmulatorConfiguration.supportedCDFileExtensions.contains(gameExtension.lowercased())) || systems.count > 1 {
            guard let existingGames = findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: gameFilename) else {
                ELOG("System for extension \(gameExtension) is a CD system and {\(gameExtension)} not the right matching file type of cue or m3u")
                return nil
            }
            if existingGames.count == 1, let onlyMatch = existingGames.first {
                ILOG("We found a hit for artwork that could have been belonging to multiple games and only found one file that matched by systemid/filename. The winner is \(onlyMatch.title) for \(onlyMatch.systemIdentifier)")
                
                guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
                    ELOG("Couldn't move image, fail to set custom artwork")
                    return nil
                }
                
                do {
                    try database.writeTransaction {
                        onlyMatch.customArtworkURL = hash
                    }
                    success = true
                } catch {
                    ELOG("Couldn't update game \(onlyMatch.title) with new artwork URL")
                }
                return onlyMatch
            } else {
                ELOG("We got to the unlikely scenario where an extension is possibly a CD binary file, or belongs to a system, and had multiple games that matched the filename under more than one core.")
                return nil
            }
        }
        
        guard let system = systems.first else {
            ELOG("systems empty")
            return nil
        }
        
        var gamePartialPath: String = URL(fileURLWithPath: system.identifier, isDirectory: true).appendingPathComponent(gameFilename).deletingPathExtension().path
        if gamePartialPath.first == "/" {
            gamePartialPath.removeFirst()
        }
        
        if gamePartialPath.isEmpty {
            ELOG("Game path was empty")
            return nil
        }
        
        var games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: gamePartialPath)
        if games.isEmpty {
            games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), beginsWith: gamePartialPath)
        }
        
        guard !games.isEmpty else {
            ELOG("Couldn't find game for path \(gamePartialPath)")
            return nil
        }
        
        if games.count > 1 {
            WLOG("There were multiple matches for \(gamePartialPath)! #\(games.count). Going with first for now until we make better code to prompt user.")
        }
        
        let game = games.first!
        
        guard let hash = scaleAndMoveImageToCache(imageFullPath: imageFullPath) else {
            ELOG("scaleAndMoveImageToCache failed")
            return nil
        }
        
        do {
            try database.writeTransaction {
                game.customArtworkURL = hash
            }
            success = true
        } catch {
            ELOG("Couldn't update game with new artwork URL")
        }
        
        return game
    }
    
    /// Scales and moves an image to the cache
    fileprivate class func scaleAndMoveImageToCache(imageFullPath: URL) -> String? {
        let coverArtFullData: Data
        do {
            coverArtFullData = try Data(contentsOf: imageFullPath, options: [])
        } catch {
            ELOG("Couldn't read data from image file \(imageFullPath.path)\n\(error.localizedDescription)")
            return nil
        }
        
#if canImport(UIKit)
        guard let coverArtFullImage = UIImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
            ELOG("Failed to create scale image")
            return nil
        }
#else
        guard let coverArtFullImage = NSImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        let coverArtScaledImage = coverArtFullImage
#endif
        
#if canImport(UIKit)
        guard let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.85) else {
            ELOG("Failed to create data representation of scaled image")
            return nil
        }
#else
        let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.85)
#endif
        
        let hash: String = (coverArtScaledData as NSData).md5
        
        do {
            let destinationURL = try PVMediaCache.writeData(toDisk: coverArtScaledData, withKey: hash)
            VLOG("Scaled and moved image from \(imageFullPath.path) to \(destinationURL.path)")
        } catch {
            ELOG("Failed to save artwork to cache: \(error.localizedDescription)")
            return nil
        }
        
        return hash
    }
}

// MARK: - System Management

extension GameImporter {
    
    private func matchSystemByPartialName(_ fileName: String, possibleSystems: [PVSystem]) -> PVSystem? {
        let cleanedName = fileName.lowercased()
        
        for system in possibleSystems {
            let patterns = filenamePatterns(forSystem: system)
            
            for pattern in patterns {
                if (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?
                    .firstMatch(in: cleanedName, options: [], range: NSRange(cleanedName.startIndex..., in: cleanedName)) != nil {
                    DLOG("Found system match by pattern '\(pattern)' for system: \(system.name)")
                    return system
                }
            }
        }
        
        return nil
    }
    
    /// Matches a system based on the file name
    private func matchSystemByFileName(_ fileName: String) async -> PVSystem? {
        let systems = PVEmulatorConfiguration.systems
        let lowercasedFileName = fileName.lowercased()
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        // First, try to match based on file extension
        if let systemsForExtension = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
            if systemsForExtension.count == 1 {
                return systemsForExtension[0]
            } else if systemsForExtension.count > 1 {
                // If multiple systems match the extension, try to narrow it down
                for system in systemsForExtension {
                    if await doesFileNameMatch(lowercasedFileName, forSystem: system) {
                        return system
                    }
                }
            }
        }
        
        // If extension matching fails, try other methods
        for system in systems {
            if await doesFileNameMatch(lowercasedFileName, forSystem: system) {
                return system
            }
        }
        
        // If no match found, try querying the OpenVGDB
        do {
            if let results = try await openVGDB.searchDatabase(usingFilename: fileName),
               let firstResult = results.first,
               let systemID = firstResult["systemID"] as? Int,
               let system = PVEmulatorConfiguration.system(forDatabaseID: systemID) {
                return system
            }
        } catch {
            ELOG("Error querying OpenVGDB for filename: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Checks if a file name matches a given system
    private func doesFileNameMatch(_ lowercasedFileName: String, forSystem system: PVSystem) async -> Bool {
        // Check if the filename contains the system's name or abbreviation
        if lowercasedFileName.contains(system.name.lowercased()) ||
            lowercasedFileName.contains(system.shortName.lowercased()) {
            return true
        }
        
        // Check against known filename patterns for the system
        let patterns = filenamePatterns(forSystem: system)
        for pattern in patterns {
            if lowercasedFileName.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Check against a list of known game titles for the system
        if await isKnownGameTitle(lowercasedFileName, forSystem: system) {
            return true
        }
        
        return false
    }
    
    /// Checks if a file name matches a known game title for a given system
    private func isKnownGameTitle(_ lowercasedFileName: String, forSystem system: PVSystem) async -> Bool {
        do {
            // Remove file extension and common parenthetical information
            let cleanedFileName = cleanFileName(lowercasedFileName)
            
            // Search the database using the cleaned filename
            if let results = try await openVGDB.searchDatabase(usingFilename: cleanedFileName, systemID: system.openvgDatabaseID) {
                // Check if we have any results
                if !results.isEmpty {
                    // Optionally, you can add more strict matching here
                    for result in results {
                        if let gameTitle = result["gameTitle"] as? String,
                           cleanFileName(gameTitle.lowercased()) == cleanedFileName {
                            return true
                        }
                    }
                }
            }
        } catch {
            ELOG("Error searching OpenVGDB for known game title: \(error.localizedDescription)")
        }
        return false
    }
    
    /// Cleans a file name
    private func cleanFileName(_ fileName: String) -> String {
        var cleaned = fileName.lowercased()
        
        // Remove file extension
        if let dotIndex = cleaned.lastIndex(of: ".") {
            cleaned = String(cleaned[..<dotIndex])
        }
        
        // Remove common parenthetical information
        let parentheticalPatterns = [
            "\\(.*?\\)",           // Matches anything in parentheses
            "\\[.*?\\]",           // Matches anything in square brackets
            "\\(u\\)",             // Common ROM notation for USA
            "\\(e\\)",             // Common ROM notation for Europe
            "\\(j\\)",             // Common ROM notation for Japan
            "\\(usa\\)",
            "\\(europe\\)",
            "\\(japan\\)",
            "\\(world\\)",
            "v1\\.0",
            "v1\\.1",
            // Add more patterns as needed
        ]
        
        for pattern in parentheticalPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove extra spaces and trim
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Retrieves filename patterns for a given system
    private func filenamePatterns(forSystem system: PVSystem) -> [String] {
        let systemName = system.name.lowercased()
        let shortName = system.shortName.lowercased()
        
        var patterns: [String] = []
        
        // Add pattern for full system name
        patterns.append("\\b\(systemName)\\b")
        
        // Add pattern for short name
        patterns.append("\\b\(shortName)\\b")
        // Add some common variations and abbreviations
        switch system.identifier {
        case "com.provenance.nes":
            patterns.append("\\b(nes|nintendo)\\b")
        case "com.provenance.snes":
            patterns.append("\\b(snes|super\\s*nintendo)\\b")
        case "com.provenance.genesis":
            patterns.append("\\b(genesis|mega\\s*drive|md)\\b")
        case "com.provenance.gba":
            patterns.append("\\b(gba|game\\s*boy\\s*advance)\\b")
        case "com.provenance.n64":
            patterns.append("\\b(n64|nintendo\\s*64)\\b")
        case "com.provenance.psx":
            patterns.append("\\b(psx|playstation|ps1)\\b")
        case "com.provenance.ps2":
            patterns.append("\\b(ps2|playstation\\s*2)\\b")
        case "com.provenance.gb":
            patterns.append("\\b(gb|game\\s*boy)\\b")
        case "com.provenance.3DO":
            patterns.append("\\b(3do|panasonic\\s*3do)\\b")
        case "com.provenance.3ds":
            patterns.append("\\b(3ds|nintendo\\s*3ds)\\b")
        case "com.provenance.2600":
            patterns.append("\\b(2600|atari\\s*2600|vcs)\\b")
        case "com.provenance.5200":
            patterns.append("\\b(5200|atari\\s*5200)\\b")
        case "com.provenance.7800":
            patterns.append("\\b(7800|atari\\s*7800)\\b")
        case "com.provenance.jaguar":
            patterns.append("\\b(jaguar|atari\\s*jaguar)\\b")
        case "com.provenance.colecovision":
            patterns.append("\\b(coleco|colecovision)\\b")
        case "com.provenance.dreamcast":
            patterns.append("\\b(dc|dreamcast|sega\\s*dreamcast)\\b")
        case "com.provenance.ds":
            patterns.append("\\b(nds|nintendo\\s*ds)\\b")
        case "com.provenance.gamegear":
            patterns.append("\\b(gg|game\\s*gear|sega\\s*game\\s*gear)\\b")
        case "com.provenance.gbc":
            patterns.append("\\b(gbc|game\\s*boy\\s*color)\\b")
        case "com.provenance.lynx":
            patterns.append("\\b(lynx|atari\\s*lynx)\\b")
        case "com.provenance.mastersystem":
            patterns.append("\\b(sms|master\\s*system|sega\\s*master\\s*system)\\b")
        case "com.provenance.neogeo":
            patterns.append("\\b(neo\\s*geo|neogeo|neo-geo)\\b")
        case "com.provenance.ngp":
            patterns.append("\\b(ngp|neo\\s*geo\\s*pocket)\\b")
        case "com.provenance.ngpc":
            patterns.append("\\b(ngpc|neo\\s*geo\\s*pocket\\s*color)\\b")
        case "com.provenance.psp":
            patterns.append("\\b(psp|playstation\\s*portable)\\b")
        case "com.provenance.saturn":
            patterns.append("\\b(saturn|sega\\s*saturn)\\b")
        case "com.provenance.32X":
            patterns.append("\\b(32x|sega\\s*32x)\\b")
        case "com.provenance.segacd":
            patterns.append("\\b(scd|sega\\s*cd|mega\\s*cd)\\b")
        case "com.provenance.sg1000":
            patterns.append("\\b(sg1000|sg-1000|sega\\s*1000)\\b")
        case "com.provenance.vb":
            patterns.append("\\b(vb|virtual\\s*boy)\\b")
        case "com.provenance.ws":
            patterns.append("\\b(ws|wonderswan)\\b")
        case "com.provenance.wsc":
            patterns.append("\\b(wsc|wonderswan\\s*color)\\b")
        default:
            // For systems without specific patterns, we'll just use the general ones created above
            break
        }
        
        return patterns
    }
    
    /// Determines the system for a given candidate file
    private func determineSystemFromContent(for candidate: ImportCandidateFile, possibleSystems: [PVSystem]) throws -> PVSystem {
        // Implement logic to determine system based on file content or metadata
        // This could involve checking file headers, parsing content, or using a database of known games
        
        let fileName = candidate.filePath.deletingPathExtension().lastPathComponent
        
        for system in possibleSystems {
            do {
                if let results = try openVGDB.searchDatabase(usingFilename: fileName, systemID: system.openvgDatabaseID),
                   !results.isEmpty {
                    ILOG("System determined by filename match in OpenVGDB: \(system.name)")
                    return system
                }
            } catch {
                ELOG("Error searching OpenVGDB for system \(system.name): \(error.localizedDescription)")
            }
        }
        
        // If we couldn't determine the system, try a more detailed search
        if let fileMD5 = candidate.md5?.uppercased(), !fileMD5.isEmpty {
            do {
                if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: fileMD5),
                   let firstResult = results.first,
                   let systemID = firstResult["systemID"] as? Int,
                   let system = possibleSystems.first(where: { $0.openvgDatabaseID == systemID }) {
                    ILOG("System determined by MD5 match in OpenVGDB: \(system.name)")
                    return system
                }
            } catch {
                ELOG("Error searching OpenVGDB by MD5: \(error.localizedDescription)")
            }
        }
        
        // If still no match, try to determine based on file content
        // This is a placeholder for more advanced content-based detection
        // You might want to implement system-specific logic here
        for system in possibleSystems {
            if doesFileContentMatch(candidate, forSystem: system) {
                ILOG("System determined by file content match: \(system.name)")
                return system
            }
        }
        
        // If we still couldn't determine the system, return the first possible system as a fallback
        WLOG("Could not determine system from content, using first possible system as fallback")
        return possibleSystems[0]
    }
    
    /// Checks if a file content matches a given system
    private func doesFileContentMatch(_ candidate: ImportCandidateFile, forSystem system: PVSystem) -> Bool {
        // Implement system-specific file content matching logic here
        // This could involve checking file headers, file structure, or other system-specific traits
        // For now, we'll return false as a placeholder
        return false
    }
    
    /// Determines the system for a given candidate file
    private func determineSystem(for candidate: ImportCandidateFile) async throws -> PVSystem {
        guard let md5 = candidate.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }
        
        let fileExtension = candidate.filePath.pathExtension.lowercased()
        
        DLOG("Checking MD5: \(md5) for possible BIOS match")
        // First check if this is a BIOS file by MD5
        let biosMatches = PVEmulatorConfiguration.biosEntries.filter("expectedMD5 == %@", md5).map({ $0 })
        if !biosMatches.isEmpty {
            DLOG("Found BIOS matches: \(biosMatches.map { $0.expectedFilename }.joined(separator: ", "))")
            // Copy BIOS to all matching system directories
            for bios in biosMatches {
                if let system = bios.system {
                    DLOG("Copying BIOS to system: \(system.name)")
                    let biosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
                        .appendingPathComponent(bios.expectedFilename)
                    try FileManager.default.copyItem(at: candidate.filePath, to: biosPath)
                }
            }
            // Return the first system that uses this BIOS
            if let firstSystem = biosMatches.first?.system {
                DLOG("Using first matching system for BIOS: \(firstSystem.name)")
                return firstSystem
            }
        }
        
        // Check if it's a CD-based game first
        if PVEmulatorConfiguration.supportedCDFileExtensions.contains(fileExtension) {
            if let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
                if systems.count == 1 {
                    return systems[0]
                } else if systems.count > 1 {
                    // For CD games with multiple possible systems, use content detection
                    return try determineSystemFromContent(for: candidate, possibleSystems: systems)
                }
            }
        }
        
        // Try to find system by MD5 using OpenVGDB
        if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: md5),
           let firstResult = results.first,
           let systemID = firstResult["systemID"] as? NSNumber {
            
            // Get all matching systems
            let matchingSystems = results.compactMap { result -> PVSystem? in
                guard let sysID = (result["systemID"] as? NSNumber).map(String.init) else { return nil }
                return PVEmulatorConfiguration.system(forIdentifier: sysID)
            }
            
            if !matchingSystems.isEmpty {
                // Sort by release year and take the oldest
                if let oldestSystem = matchingSystems.sorted(by: { $0.releaseYear < $1.releaseYear }).first {
                    DLOG("System determined by MD5 match (oldest): \(oldestSystem.name) (\(oldestSystem.releaseYear))")
                    return oldestSystem
                }
            }
            
            // Fallback to original single system match if sorting fails
            if let system = PVEmulatorConfiguration.system(forIdentifier: String(systemID.intValue)) {
                DLOG("System determined by MD5 match (fallback): \(system.name)")
                return system
            }
        }
        
        DLOG("MD5 lookup failed, trying filename matching")
        
        // Try filename matching next
        let fileName = candidate.filePath.lastPathComponent
        
        if let matchedSystem = await matchSystemByFileName(fileName) {
            DLOG("Found system by filename match: \(matchedSystem.name)")
            return matchedSystem
        }
        
        let possibleSystems = PVEmulatorConfiguration.systems(forFileExtension: candidate.filePath.pathExtension.lowercased()) ?? []
        
        // If MD5 lookup fails, try to determine the system based on file extension
        if let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
            if systems.count == 1 {
                return systems[0]
            } else if systems.count > 1 {
                // If multiple systems support this extension, try to determine based on file content or metadata
                return try await determineSystemFromContent(for: candidate, possibleSystems: systems)
            }
        }
        
        throw GameImporterError.noSystemMatched
    }
    
    /// Retrieves the system ID from the cache for a given ROM candidate
    public func systemIdFromCache(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }
        if let result = RomDatabase.artMD5DBCache[md5] ?? RomDatabase.getArtCacheByFileName(rom.filePath.lastPathComponent),
           let databaseID = result["systemID"] as? Int,
           let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
            return systemID
        }
        return nil
    }
    
    /// Matches a system based on the ROM candidate
    public func systemId(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }
        
        let fileName: String = rom.filePath.lastPathComponent
        
        do {
            if let databaseID = try openVGDB.system(forRomMD5: md5, or: fileName),
               let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
                return systemID
            } else {
                ILOG("Could't match \(rom.filePath.lastPathComponent) based off of MD5 {\(md5)}")
                return nil
            }
        } catch {
            DLOG("Unable to find rom by MD5: \(error.localizedDescription)")
            return nil
        }
    }
}

/// ROM Query
public extension GameImporter {
    
    /// Retrieves ROM information for files at given paths
    func getRomInfoForFiles(atPaths paths: [URL], userChosenSystem chosenSystem: System? = nil) async {
        // If directory, map out sub directories if folder
        let paths: [URL] = paths.compactMap { (url) -> [URL]? in
            if url.hasDirectoryPath {
                return try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } else {
                return [url]
            }
        }.joined().map { $0 }
        
        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
        await sortedPaths.asyncForEach { path in
            do {
                try await self._handlePath(path: path, userChosenSystem: chosenSystem)
            } catch {
                ELOG("\(error)")
            }
        } // for each
    }
}

// Crap, bad crap
extension GameImporter {
    
    /// Calculates the MD5 hash for a given game
    @objc
    public func calculateMD5(forGame game: PVGame) -> String? {
        var offset: UInt64 = 0
        
        if game.systemIdentifier == SystemIdentifier.SNES.rawValue {
            offset = SystemIdentifier.SNES.offset
        } else if let system = SystemIdentifier(rawValue: game.systemIdentifier) {
            offset = system.offset
        }
        
        let romPath = romsPath.appendingPathComponent(game.romPath, isDirectory: false)
        let fm = FileManager.default
        if !fm.fileExists(atPath: romPath.path) {
            ELOG("Cannot find file at path: \(romPath)")
            return nil
        }
        
        return fm.md5ForFile(atPath: romPath.path, fromOffset: offset)
    }
    
    /// Saves the relative path for a given game
    func saveRelativePath(_ existingGame: PVGame, partialPath:String, file:URL) {
        Task {
            if await RomDatabase.gamesCache[partialPath] == nil {
                await RomDatabase.addRelativeFileCache(file, game:existingGame)
            }
        }
    }
    
    /// Handles the import of a path
    func _handlePath(path: URL, userChosenSystem chosenSystem: System?) async throws {
        // Skip hidden files and directories
        if path.lastPathComponent.hasPrefix(".") {
            VLOG("Skipping hidden file or directory: \(path.lastPathComponent)")
            return
        }
        
        let isDirectory = path.hasDirectoryPath
        let filename = path.lastPathComponent
        let fileExtensionLower = path.pathExtension.lowercased()
        
        // Handle directories
        if isDirectory {
            try await handleDirectory(path: path, chosenSystem: chosenSystem)
            return
        }
        
        // Handle files
        let systems = try determineSystems(for: path, chosenSystem: chosenSystem)
        
        // Handle conflicts
        if systems.count > 1 {
            try await handleSystemConflict(path: path, systems: systems)
            return
        }
        
        guard let system = systems.first else {
            ELOG("No system matched extension {\(fileExtensionLower)}")
            try moveToConflictsDirectory(path: path)
            return
        }
        
        try importGame(path: path, system: system)
    }
    
    // Helper functions
    
    /// Handles a directory
    private func handleDirectory(path: URL, chosenSystem: System?) async throws {
        guard chosenSystem == nil else { return }
        
        do {
            let subContents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            if subContents.isEmpty {
                try await FileManager.default.removeItem(at: path)
                ILOG("Deleted empty import folder \(path.path)")
            } else {
                ILOG("Found non-empty folder in imports dir. Will iterate subcontents for import")
                for subFile in subContents {
                    try await self._handlePath(path: subFile, userChosenSystem: nil)
                }
            }
        } catch {
            ELOG("Error handling directory: \(error)")
            throw error
        }
    }
    private func determineSystemByMD5(_ candidate: ImportCandidateFile) async throws -> PVSystem? {
        guard let md5 = candidate.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }
        
        DLOG("Attempting MD5 lookup for: \(md5)")
        
        // Try to find system by MD5 using OpenVGDB
        if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: md5),
           let firstResult = results.first,
           let systemID = firstResult["systemID"] as? NSNumber,
           let system = PVEmulatorConfiguration.system(forIdentifier: String(systemID.intValue)) {
            DLOG("System determined by MD5 match: \(system.name)")
            return system
        }
        
        DLOG("No system found by MD5")
        return nil
    }
    
    /// Determines the systems for a given path
    private func determineSystems(for path: URL, chosenSystem: System?) throws -> [PVSystem] {
        if let chosenSystem = chosenSystem {
            if let system = RomDatabase.systemCache[chosenSystem.identifier] {
                return [system]
            }
        }
        
        let fileExtensionLower = path.pathExtension.lowercased()
        return PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtensionLower) ?? []
    }
    
    /// Handles a system conflict
    private func handleSystemConflict(path: URL, systems: [PVSystem]) async throws {
        let candidate = ImportCandidateFile(filePath: path)
        DLOG("Handling system conflict for path: \(path.lastPathComponent)")
        DLOG("Possible systems: \(systems.map { $0.name }.joined(separator: ", "))")
        
        // Try to determine system using all available methods
        if let system = try? await determineSystem(for: candidate) {
            if systems.contains(system) {
                DLOG("Found matching system: \(system.name)")
                try importGame(path: path, system: system)
                return
            } else {
                DLOG("Determined system \(system.name) not in possible systems list")
            }
        } else {
            DLOG("Could not determine system automatically")
        }
        
        // Fall back to multiple system handling
        DLOG("Falling back to multiple system handling")
        try handleMultipleSystemMatch(path: path, systems: systems)
    }
    
    /// Handles a multiple system match
    private func handleMultipleSystemMatch(path: URL, systems: [PVSystem]) throws {
        let filename = path.lastPathComponent
        guard let existingGames = GameImporter.findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: filename) else {
            self.encounteredConflicts = true
            try moveToConflictsDirectory(path: path)
            return
        }
        
        if existingGames.count == 1 {
            try importGame(path: path, system: systems.first!)
        } else {
            self.encounteredConflicts = true
            try moveToConflictsDirectory(path: path)
            let matchedSystems = systems.map { $0.identifier }.joined(separator: ", ")
            let matchedGames = existingGames.map { $0.romPath }.joined(separator: ", ")
            WLOG("Scanned game matched with multiple systems {\(matchedSystems)} and multiple existing games \(matchedGames) so we moved \(filename) to conflicts dir. You figure it out!")
        }
    }
    
    private func importGame(path: URL, system: PVSystem) throws {
        DLOG("Attempting to import game: \(path.lastPathComponent) for system: \(system.name)")
        let filename = path.lastPathComponent
        let partialPath = (system.identifier as NSString).appendingPathComponent(filename)
        let similarName = RomDatabase.altName(path, systemIdentifier: system.identifier)
        
        DLOG("Checking game cache for partialPath: \(partialPath) or similarName: \(similarName)")
        let gamesCache = RomDatabase.gamesCache
        
        if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
           system.identifier == existingGame.systemIdentifier {
            DLOG("Found existing game in cache, saving relative path")
            saveRelativePath(existingGame, partialPath: partialPath, file: path)
        } else {
            DLOG("No existing game found, starting import to database")
            Task.detached(priority: .utility) {
                try await self.importToDatabaseROM(atPath: path, system: system, relatedFiles: nil)
            }
        }
    }
    
    /// Moves a file to the conflicts directory
    private func moveToConflictsDirectory(path: URL) throws {
        let destination = conflictPath.appendingPathComponent(path.lastPathComponent)
        try moveAndOverWrite(sourcePath: path, destinationPath: destination)
    }
    
    /// Imports a ROM to the database
    private func importToDatabaseROM(atPath path: URL, system: PVSystem, relatedFiles: [URL]?) async throws {
        DLOG("Starting database ROM import for: \(path.lastPathComponent)")
        let filename = path.lastPathComponent
        let filenameSansExtension = path.deletingPathExtension().lastPathComponent
        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameSansExtension)
        let destinationDir = (system.identifier as NSString)
        let partialPath: String = (system.identifier as NSString).appendingPathComponent(filename)
        
        DLOG("Creating game object with title: \(title), partialPath: \(partialPath)")
        let file = PVFile(withURL: path)
        let game = PVGame(withFile: file, system: system)
        game.romPath = partialPath
        game.title = title
        game.requiresSync = true
        var relatedPVFiles = [PVFile]()
        let files = RomDatabase.getFileSystemROMCache(for: system).keys
        let name = RomDatabase.altName(path, systemIdentifier: system.identifier)
        
        DLOG("Searching for related files with name: \(name)")
        
        await files.asyncForEach { url in
            let relativeName = RomDatabase.altName(url, systemIdentifier: system.identifier)
            DLOG("Checking file \(url.lastPathComponent) with relative name: \(relativeName)")
            if relativeName == name {
                DLOG("Found matching related file: \(url.lastPathComponent)")
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }
        
        if let relatedFiles = relatedFiles {
            DLOG("Processing \(relatedFiles.count) additional related files")
            for url in relatedFiles {
                DLOG("Adding related file: \(url.lastPathComponent)")
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }
        
        guard let md5 = calculateMD5(forGame: game)?.uppercased() else {
            ELOG("Couldn't calculate MD5 for game \(partialPath)")
            throw GameImporterError.couldNotCalculateMD5
        }
        DLOG("Calculated MD5: \(md5)")
        
        // Register import with coordinator
        guard await importCoordinator.checkAndRegisterImport(md5: md5) else {
            DLOG("Import already in progress for MD5: \(md5)")
            throw GameImporterError.romAlreadyExistsInDatabase
        }
        DLOG("Registered import with coordinator for MD5: \(md5)")
        
        defer {
            Task {
                await importCoordinator.completeImport(md5: md5)
                DLOG("Completed import coordination for MD5: \(md5)")
            }
        }
        
        game.relatedFiles.append(objectsIn: relatedPVFiles)
        game.md5Hash = md5
        try await finishUpdateOrImport(ofGame: game, path: path)
    }
    
    /// Finishes the update or import of a game
    private func finishUpdateOrImport(ofGame game: PVGame, path: URL) async throws {
        // Only process if rom doensn't exist in DB
        if await RomDatabase.gamesCache[game.romPath] != nil {
            throw GameImporterError.romAlreadyExistsInDatabase
        }
        var modified = false
        var game:PVGame = game
        if game.requiresSync {
            if importStartedHandler != nil {
                let fullpath = PVEmulatorConfiguration.path(forGame: game)
                Task { @MainActor in
                    self.importStartedHandler?(fullpath.path)
                }
            }
            game = lookupInfo(for: game, overwrite: true)
            modified = true
        }
        let wasModified = modified
        if finishedImportHandler != nil {
            let md5: String = game.md5Hash
            //            Task { @MainActor in
            self.finishedImportHandler?(md5, wasModified)
            //            }
        }
        if game.originalArtworkFile == nil {
            game = await getArtwork(forGame: game)
        }
        self.saveGame(game)
    }
    
    /// Saves a game to the database
    func saveGame(_ game:PVGame) {
        do {
            let database = RomDatabase.sharedInstance
            try database.writeTransaction {
                database.realm.create(PVGame.self, value:game, update:.modified)
            }
            RomDatabase.addGamesCache(game)
        } catch {
            ELOG("Couldn't add new game \(error.localizedDescription)")
        }
    }
    
    /// Finds any current game that could belong to any of the given systems
    fileprivate class func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem]?, romFilename: String) -> [PVGame]? {
        // Check if existing ROM
        
        let allGames = RomDatabase.gamesCache.values.filter ({
            $0.romPath.lowercased() == romFilename.lowercased()
        })
        /*
         let database = RomDatabase.sharedInstance
         
         let predicate = NSPredicate(format: "romPath CONTAINS[c] %@", PVEmulatorConfiguration.stripDiscNames(fromFilename: romFilename))
         let allGames = database.all(PVGame.self, filter: predicate)
         */
        // Optionally filter to specfici systems
        if let systems = systems {
            //let filteredGames = allGames.filter { systems.contains($0.system) }
            var sysIds:[String:Bool]=[:]
            systems.forEach({ sysIds[$0.identifier] = true })
            let filteredGames = allGames.filter { sysIds[$0.systemIdentifier] != nil }
            return filteredGames.isEmpty ? nil : Array(filteredGames)
        } else {
            return allGames.isEmpty ? nil : Array(allGames)
        }
    }
    private func handleM3UFile(_ candidate: ImportCandidateFile) async throws -> PVSystem? {
        guard candidate.filePath.pathExtension.lowercased() == "m3u" else {
            return nil
        }
        
        DLOG("Handling M3U file: \(candidate.filePath.lastPathComponent)")
        
        // First try to match the M3U file itself by MD5
        if let system = try? await determineSystem(for: candidate) {
            DLOG("Found system match for M3U by MD5: \(system.name)")
            return system
        }
        
        // Read M3U contents
        let contents = try String(contentsOf: candidate.filePath, encoding: .utf8)
        let files = contents.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        DLOG("Found \(files.count) entries in M3U")
        
        // Try to match first valid file in M3U
        for file in files {
            let filePath = candidate.filePath.deletingLastPathComponent().appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: filePath.path) else { continue }
            
            let candidateFile = ImportCandidateFile(filePath: filePath)
            if let system = try? await determineSystem(for: candidateFile) {
                DLOG("Found system match from M3U entry: \(file) -> \(system.name)")
                return system
            }
        }
        
        DLOG("No system match found for M3U or its contents")
        return nil
    }
    
    private func handleRegularROM(_ candidate: ImportCandidateFile) async throws -> (PVSystem, Bool) {
        DLOG("Handling regular ROM file: \(candidate.filePath.lastPathComponent)")
        
        // 1. Try MD5 match first
        if let md5 = candidate.md5?.uppercased() {
            if let results = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: md5),
               !results.isEmpty {
                let matchingSystems = results.compactMap { result -> PVSystem? in
                    guard let sysID = (result["systemID"] as? NSNumber).map(String.init) else { return nil }
                    return PVEmulatorConfiguration.system(forIdentifier: sysID)
                }
                
                if matchingSystems.count == 1 {
                    DLOG("Found single system match by MD5: \(matchingSystems[0].name)")
                    return (matchingSystems[0], false)
                } else if matchingSystems.count > 1 {
                    DLOG("Found multiple system matches by MD5, moving to conflicts")
                    return (matchingSystems[0], true) // Return first with conflict flag
                }
            }
        }
        
        let fileName = candidate.filePath.lastPathComponent
        let fileExtension = candidate.filePath.pathExtension.lowercased()
        let possibleSystems = PVEmulatorConfiguration.systems(forFileExtension: fileExtension) ?? []
        
        // 2. Try exact filename match
        if let system = await matchSystemByFileName(fileName) {
            DLOG("Found system match by exact filename: \(system.name)")
            return (system, false)
        }
        
        // 3. Try extension match
        if possibleSystems.count == 1 {
            DLOG("Single system match by extension: \(possibleSystems[0].name)")
            return (possibleSystems[0], false)
        } else if possibleSystems.count > 1 {
            DLOG("Multiple systems match extension, trying partial name match")
            
            // 4. Try partial filename system identifier match
            if let system = matchSystemByPartialName(fileName, possibleSystems: possibleSystems) {
                DLOG("Found system match by partial name: \(system.name)")
                return (system, false)
            }
            
            DLOG("No definitive system match, moving to conflicts")
            return (possibleSystems[0], true)
        }
        
        throw GameImporterError.systemNotDetermined
    }
}
