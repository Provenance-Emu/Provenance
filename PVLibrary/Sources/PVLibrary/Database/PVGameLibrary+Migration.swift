//
//  PVGameLibrary+Migration.swift
//  PVLibrary
//
//  Created by Dan Berglund on 2020-06-02.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import RxSwift
import PVSupport
import PVLogging
import AsyncAlgorithms
import PVFileSystem

/// Handles migration of ROM and BIOS files from old documents directory to new shared container directory
public final class ROMLocationMigrator {
    private let fileManager = FileManager.default

    /// Old paths that need migration
    private var oldPaths: [(source: URL, destination: URL)] {
        guard let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)?
            .appendingPathComponent("Documents") else {
            ELOG("Could not load appgroup \(PVAppGroupId)")
            return []
        }

        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsURL = URL(fileURLWithPath: documentsPath)

        if Defaults[.useAppGroups] {
            return [
                (documentsURL.appendingPathComponent("ROMs"),
                 sharedContainer.appendingPathComponent("ROMs")),
                (documentsURL.appendingPathComponent("BIOS"),
                 sharedContainer.appendingPathComponent("BIOS")),
                (documentsURL.appendingPathComponent("Battery Saves"),
                 sharedContainer.appendingPathComponent("Battery Saves")),
                (documentsURL.appendingPathComponent("Save States"),
                 sharedContainer.appendingPathComponent("Save States")),
                (documentsURL.appendingPathComponent("RetroArch"),
                 sharedContainer.appendingPathComponent("RetroArch")),
                (documentsURL.appendingPathComponent("Conflicts"),
                 sharedContainer.appendingPathComponent("Conflicts"))
            ]
        } else {
            return [
                (sharedContainer.appendingPathComponent("ROMs"),
                 documentsURL.appendingPathComponent("ROMs")),
                (sharedContainer.appendingPathComponent("BIOS"),
                 documentsURL.appendingPathComponent("BIOS")),
                (sharedContainer.appendingPathComponent("Battery Saves"),
                 documentsURL.appendingPathComponent("Battery Saves")),
                (sharedContainer.appendingPathComponent("Save States"),
                 documentsURL.appendingPathComponent("Save States")),
                (sharedContainer.appendingPathComponent("RetroArch"),
                 documentsURL.appendingPathComponent("RetroArch")),
                (sharedContainer.appendingPathComponent("Conflicts"),
                 documentsURL.appendingPathComponent("Conflicts"))
            ]
        }
    }

    public func printFolderContents() async {
        for (oldPath, newPath) in oldPaths {
            try? await printFolderContents(oldPath)
            try? await printFolderContents(newPath)
        }
    }

    /// Debug print contents of folder and it's subfolders
    public func printFolderContents(_ folder: URL) async throws {
        let contents = try await fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [])
        let paths = contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).sorted(by: { $0.path < $1.path }).map { $0.relativePath }
        DLOG("Contents of path: \(folder.standardizedFileURL): \(paths.joined(separator: ", "))")
    }

    /// Migrates files from old location to new location if necessary
    public func migrateIfNeeded() async throws {
        ILOG("Checking if file migration is needed...")
        #if DEBUG
        await try? printFolderContents()
        #endif

        for (oldPath, newPath) in oldPaths {
            if fileManager.fileExists(atPath: oldPath.path) {
                ILOG("Found old directory to migrate: \(oldPath.lastPathComponent)")
                // Contents of old directory
                #if DEBUG
                let contents = try await fileManager.contentsOfDirectory(at: oldPath, includingPropertiesForKeys: nil, options: [])
                let paths = contents.map { $0.relativePath }.joined(separator: ", ")
                DLOG("PATHS: \(paths)")
                #endif
                if !fileManager.fileExists(atPath: newPath.path) {
                    try fileManager.createDirectory(at: newPath,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
                }

                try await migrateDirectory(from: oldPath, to: newPath)

                // Clean up empty directories after migration is complete
                try await cleanupSourceDirectory(oldPath)
            } else {
                ILOG("No old \(oldPath.lastPathComponent) directory found, skipping migration")
            }
        }
    }

    /// Recursively migrates contents of a directory
    private func migrateDirectory(from sourceDir: URL, to destDir: URL) async throws {
        ILOG("Migrating directory: \(sourceDir.lastPathComponent)")

        // Get all items in source directory with minimal property loading
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]
        let enumerator = FileManager.default.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        guard let enumerator = enumerator else {
            ELOG("Failed to create enumerator for \(sourceDir.path)")
            return
        }

        // Process items in chunks to avoid memory pressure
        let chunkSize = 20
        var itemsToProcess: [URL] = []

        while let url = enumerator.nextObject() as? URL {
            itemsToProcess.append(url)

            if itemsToProcess.count >= chunkSize {
                try await processChunk(itemsToProcess, sourceDir: sourceDir, destDir: destDir)
                itemsToProcess.removeAll(keepingCapacity: true)

                // Brief pause between chunks to let the system breathe
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }

        // Process remaining items
        if !itemsToProcess.isEmpty {
            try await processChunk(itemsToProcess, sourceDir: sourceDir, destDir: destDir)
        }
    }

    private func processChunk(_ urls: [URL], sourceDir: URL, destDir: URL) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for itemURL in urls {
                group.addTask {
                    /// Get the relative path from the source directory to preserve directory structure
                    let relativePath = itemURL.path.replacingOccurrences(of: sourceDir.path, with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let destinationURL = destDir.appendingPathComponent(relativePath)

                    // Quick check for existing files first
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        ILOG("Skipping \(relativePath) as it already exists")
                        return
                    }

                    let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])

                    if resourceValues.isDirectory ?? false {
                        // Handle directory
                        if !FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.createDirectory(
                                at: destinationURL,
                                withIntermediateDirectories: true,
                                attributes: nil
                            )
                        }
                        try await self.migrateDirectory(from: itemURL, to: destinationURL)
                    } else {
                        // Create parent directories if needed
                        try FileManager.default.createDirectory(
                            at: destinationURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true,
                            attributes: nil
                        )
                        // Handle file
                        try FileManager.default.moveItem(at: itemURL, to: destinationURL)
                        ILOG("Migrated: \(relativePath)")
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func cleanupSourceDirectory(_ sourceDir: URL) async throws {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: sourceDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            // First check if there are any files (non-directories)
            let hasFiles = contents.contains { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return !isDirectory
            }

            if !hasFiles {
                // Process subdirectories recursively
                for url in contents {
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDirectory {
                        try await cleanupSourceDirectory(url)
                    }
                }

                // Check again after processing subdirectories
                let remainingContents = try FileManager.default.contentsOfDirectory(
                    at: sourceDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                if remainingContents.isEmpty {
                    try await FileManager.default.removeItem(at: sourceDir)
                    ILOG("Removed empty directory: \(sourceDir.lastPathComponent)")
                }
            }
        } catch {
            ELOG("Error cleaning up \(sourceDir.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Fixes files that were incorrectly placed in the root ROMs directory instead of their system-specific subdirectories
    public func fixOrphanedFiles() async throws {
        // Get all games from the database
        let realm = RomDatabase.sharedInstance.realm
        let games = realm.objects(PVGame.self)

        // Get the root ROMs directory
        let romsRootDir = Paths.romsPath

        // Get list of files in root ROMs dir
        let fileManager = FileManager.default
        let rootFiles = try fileManager.contentsOfDirectory(at: romsRootDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

        // Keep track of files we've moved
        var movedFiles = Set<String>()

        // For each game, check if its file is in the root directory and move it if needed
        for game in games {
            // Get the game's file URL
            guard let gameFile = game.file else { continue }
            let gameURL = gameFile.url

            // Skip if file is already in correct location
            if gameURL.deletingLastPathComponent().lastPathComponent == game.systemIdentifier {
                continue
            }

            // Check if file exists in root directory
            let filename = gameURL.lastPathComponent
            let rootFileURL = romsRootDir.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: rootFileURL.path) && !movedFiles.contains(filename) {
                // Create system subdirectory if needed
                let systemDir = romsRootDir.appendingPathComponent(game.systemIdentifier)
                try fileManager.createDirectory(at: systemDir, withIntermediateDirectories: true, attributes: nil)

                // Move file to correct system directory
                let newURL = systemDir.appendingPathComponent(filename)
                try fileManager.moveItem(at: rootFileURL, to: newURL)

                // Update database with new path
//                try realm.write {
//                    game.file?.url = newURL
//                }

                movedFiles.insert(filename)
            }
        }

        // Clean up any remaining files in root that aren't associated with games
        for rootFile in rootFiles {
            let filename = rootFile.lastPathComponent
            if !movedFiles.contains(filename) {
                // Check file extension against all system supported extensions
                let ext = rootFile.pathExtension.lowercased()
                for (systemId, system) in RomDatabase.systemCache {
                    if system.supportedExtensions.contains(ext) {
                        // Move to appropriate system directory
                        let systemDir = romsRootDir.appendingPathComponent(systemId)
                        try fileManager.createDirectory(at: systemDir, withIntermediateDirectories: true, attributes: nil)
                        let newURL = systemDir.appendingPathComponent(filename)
                        try fileManager.moveItem(at: rootFile, to: newURL)
                        break
                    }
                }
            }
        }
    }
}

// Add this extension to support chunking
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


extension PVGameLibrary {
    public enum MigrationEvent {
        case starting
        case pathsToImport(paths: [URL])
    }

    public enum MigrationError: Error {
        case unableToCreateRomsDirectory(error: Error)
        case unableToGetContentsOfDocuments(error: Error)
        case unableToGetRomPaths(error: Error)
    }

    // This method is probably outdated
    public func migrate(fileManager: FileManager = .default) async -> Observable<MigrationEvent> {

        let libraryPath: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let libraryURL = URL(fileURLWithPath: libraryPath)
        let toDelete = ["PVGame.sqlite", "PVGame.sqlite-shm", "PVGame.sqlite-wal"].map { libraryURL.appendingPathComponent($0) }

        let deleteDatabase = Completable
            .concat(toDelete
                        .map { path in
                            fileManager.rx
                                .removeItem(at: path)
                                .catch { error in
                                    ILOG("Unable to delete \(path) because \(error.localizedDescription)")
                                    return .empty()
                                }
                        })

        let romsImportPath = Paths.romsImportPath
        let createDirectory = fileManager
            .rx
            .createDirectory(at: romsImportPath, withIntermediateDirectories: true, attributes: nil)
            .catch { .error(MigrationError.unableToCreateRomsDirectory(error: $0)) }

        // Move everything that isn't a realm file, into the the import folder so it wil be re-imported
        let moveFiles: Completable = fileManager.rx
            .contentsOfDirectory(at: URL.documentsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .catch { Single<[URL]>.error(MigrationError.unableToGetContentsOfDocuments(error: $0)) }
            .map({ contents -> [URL] in
                let ignoredExtensions = ["jpg", "png", "gif", "jpeg"]
                return contents.filter { (url) -> Bool in
                    let dbFile = url.path.lowercased().contains("realm")
                    let ignoredExtension = ignoredExtensions.contains(url.pathExtension)
                    var isDir: ObjCBool = false
                    let exists: Bool = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
                    return exists && !dbFile && !ignoredExtension && !isDir.boolValue
                }
            })
            .flatMapCompletable({ filesToMove -> Completable in
                let moves = filesToMove
                    .map { ($0, romsImportPath.appendingPathComponent($0.lastPathComponent))}
                    .map { path, toPath in
                        fileManager.rx.moveItem(at: path, to: toPath)
                            .catch({ error in
                                ELOG("Unable to move \(path.path) to \(toPath.path) because \(error.localizedDescription)")
                                return .empty()
                            })
                }
                return Completable.concat(moves)
            })

        let getRomPaths: Observable<MigrationEvent> = fileManager.rx
            .contentsOfDirectory(at: romsImportPath, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
            .catch { Single<[URL]>.error(MigrationError.unableToGetRomPaths(error: $0)) }
            .flatMapMaybe({ paths in
                if paths.isEmpty {
                    return .empty()
                } else {
                    return .just(.pathsToImport(paths: paths))
                }
            })
            .asObservable()

        return deleteDatabase
            .andThen(createDirectory)
            .andThen(moveFiles)
            .andThen(getRomPaths)
            .startWith(.starting)
    }
}

extension PVGameLibrary.MigrationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unableToCreateRomsDirectory(let error):
            return "Unable to create roms directory, error: \(error.localizedDescription)"
        case .unableToGetContentsOfDocuments(let error):
            return "Unable to get contents of directory, error: \(error.localizedDescription)"
        case .unableToGetRomPaths(let error):
            return "Unable to get rom paths, error: \(error.localizedDescription)"
        }
    }
}

private extension Reactive where Base: FileManager {
    func removeItem(at path: URL) -> Completable {
        Completable.create { observer in
            do {
                if self.base.fileExists(atPath: path.path) {
                    try self.base.removeItem(at: path)
                }
                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    func createDirectory(at path: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) -> Completable {
        Completable.create { observer in
            do {
                if !self.base.fileExists(atPath: path.path) {
                    try self.base.createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
                }

                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    func contentsOfDirectory(at path: URL, includingPropertiesForKeys: [URLResourceKey]?, options: Base.DirectoryEnumerationOptions) -> Single<[URL]> {
        Single.create { observer in
            do {
                let urls = try self.base.contentsOfDirectory(at: path, includingPropertiesForKeys: includingPropertiesForKeys, options: options)
                observer(.success(urls))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    func moveItem(at path: URL, to destination: URL) -> Completable {
        Completable.create { observer in
            do {
                try self.base.moveItem(at: path, to: destination)
                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
}
