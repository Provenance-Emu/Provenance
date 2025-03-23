//
//  BIOSWatcher.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import Combine
import PVLogging
import Perception
import PVFileSystem
import RealmSwift

/// A dedicated actor for file system operations to keep them off the main thread
@globalActor actor FileSystemActor {
    static let shared = FileSystemActor()
    private init() {}
}

/// Actor to prevent crash when mutating and another thread is accessing
actor FileOperationTasks {
    private var fileOperationTasks = Set<Task<Void, Never>>()
    
    /// inserts item into set
    /// - Parameter item: item to insert
    func insert(_ item: Task<Void, Never>) {
        fileOperationTasks.insert(item)
    }
    
    /// removes item from set
    /// - Parameter item: item to remove
    func remove(_ item: Task<Void, Never>) {
        fileOperationTasks.remove(item)
    }
    
    /// clears set
    func removeAll() {
        fileOperationTasks.removeAll()
    }
    
    /// Cancels all ongoing file operation tasks and clears set after
    func cancelAllFileOperations() {
        for task in fileOperationTasks {
            task.cancel()
        }
        fileOperationTasks.removeAll()
    }
    
}

@Perceptible
public final class BIOSWatcher: ObservableObject {
    public static let shared = BIOSWatcher()

    private let biosPath: URL
    private var directoryWatcher: DirectoryWatcher?
    private var newBIOSFilesContinuation: AsyncStream<[URL]>.Continuation?

    /// Task group for managing concurrent file operations
    private var fileOperationTasks = FileOperationTasks()

    /// Serial queue for file operations that need to be sequential
    private let fileOperationQueue = DispatchQueue(label: "com.provenance.biosWatcher.fileOperations", qos: .utility)

    /// Concurrent queue for parallel file scanning
    private let fileScanQueue = DispatchQueue(label: "com.provenance.biosWatcher.fileScan", qos: .utility, attributes: .concurrent)

