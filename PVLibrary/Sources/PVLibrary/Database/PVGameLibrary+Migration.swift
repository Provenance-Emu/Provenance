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

    /// Fixes files that were incorrectly placed in the root ROMs directory by matching them to existing games
    public func fixOrphanedFiles() async throws {
        DLOG("Starting fixOrphanedFiles")
        // Get the root ROMs directory
        let romsRootDir = Paths.romsPath
        let fileManager = FileManager.default

        DLOG("Scanning root ROMs directory: \(romsRootDir.path)")
        // Get list of files in root ROMs dir
        let rootFiles = try fileManager.contentsOfDirectory(at: romsRootDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { !$0.hasDirectoryPath } // Only look at files, not directories

        DLOG("Found \(rootFiles.count) files in root directory")

        // Get all games from the database
        let realm = RomDatabase.sharedInstance.realm
        let games = realm.objects(PVGame.self)
        DLOG("Found \(games.count) games in database")

        // Create lookup of filename -> [PVGame] for quick matching
        var gamesByFilename: [String: [PVGame]] = [:]
        for game in games {
            let filename = game.file?.url.lastPathComponent ?? ""
            if !filename.isEmpty {
                gamesByFilename[filename, default: []].append(game)
            }
        }
        DLOG("Created filename lookup with \(gamesByFilename.count) unique filenames")

        // Process each file in the root directory
        for rootFile in rootFiles {
            let filename = rootFile.lastPathComponent
            DLOG("Processing root file: \(filename)")

            // If we find matching games by filename
            if let matchingGames = gamesByFilename[filename] {
                DLOG("Found \(matchingGames.count) matching games for \(filename)")

                for game in matchingGames {
                    DLOG("Checking game: \(game.title) (System: \(game.systemIdentifier))")
                    guard let gameFile = game.file else {
                        DLOG("Game has no file record, skipping")
                        continue
                    }

                    // First check if the file exists at its expected location
                    DLOG("Checking if file exists at expected location: \(gameFile.url.path)")
                    if fileManager.fileExists(atPath: gameFile.url.path) {
                        DLOG("File already exists at expected location, skipping")
                        continue
                    }

                    // Get the correct system directory for this game
                    let systemDir = romsRootDir.appendingPathComponent(game.systemIdentifier)
                    let newURL = systemDir.appendingPathComponent(filename)
                    DLOG("Will try to move file to: \(newURL.path)")

                    do {
                        // Create system directory if needed
                        if !fileManager.fileExists(atPath: systemDir.path) {
                            DLOG("Creating system directory: \(systemDir.path)")
                            try fileManager.createDirectory(at: systemDir, withIntermediateDirectories: true, attributes: nil)
                        }

                        // Move the file
                        if !fileManager.fileExists(atPath: newURL.path) {
                            DLOG("Moving file from \(rootFile.path) to \(newURL.path)")
                            try fileManager.moveItem(at: rootFile, to: newURL)

                            // Update the game's file in the database with new relative path
                            let partialPath = "ROMs/\(game.systemIdentifier)/\(filename)"
                            DLOG("Updating database with new partial path: \(partialPath)")
                            try realm.write {
                                let newFile = PVFile(withPartialPath: partialPath)
                                game.file = newFile
                            }

                            ILOG("Successfully moved orphaned file \(filename) to system directory \(game.systemIdentifier)")
                            break // Stop after first matching game
                        } else {
                            DLOG("File already exists at destination: \(newURL.path)")
                        }
                    } catch {
                        ELOG("Error processing file \(filename): \(error.localizedDescription)")
                    }
                }
            } else {
                DLOG("No matching games found for \(filename), trying extension matching")
                // No matching game found - try to determine system by file extension
                let ext = rootFile.pathExtension.lowercased()
                DLOG("Checking extension '\(ext)' against system extensions")

                for (systemId, system) in RomDatabase.systemCache where system.supportedExtensions.contains(ext) {
                    DLOG("Found matching system \(systemId) for extension \(ext)")
                    // Found a matching system for this file extension
                    let systemDir = romsRootDir.appendingPathComponent(systemId)
                    let newURL = systemDir.appendingPathComponent(filename)

                    do {
                        if !fileManager.fileExists(atPath: newURL.path) {
                            DLOG("Moving unmatched file to \(newURL.path)")
                            try fileManager.createDirectory(at: systemDir, withIntermediateDirectories: true, attributes: nil)
                            try fileManager.moveItem(at: rootFile, to: newURL)
                            ILOG("Successfully moved unmatched file \(filename) to system directory \(systemId) based on extension")
                            break
                        } else {
                            DLOG("File already exists at destination: \(newURL.path)")
                        }
                    } catch {
                        ELOG("Error moving unmatched file \(filename): \(error.localizedDescription)")
                    }
                }
            }
        }
        DLOG("Completed fixOrphanedFiles")
    }

    /// Fixes PVFile partial paths that are missing the ROMs/ prefix
    public func fixPartialPaths() async throws {
        DLOG("Starting fixPartialPaths")

        let realm = RomDatabase.sharedInstance.realm
        let games = realm.objects(PVGame.self)
        DLOG("Found \(games.count) games to check")

        var fixCount = 0
        for game in games {
            guard let file = game.file else {
                DLOG("Game \(game.title) has no file, skipping")
                continue
            }

            let currentPath = file.relativePath
            DLOG("Checking path for game \(game.title): \(currentPath)")

            // Check if path needs fixing
            if !currentPath.hasPrefix("ROMs/") {
                // If it starts with the system ID, add ROMs/ prefix
                if currentPath.hasPrefix(game.systemIdentifier + "/") {
                    let newPath = "ROMs/" + currentPath
                    DLOG("Fixing path: \(currentPath) -> \(newPath)")

                    try realm.write {
                        let newFile = PVFile(withPartialPath: newPath)
                        game.file = newFile
                    }
                    fixCount += 1
                    ILOG("Fixed partial path for \(game.title)")
                } else {
                    // If it's just a filename, add full path
                    let newPath = "ROMs/\(game.systemIdentifier)/\(currentPath)"
                    DLOG("Fixing path: \(currentPath) -> \(newPath)")

                    try realm.write {
                        let newFile = PVFile(withPartialPath: newPath)
                        game.file = newFile
                    }
                    fixCount += 1
                    ILOG("Fixed partial path for \(game.title)")
                }
            } else {
                DLOG("Path already correct for \(game.title)")
            }
        }

        DLOG("Completed fixPartialPaths - fixed \(fixCount) paths")
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
