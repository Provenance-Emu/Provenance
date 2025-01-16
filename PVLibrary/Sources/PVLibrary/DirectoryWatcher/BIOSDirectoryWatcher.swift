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

@Perceptible
public final class BIOSWatcher: ObservableObject {
    public static let shared = BIOSWatcher()

    private let biosPath: URL
    private var directoryWatcher: DirectoryWatcher?
    private var newBIOSFilesContinuation: AsyncStream<[URL]>.Continuation?

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

        let options = DirectoryWatcherOptions(includeSubdirectories: true)
        directoryWatcher = DirectoryWatcher(directory: biosPath, options: options)
        ILOG("Created new DirectoryWatcher for path: \(biosPath.path)")

        // Create system-specific subdirectories if they don't exist
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
    }

    /// Scans for BIOS files and updates database entries
    @MainActor
    public func scanForBIOSFiles() async {
        ILOG("Starting BIOS file scan")

        let fileManager = FileManager.default
        var biosFiles = [URL]()

        // First check if the BIOS directory exists
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: biosPath.path, isDirectory: &isDirectory)
        ILOG("BIOS directory exists: \(exists), isDirectory: \(isDirectory.boolValue)")

        // List all subdirectories first
        if let contents = try? fileManager.contentsOfDirectory(at: biosPath, includingPropertiesForKeys: nil) {
            ILOG("BIOS root directory contents:")
            for item in contents {
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: item.path, isDirectory: &isDir)
                ILOG("  - \(item.lastPathComponent) (isDirectory: \(isDir.boolValue))")

                if isDir.boolValue {
                    // For system directories, scan their contents
                    if let subContents = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                        ILOG("    Contents of \(item.lastPathComponent):")
                        for subItem in subContents {
                            ILOG("      - \(subItem.lastPathComponent)")
                            biosFiles.append(subItem)
                        }
                    }
                } else {
                    // Also collect files in root BIOS directory
                    biosFiles.append(item)
                }
            }
        }

        ILOG("Found \(biosFiles.count) potential BIOS files")
        await processBIOSFiles(biosFiles)
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
    @MainActor
    private func processBIOSFiles(_ files: [URL]) async {
        ILOG("Processing BIOS files: \(files.map { $0.lastPathComponent })")
        let realm = try! await Realm()

        // Get all BIOS entries that don't have files
        let biosEntries = realm.objects(PVBIOS.self).filter("file == nil")
        ILOG("Found \(biosEntries.count) BIOS entries without files")

        // Log all expected filenames for debugging
//        DLOG("Expected BIOS filenames: \(biosEntries.map { $0.expectedFilename })")

        for file in files {
            let filename = file.lastPathComponent
            ILOG("Checking BIOS file: \(filename)")

            // Look for matching BIOS entries by filename
            if let matchingBios = biosEntries.first(where: { $0.expectedFilename.lowercased() == filename.lowercased() }) {
                ILOG("Found matching BIOS entry for \(filename)")
                do {
                    try updateBIOSEntry(matchingBios, withFileAt: file)
                } catch {
                    ELOG("Failed to update BIOS entry for \(filename): \(error.localizedDescription)")
                }
            } else {
                ILOG("No matching BIOS entry found for \(filename)")
            }
        }
    }

    private func watchForNewBIOSFiles() async {
        ILOG("watchForNewBIOSFiles started")
        guard let directoryWatcher = directoryWatcher else {
            ELOG("DirectoryWatcher is nil in watchForNewBIOSFiles")
            return
        }

        for await files in directoryWatcher.completedFilesSequence {
            ILOG("Received \(files.count) new files from DirectoryWatcher")

            // Process each file, including those in subdirectories
            let filesToProcess = files.filter { file in
                // Only process files that are either:
                // 1. Directly in BIOS directory
                // 2. One level deep in a system directory
                let relativePath = file.path.replacingOccurrences(of: biosPath.path, with: "")
                let components = relativePath.components(separatedBy: "/").filter { !$0.isEmpty }
                let isValidDepth = components.count <= 2 // Allow root or one subdirectory

                ILOG("Checking path depth for \(file.path): components=\(components), valid=\(isValidDepth)")
                return isValidDepth
            }

            if !filesToProcess.isEmpty {
                let realm = try! await Realm()
                let biosEntries = realm.objects(PVBIOS.self)

                let newFiles = filesToProcess.filter { file in
                    let fileName = file.lastPathComponent
                    // Check if this file is not already attached to any BIOS entry
                    let isAttached = biosEntries.contains { bios in
                        bios.file?.fileName == fileName
                    }
                    ILOG("Checking file \(fileName) - already attached to BIOS: \(isAttached)")
                    return !isAttached
                }

                if !newFiles.isEmpty {
                    ILOG("Processing \(newFiles.count) new BIOS files")
                    await processBIOSFiles(newFiles)
                    newBIOSFilesContinuation?.yield(newFiles)
                }
            }
        }
    }

    public func restartWatcher() {
        ILOG("Restarting BIOSWatcher")
        directoryWatcher?.stopMonitoring()
        directoryWatcher = nil
        directoryWatchingTask?.cancel()
        directoryWatchingTask = nil
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

    @MainActor
    public func checkBIOSFile(at path: URL) async -> Bool {
        let realm = try! await Realm()
        let fileName = path.lastPathComponent

        // First check if there's a BIOS entry expecting this file
        if let biosEntry = realm.objects(PVBIOS.self).first(where: { $0.expectedFilename.lowercased() == fileName.lowercased() }) {
            ILOG("Found BIOS entry for \(fileName)")

            // Check if it's already attached
            if biosEntry.file != nil {
                ILOG("BIOS file already attached for \(fileName)")
                return true
            }

            // If not attached, try to attach it
            do {
                try updateBIOSEntry(biosEntry, withFileAt: path)
                ILOG("Successfully attached BIOS file \(fileName)")
                return true
            } catch {
                ELOG("Failed to attach BIOS file \(fileName): \(error)")
                return false
            }
        }

        ILOG("No BIOS entry found for \(fileName)")
        return false
    }

    // Add a method to manually trigger a rescan of a specific directory
    @MainActor
    public func rescanDirectory(_ directory: URL? = nil) async {
        ILOG("Manually rescanning directory: \(directory?.path ?? "all")")

        let directoryToScan = directory ?? biosPath
        let fileManager = FileManager.default

        var files = [URL]()

        if directoryToScan == biosPath {
            // Full scan
            await scanForBIOSFiles()
        } else {
            // Scan specific directory
            do {
                let contents = try fileManager.contentsOfDirectory(at: directoryToScan,
                                                                 includingPropertiesForKeys: nil)
                files = contents
                ILOG("Found \(files.count) files in \(directoryToScan.path)")
                await processBIOSFiles(files)
            } catch {
                ELOG("Failed to scan directory \(directoryToScan.path): \(error)")
            }
        }
    }
}
