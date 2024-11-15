//
//  PVGameLibrary.swift
//  PVLibrary
//
//  Created by Dan Berglund on 2020-05-27.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import RxSwift
import RealmSwift
import RxRealm
import PVLogging
import PVRealm
@_exported public import PVSettings

public class PVGameLibrary<T> where T: DatabaseDriver {

    public struct System {
        public let identifier: String
        public let manufacturer: String
        public let shortName: String
        public let isBeta: Bool
        public let unsupported: Bool
        public let sortedGames: [T.GameType]
    }

    internal let database: RomDatabase
    internal let databaseDriver: T
    private let romMigrator: ROMLocationMigrator

    public init(database: RomDatabase) {
        self.database = database
        self.databaseDriver = .init(database: database)
        self.romMigrator = ROMLocationMigrator()

        // Kick off ROM migration
        Task {
            do {
                try await romMigrator.migrateIfNeeded()
                ILOG("ROM migration completed successfully")
            } catch {
                ELOG("ROM migration failed: \(error.localizedDescription)")
            }
        }
    }
}

public extension PVGameLibrary where T == RealmDatabaseDriver {
    func toggleFavorite(for game: PVGame) -> Completable {
        return databaseDriver.toggleFavorite(for: game)
    }
}

extension RealmSwift.LinkingObjects where Element: PVGame {
    func sorted(by sortOptions: SortOptions) -> Results<Element> {
        var sortDescriptors = [SortDescriptor(keyPath: #keyPath(PVGame.isFavorite), ascending: false)]
        switch sortOptions {
        case .title:
            break
        case .importDate:
            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.importDate), ascending: false))
        case .lastPlayed:
            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.lastPlayed), ascending: false))
        case .mostPlayed:
            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false))
        }

        sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: true))
        return sorted(by: sortDescriptors)
    }
}

extension Array where Element == PVGameLibrary<RealmDatabaseDriver>.System {
    func sorted(by sortOptions: SortOptions) -> [Element] {
        let titleSort: (Element, Element) -> Bool = { (s1, s2) -> Bool in
            let mc = s1.manufacturer.compare(s2.manufacturer)
            if mc == .orderedSame {
                return s1.shortName.compare(s2.shortName) == .orderedAscending
            } else {
                return mc == .orderedAscending
            }
        }

        switch sortOptions {
        case .title:
            return sorted(by: titleSort)
        case .lastPlayed:
            return sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.sortedGames.first?.lastPlayed
                let l2 = s2.sortedGames.first?.lastPlayed

                if let l1 = l1, let l2 = l2 {
                    return l1.compare(l2) == .orderedDescending
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        case .importDate:
            return sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.sortedGames.first?.importDate
                let l2 = s2.sortedGames.first?.importDate

                if let l1 = l1, let l2 = l2 {
                    return l1.compare(l2) == .orderedDescending
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        case .mostPlayed:
            return sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.sortedGames.first?.playCount
                let l2 = s2.sortedGames.first?.playCount

                if let l1 = l1, let l2 = l2 {
                    return l1 < l2
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        }
    }
}

/// Handles migration of ROM files from old documents directory to new shared container directory
public final class ROMLocationMigrator {
    private let fileManager = FileManager.default

    /// Old path where ROMs were stored
    private var oldROMsPath: URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: documentsPath).appendingPathComponent("ROMs")
    }

    /// New path where ROMs should be stored
    private var newROMsPath: URL {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)!
            .appendingPathComponent("Documents")
            .appendingPathComponent("ROMs")
    }

    /// Migrates ROMs from old location to new location if necessary
    public func migrateIfNeeded() async throws {
        ILOG("Checking if ROM migration is needed...")

        // Check if old directory exists and has contents
        guard fileManager.fileExists(atPath: oldROMsPath.path) else {
            ILOG("No old ROMs directory found, skipping migration")
            return
        }

        if !fileManager.fileExists(atPath: newROMsPath.path) {
            // Create new directory if it doesn't exist
            try fileManager.createDirectory(at: newROMsPath,
                                         withIntermediateDirectories: true,
                                         attributes: nil)
        }

        try await migrateDirectory(from: oldROMsPath, to: newROMsPath)
    }

    /// Recursively migrates contents of a directory
    private func migrateDirectory(from sourceDir: URL, to destDir: URL) async throws {
        ILOG("Migrating directory: \(sourceDir.lastPathComponent)")

        // Get all items in source directory
        let contents = try fileManager.contentsOfDirectory(
            at: sourceDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        ILOG("Found \(contents.count) items to process in \(sourceDir.lastPathComponent)")

        try await withThrowingTaskGroup(of: Void.self) { group in
            for itemURL in contents {
                group.addTask {
                    let isDirectory = try itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
                    let relativePath = itemURL.lastPathComponent
                    let destinationURL = destDir.appendingPathComponent(relativePath)

                    if isDirectory {
                        // Create destination directory if it doesn't exist
                        if !self.fileManager.fileExists(atPath: destinationURL.path) {
                            try self.fileManager.createDirectory(at: destinationURL,
                                                              withIntermediateDirectories: true,
                                                              attributes: nil)
                        }
                        // Recursively migrate contents of subdirectory
                        try await self.migrateDirectory(from: itemURL, to: destinationURL)

                        // Try to remove empty source directory
                        if try self.fileManager.contentsOfDirectory(atPath: itemURL.path).isEmpty {
                            try await self.fileManager.removeItem(at: itemURL)
                            ILOG("Removed empty directory: \(itemURL.lastPathComponent)")
                        }
                    } else {
                        // Handle file migration
                        if self.fileManager.fileExists(atPath: destinationURL.path) {
                            ILOG("Skipping \(relativePath) as it already exists in destination")
                        } else {
                            try self.fileManager.moveItem(at: itemURL, to: destinationURL)
                            ILOG("Successfully migrated: \(relativePath)")
                        }
                    }
                }
            }

            try await group.waitForAll()
        }

        // Try to remove source directory if empty
        if sourceDir == oldROMsPath {
            do {
                let remainingItems = try fileManager.contentsOfDirectory(
                    at: sourceDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                if remainingItems.isEmpty {
                    try await fileManager.removeItem(at: sourceDir)
                    ILOG("Removed empty old ROMs directory")
                }
            } catch {
                ELOG("Error cleaning up old ROMs directory: \(error.localizedDescription)")
            }
        }
    }
}