    public var newBIOSFilesSequence: AsyncStream<[URL]> {
        AsyncStream { continuation in
            newBIOSFilesContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.newBIOSFilesContinuation = nil
            }
        }
    }

    private init() {
        biosPath = Paths.biosesPath
        ILOG("BIOSWatcher initialized with path: \(biosPath.path)")
        setupDirectoryWatcher()
    }

    var directoryWatchingTask: Task<Void, Never>?
    private func setupDirectoryWatcher() {
        ILOG("Setting up BIOSWatcher directory watcher")

        // Cancel existing watcher if any
        if directoryWatcher != nil {
            ILOG("Cancelling existing watcher")
            directoryWatcher?.stopMonitoring()
            directoryWatcher = nil
        }

        Task {
            // Cancel any ongoing file operation tasks
            await fileOperationTasks.cancelAllFileOperations()
        }

        // Watch BIOS directory and its subdirectories, but exclude sibling directories
        let options = DirectoryWatcherOptions(
            includeSubdirectories: true,  // We do want to watch BIOS subdirectories
            allowedPaths: [biosPath],     // Only watch paths under the BIOS directory
            excludedPaths: []             // No need to explicitly exclude Imports since we're using allowedPaths
        )

        ILOG("BIOSWatcher root path: \(biosPath.path)")
        directoryWatcher = DirectoryWatcher(directory: biosPath, options: options)
        ILOG("Created new DirectoryWatcher for path: \(biosPath.path)")

        // Create system-specific subdirectories in background
        Task.detached(priority: .utility) {
            await self.createSystemDirectories()
        }

        do {
            try directoryWatcher?.startMonitoring()
            ILOG("Successfully started monitoring BIOS directory")
        } catch {
            ELOG("Failed to start monitoring BIOS directory: \(error)")
        }

        directoryWatchingTask?.cancel()
        directoryWatchingTask = Task {
            ILOG("Starting BIOS file watching task")
            // Perform initial scan
            await scanForBIOSFiles()
            // Then start watching for changes
            await watchForNewBIOSFiles()
        }

        // Add notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBIOSFileFound(_:)),
            name: .BIOSFileFound,
            object: nil
        )
    }

    /// Creates system-specific subdirectories off the main thread
    @FileSystemActor
    private func createSystemDirectories() async {
        for system in SystemIdentifier.allCases where system != .Unknown {
            let systemPath = biosPath.appendingPathComponent(system.rawValue)
            do {
                try FileManager.default.createDirectory(at: systemPath,
                                                      withIntermediateDirectories: true)
                ILOG("Ensured BIOS directory exists for system: \(system.rawValue)")
            } catch {
                ELOG("Failed to create BIOS directory for system \(system.rawValue): \(error)")
            }
        }
    }

    /// Scans for BIOS files and updates database entries
    public func scanForBIOSFiles() async {
        ILOG("Starting BIOS file scan")

        // Perform file scanning off the main thread
        let biosFiles = await scanFileSystem()

        ILOG("Found \(biosFiles.count) potential BIOS files")

        // Process files on a background thread, then update DB on main thread
        await processBIOSFiles(biosFiles)
    }

    /// Scans the file system for BIOS files off the main thread
    @FileSystemActor
    private func scanFileSystem() async -> [URL] {
        let fileManager = FileManager.default
        var biosFiles = [URL]()

        // First check if the BIOS directory exists
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: biosPath.path, isDirectory: &isDirectory)
        ILOG("BIOS directory exists: \(exists), isDirectory: \(isDirectory.boolValue)")

        guard exists && isDirectory.boolValue else {
            return []
        }

        // Use async/await with Task groups for concurrent directory scanning
        return await withTaskGroup(of: [URL].self) { group in
            do {
                // Get top-level contents
                let contents = try fileManager.contentsOfDirectory(at: biosPath, includingPropertiesForKeys: nil)

                ILOG("BIOS root directory contents: \(contents.count) items")

                // Add root-level files directly
                for item in contents {
                    var isDir: ObjCBool = false
                    fileManager.fileExists(atPath: item.path, isDirectory: &isDir)

                    if !isDir.boolValue {
                        biosFiles.append(item)
                    } else {
                        // For directories, scan them concurrently
                        group.addTask {
                            do {
                                let subContents = try fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                                ILOG("Scanned directory \(item.lastPathComponent): found \(subContents.count) files")
                                return subContents
                            } catch {
                                ELOG("Error scanning directory \(item.path): \(error)")
                                return []
                            }
                        }
                    }
                }

                // Collect results from all concurrent tasks
                for await result in group {
                    biosFiles.append(contentsOf: result)
                }

                return biosFiles
            } catch {
                ELOG("Error scanning BIOS directory: \(error)")
                return []
            }
        }
    }

    /// Updates a PVBIOS entry with a new file
    @MainActor
    public func updateBIOSEntry(_ bios: PVBIOS, withFileAt fileURL: URL) throws {
        let realm = try Realm()
        try realm.write {
            if let thawedBios = bios.thaw() {
                let biosFile = PVFile(withURL: fileURL)
                thawedBios.file = biosFile
                ILOG("Updated BIOS entry for \(bios.expectedFilename) with file at \(fileURL.path)")
            }
        }
    }

    /// Process a collection of potential BIOS files
    public func processBIOSFiles(_ files: [URL]) async {
        // First perform matching off the main thread
        let matchResults = await matchBIOSFilesToEntries(files)

        // Then update the database on the main thread
        await MainActor.run {
            Task {
                ILOG("Processing \(matchResults.count) BIOS file matches")

                guard let realm = try? await Realm() else {
                    ELOG("Failed to open Realm")
                    return
                }

                for (bios, fileURL) in matchResults {
                    do {
                        try updateBIOSEntry(bios, withFileAt: fileURL)
                    } catch {
                        ELOG("Failed to update BIOS entry for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Matches BIOS files to entries off the main thread
    private func matchBIOSFilesToEntries(_ files: [URL]) async -> [(PVBIOS, URL)] {
        await Task.detached(priority: .utility) {
            var results: [(PVBIOS, URL)] = []

            // Get realm and BIOS entries on the main thread
            let (biosEntries, realm): (Results<PVBIOS>?, Realm?) = await MainActor.run {
                guard let realm = try? Realm() else {
                    return (nil, nil)
                }
                let entries = realm.objects(PVBIOS.self).filter("file == nil")
                // Freeze the results so we can use them off the main thread
                return (entries.freeze(), realm)
            }

            guard let biosEntries = biosEntries, let _ = realm else {
                return []
            }

            // Process files in batches to avoid overwhelming the system
            let batchSize = 10
            for i in stride(from: 0, to: files.count, by: batchSize) {
                let end = min(i + batchSize, files.count)
                let batch = Array(files[i..<end])

                // Process each file in the batch
                for file in batch {
                    let filename = file.lastPathComponent.lowercased()

                    // Find matching BIOS entry
                    if let matchingBios = biosEntries.first(where: {
                        $0.expectedFilename.lowercased() == filename
                    }) {
                        results.append((matchingBios, file))
                    }

                    // Check for cancellation between files
                    if Task.isCancelled {
                        return results
                    }
                }

                // Small delay between batches to prevent CPU spikes
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }

            return results
        }.value
    }

    private func watchForNewBIOSFiles() async {
        ILOG("watchForNewBIOSFiles started")
        guard let directoryWatcher = directoryWatcher else {
            ELOG("DirectoryWatcher is nil in watchForNewBIOSFiles")
            return
        }

        for await files in directoryWatcher.completedFilesSequence {
            ILOG("Received \(files.count) new files from DirectoryWatcher")

            // Process files off the main thread
            let task = Task.detached(priority: .utility) {
                // Filter files based on path depth
                let filesToProcess = await self.filterFilesByDepth(files)

                if filesToProcess.isEmpty {
                    return
                }

                // Check which files are new (not already attached to BIOS entries)
                let newFiles = await self.filterNewFiles(filesToProcess)

                if !newFiles.isEmpty {
                    ILOG("Processing \(newFiles.count) new BIOS files")
                    await self.processBIOSFiles(newFiles)

                    // Notify observers on the main thread
                    await MainActor.run {
                        self.newBIOSFilesContinuation?.yield(newFiles)
                    }
                }
            }

            // Store the task for potential cancellation
            await fileOperationTasks.insert(task)

            // Set up cleanup when task completes
            Task {
                await task.value
                await self.fileOperationTasks.remove(task)
            }
        }
    }

    /// Filters files based on path depth off the main thread
    @FileSystemActor
    private func filterFilesByDepth(_ files: [URL]) async -> [URL] {
        files.filter { file in
            // Only process files that are either:
            // 1. Directly in BIOS directory
            // 2. One level deep in a system directory
            let relativePath = file.path.replacingOccurrences(of: biosPath.path, with: "")
            let components = relativePath.components(separatedBy: "/").filter { !$0.isEmpty }
            let isValidDepth = components.count <= 2 // Allow root or one subdirectory

            return isValidDepth
        }
    }

    /// Filters files to find ones not already attached to BIOS entries
    private func filterNewFiles(_ files: [URL]) async -> [URL] {
        // Get realm and BIOS entries on the main thread
        let biosEntries = await MainActor.run { () -> Results<PVBIOS>? in
            do {
                let realm = try Realm()
                return realm.objects(PVBIOS.self).freeze()
            } catch {
                ELOG("Failed to open Realm: \(error)")
                return nil
            }
        }

        guard let entries = biosEntries else {
            return []
        }

        // Filter files off the main thread
        return files.filter { file in
            let fileName = file.lastPathComponent
            // Check if this file is not already attached to any BIOS entry
            let isAttached = entries.contains { bios in
                bios.file?.fileName == fileName
            }
            return !isAttached
        }
    }

    public func restartWatcher() {
        ILOG("Restarting BIOSWatcher")
        directoryWatcher?.stopMonitoring()
        directoryWatcher = nil
        directoryWatchingTask?.cancel()
        directoryWatchingTask = nil
        Task {
            await fileOperationTasks.cancelAllFileOperations()
        }
        setupDirectoryWatcher()
    }

    public func checkWatcherStatus() async -> Bool {
        if let directoryWatcher = directoryWatcher {
            let watching = await directoryWatcher.isWatchingAnyFile()
            ILOG("BIOSWatcher status check: \(watching)")
            return watching
        }
        ILOG("BIOSWatcher status check: false (no directoryWatcher)")
        return false
    }

    public var hasActiveWatcher: Bool {
        let hasWatcher = directoryWatcher != nil
        ILOG("BIOSWatcher hasActiveWatcher check: \(hasWatcher)")
        return hasWatcher
    }

    public func checkBIOSFile(at path: URL) async -> Bool {
        // Perform file checking off the main thread
        let result = await Task.detached(priority: .utility) {
            let fileName = path.lastPathComponent.lowercased()

            // Get matching BIOS entry on the main thread
            let matchingBios = await MainActor.run {
                do {
                    let realm = try Realm()
                    return realm.objects(PVBIOS.self)
                        .filter("expectedFilename CONTAINS[c] %@", fileName)
                        .first?
                        .freeze()
                } catch {
                    ELOG("Failed to open Realm: \(error)")
                    return nil
                }
            }

            guard let bios = matchingBios else {
                ILOG("No BIOS entry found for \(fileName)")
                return false
            }

            // Check if already attached
            if bios.file != nil {
                ILOG("BIOS file already attached for \(fileName)")
                return true
            }

            return false
        }.value

        // If we found a match but it's not attached, attach it on the main thread
        if result == false {
            return await MainActor.run {
                do {
                    let realm = try Realm()
                    let fileName = path.lastPathComponent.lowercased()

                    if let biosEntry = realm.objects(PVBIOS.self)
                        .filter("expectedFilename CONTAINS[c] %@", fileName)
                        .first {

                        try updateBIOSEntry(biosEntry, withFileAt: path)
                        ILOG("Successfully attached BIOS file \(fileName)")
                        return true
                    }
                    return false
                } catch {
                    ELOG("Failed to attach BIOS file: \(error)")
                    return false
                }
            }
        }

        return result
    }

    // Add a method to manually trigger a rescan of a specific directory
    public func rescanDirectory(_ directory: URL? = nil) async {
        ILOG("Manually rescanning directory: \(directory?.path ?? "all")")

        let directoryToScan = directory ?? biosPath

        // Perform scanning off the main thread
        let task = Task.detached(priority: .utility) {
            if directoryToScan == self.biosPath {
                // Full scan
                await self.scanForBIOSFiles()
            } else {
                // Scan specific directory
                let files = await self.scanSpecificDirectory(directoryToScan)
                if !files.isEmpty {
                    await self.processBIOSFiles(files)
                }
            }
        }

        // Store the task for potential cancellation
        await fileOperationTasks.insert(task)

        // Set up cleanup when task completes
        Task {
            await task.value
            await self.fileOperationTasks.remove(task)
        }
    }

    /// Scans a specific directory for BIOS files off the main thread
    @FileSystemActor
    private func scanSpecificDirectory(_ directory: URL) async -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            ILOG("Found \(contents.count) files in \(directory.path)")
            return contents
        } catch {
            ELOG("Failed to scan directory \(directory.path): \(error)")
            return []
        }
    }

    @objc private func handleBIOSFileFound(_ notification: Notification) {
        guard let fileURL = notification.object as? URL else { return }

        // Process the file off the main thread
        let task = Task.detached(priority: .utility) {
            await self.processBIOSFiles([fileURL])
        }
        Task {
            // Store the task for potential cancellation
            await fileOperationTasks.insert(task)
            
            // Set up cleanup when task completes
            Task {
                await task.value
                await self.fileOperationTasks.remove(task)
            }
        }
    }

    deinit {
        Task {
            await fileOperationTasks.cancelAllFileOperations()
        }
        // Clean up resources
        directoryWatcher?.stopMonitoring()
        directoryWatchingTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}
