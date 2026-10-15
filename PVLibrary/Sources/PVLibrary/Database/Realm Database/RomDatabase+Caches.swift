//
//  RomDatabase+Caches.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/26/24.
//

import PVRealm
import Foundation
import PVFileSystem
import PVLogging
import PVLookup
import PVSystems
import AsyncAlgorithms
import RealmSwift

public extension RomDatabase {

    // MARK: - Reloads


    /// Reload all caches
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadCaches(force: Bool = false) async {
//        Task {
            self.reloadSystemsCache(force: force)
            self.reloadBIOSCache()
            self.reloadCoresCache(force: force)
            self.reloadGamesCache(force: force)
//        }
    }

    /// Refreash Realm and reload caches
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadCache(force: Bool = false) async {
        VLOG("RomDatabase:reloadCache")
        self.refresh()
        await self.reloadCaches(force: force)
    }

    // MARK: - BIOS Cache

    // Internal storage
    internal static var _biosFilenamesCache: Set<String>?

    // Public interface
    static var biosFilenamesCache: Set<String> {
        guard let cache = _biosFilenamesCache else {
            reloadBIOSFilenamesCache()
            return biosFilenamesCache
        }
        return cache
    }

    // Internal helper
    internal static func reloadBIOSFilenamesCache() {
        let realm = try! Realm()
        let biosEntries = realm.objects(PVBIOS.self)
        _biosFilenamesCache = Set(biosEntries.map { $0.expectedFilename.lowercased() })
        ILOG("Reloaded BIOS filenames cache with \(_biosFilenamesCache?.count ?? 0) entries")
    }

    /// Reloads all BIOS-related caches
    @objc static func reloadBIOSCache() {
        reloadBIOSFilenamesCache()

        var files:[String:[String]] = [:]
        systemCache.values.forEach { system in
            files = addFileSystemBIOSCache(system, files:files)
        }
        _biosCache = files

        ILOG("All BIOS caches reloaded")
    }

    /// Reload Cores cache
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadCoresCache(force: Bool = false) {
        let cores = PVCore.all.toArray()

        if cores.count == _coreCache?.count, !cores.isEmpty, !force {
            ILOG("Skipping reload cores cache, not required for forced")
            return
        }
        _coreCache = cores.reduce(into: [:]) {
            dbCore, core in
            dbCore[core.identifier] = core.detached()
        }
    }

    /// Reload Systems cache
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadSystemsCache(force: Bool = false) {
        let systems = PVSystem.all.toArray()

        ILOG("Current systems count: \(systems.count)")

        if systems.count == _systemCache?.count && !systems.isEmpty && !force {
            ILOG("Skipping reload system cache, not required for forced")
            return
        }

        let cache = systems.reduce(into: [:]) {
            dbSystem, system in
            dbSystem[system.identifier] = system.detached()
        }
        _systemCache = cache
    }
    static func reloadGamesCache(force: Bool = false) {
        let games = PVGame.all.toArray()

        if games.count == _gamesCache?.count && !games.isEmpty && !force {
            ILOG("Skipping reload games cache, not required for forced")
            return
        }

        _gamesCache = games.reduce(into: [:]) {
            dbGames, game in
            dbGames = addGameCache(game, cache: dbGames)
        }
    }
    static func addGameCache(_ game:PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        // Ensure we work with a frozen copy to avoid thread issues
        let frozenGame = game.isFrozen ? game : game.freeze()
        var cache:[String:PVGame] = cache
        frozenGame.relatedFiles.forEach {
            relatedFile in
            if let url = relatedFile.url {
                cache = addRelativeFileCache(url, game:frozenGame, cache:cache)
            }
        }
        cache[frozenGame.romPath] = frozenGame.detached()
        if let url = frozenGame.file?.url {
            cache[altName(url, systemIdentifier: frozenGame.systemIdentifier)] = frozenGame.detached()
        }
        return cache
    }
    static func addRelativeFileCache(_ file:URL, game: PVGame) async {
        if let cache = _gamesCache {
            _gamesCache = addRelativeFileCache(file, game: game, cache: cache)
        }
    }
    static func addRelativeFileCache(_ file:URL, game: PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        var cache = cache
        cache[romPath(for: file, systemIdentifier: game.systemIdentifier)] = game.detached()
        cache[altName(file, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    static func addGamesCache(_ game:PVGame) {
        Task {
            if await RomDatabase.gamesCache == nil {
                await self.reloadCache()
            }
            _gamesCache = await addGameCache(game, cache: RomDatabase.gamesCache ?? [:])
        }
    }

    /// Synchronously adds a game to the cache (useful when moving games between systems)
    /// - Parameter game: The game to add to the cache
    static func addGameToCache(_ game: PVGame) {
        guard var cache = _gamesCache else {
            // Cache doesn't exist, use async version to initialize it
            addGamesCache(game)
            return
        }
        _gamesCache = addGameCache(game, cache: cache)
    }

    /// Removes a game from the games cache without reloading the entire cache
    /// - Parameter game: The game to remove from the cache
    static func removeGameFromCache(_ game: PVGame) {
        DLOG("Removing game from cache: \(game.title)")
        guard var cache = _gamesCache else {
            // Cache doesn't exist, nothing to remove
            return
        }

        // Remove the main entry for the game's ROM path
        cache.removeValue(forKey: game.romPath)

        // Remove any entries for the game's file URL
        if let url = game.file?.url {
            cache.removeValue(forKey: altName(url, systemIdentifier: game.systemIdentifier))
        }

        // Remove any entries for related files
        game.relatedFiles.forEach { relatedFile in
            if let url = relatedFile.url {
                cache.removeValue(forKey: romPath(for: url, systemIdentifier: game.systemIdentifier))
                cache.removeValue(forKey: altName(url, systemIdentifier: game.systemIdentifier))
            }
        }

        // Update the cache
        _gamesCache = cache
    }

    /// Removes cache entries for a game using old values (useful when moving games between systems)
    /// - Parameters:
    ///   - oldRomPath: The old ROM path that was in the cache
    ///   - oldSystemIdentifier: The old system identifier
    ///   - oldFileURL: The old file URL (optional)
    ///   - oldRelatedFiles: The old related files (optional)
    static func removeGameFromCache(oldRomPath: String, oldSystemIdentifier: String, oldFileURL: URL? = nil, oldRelatedFiles: [URL] = []) {
        DLOG("Removing game from cache using old values: romPath=\(oldRomPath), system=\(oldSystemIdentifier)")
        guard var cache = _gamesCache else {
            return
        }

        // Remove the main entry for the old ROM path
        cache.removeValue(forKey: oldRomPath)

        // Remove any entries for the old file URL
        if let oldURL = oldFileURL {
            cache.removeValue(forKey: altName(oldURL, systemIdentifier: oldSystemIdentifier))
        }

        // Remove any entries for old related files
        oldRelatedFiles.forEach { url in
            cache.removeValue(forKey: romPath(for: url, systemIdentifier: oldSystemIdentifier))
            cache.removeValue(forKey: altName(url, systemIdentifier: oldSystemIdentifier))
        }

        // Update the cache
        _gamesCache = cache
    }
    /// `<system>/<name without disc numbers>`; for a file in a multi-file set's own folder,
    /// `<system>/<set folder>/<name>`, so two sets with the same index name never share a key.
    static func altName(_ romPath:URL, systemIdentifier:String) -> String {
        var similarName = romPath.deletingPathExtension().lastPathComponent
        similarName = PVEmulatorConfiguration.stripDiscNames(fromFilename: similarName)
        return (romDirectoryKey(for: romPath, systemIdentifier: systemIdentifier) as NSString).appendingPathComponent(similarName)
    }

    static func altName(_ romPath:URL, systemIdentifier:SystemIdentifier) -> String {
        altName(romPath, systemIdentifier: systemIdentifier.rawValue)
    }

    /// `PVGame.romPath` for a file: `<system>/<file>`, or `<system>/<set folder>/<file>` for a
    /// file in a multi-file set's own folder (`MultiFileSetFolder`).
    static func romPath(for url: URL, systemIdentifier: String) -> String {
        (romDirectoryKey(for: url, systemIdentifier: systemIdentifier) as NSString).appendingPathComponent(url.lastPathComponent)
    }

    /// `<system>`, or `<system>/<set folder>` when `url` sits in a set folder of that system.
    private static func romDirectoryKey(for url: URL, systemIdentifier: String) -> String {
        guard let location = MultiFileSetFolder.romLocation(of: url),
              let folder = location.setFolder,
              location.systemIdentifier == systemIdentifier else {
            return systemIdentifier
        }
        return (systemIdentifier as NSString).appendingPathComponent(folder)
    }

    static func reloadFileSystemROMCache() {
        ILOG("RomDatabase: reloadFileSystemROMCache")
        var files:[URL:PVSystem]=[:]
        systemCache.values.forEach { system in
            files = addFileSystemROMCache(system, files:files)
        }
        _fileSystemROMCache = files
    }

    static func addFileSystemROMCache(_ system:PVSystem, files:[URL:PVSystem]) -> [URL:PVSystem] {
        var files = files
        let systemDir = system.romsDirectory
        if !FileManager.default.fileExists(atPath: systemDir.path) {
            do {
                try FileManager.default.createDirectory(atPath: systemDir.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog(error.localizedDescription)
            }
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: systemDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
              !contents.isEmpty else {
            return files
        }
        let detachedSystem = system.detached()
        let isDirectory = { (url: URL) in (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        contents
            .filter { system.extensions.contains($0.pathExtension) && !(isDirectory($0) && MultiFileSetPlacement.isSetFolder($0)) }
            .forEach {
                file in
                files[file] = detachedSystem
            }
        // Multi-file sets live in a folder of their own; a folder that is itself a game
        // (DOS, an unpacked MAME set) is not looked into.
        let gameFolders = Set((_gamesCache ?? [:]).values.filter { $0.systemIdentifier == system.identifier }.map { $0.romPath.lowercased() })
        MultiFileSetPlacement.indexFilesInSetFolders(of: systemDir)
            .filter { system.extensions.contains($0.pathExtension) || system.extensions.contains($0.pathExtension.lowercased()) }
            .filter { !gameFolders.contains(romPath(for: $0.deletingLastPathComponent(), systemIdentifier: system.identifier).lowercased()) }
            .forEach { files[$0] = detachedSystem }
        return files
    }

    static func addFileSystemROMCache(_ system:PVSystem) {
        Task {
            _fileSystemROMCache = addFileSystemROMCache(system, files:RomDatabase.fileSystemROMCache)
        }
    }

    static func getFileSystemROMCache(for system: PVSystem) -> [URL:PVSystem] {
        if RomDatabase.fileSystemROMCache == nil {
            self.reloadFileSystemROMCache()
        }
        var files:[URL:PVSystem] = [:]

        fileSystemROMCache.forEach({
            key, value in
            if value.identifier == system.identifier {
                files[key]=system
            }
        })
        return files
    }

    static func reloadArtDBCache() {
        VLOG("RomDatabase:reloadArtDBCache")
        if RomDatabase._artMD5DBCache != nil && RomDatabase._artFileNameToMD5Cache != nil {
            ILOG("RomDatabase:reloadArtDBCache:Cache Found, Skipping Data Reload")
            return
        }

        Task {
            do {
                let mappings = try await PVLookup.shared.getArtworkMappings()
                _artMD5DBCache = mappings.romMD5.mapValues { $0 as [String: AnyObject] }
                _artFileNameToMD5Cache = mappings.romFileNameToMD5
            } catch {
                _artMD5DBCache = [:]
                _artFileNameToMD5Cache = [:]
                ELOG("Failed to load artwork mappings: \(error.localizedDescription)")
            }
        }
    }

    static func getArtCache(_ md5: String, systemIdentifier: String) -> [String: AnyObject]? {
        if RomDatabase.artMD5DBCache.isEmpty || RomDatabase.artFileNameToMD5Cache.isEmpty {
            NSLog("RomDatabase:getArtCache:ArtCache not found, reloading")
            self.reloadArtDBCache()
        }

        if let systemID = PVEmulatorConfiguration.databaseID(forSystemID: systemIdentifier),
           let md5 = artFileNameToMD5Cache[String(systemID) + ":" + md5],
           let art = artMD5DBCache[md5] {
            return art
        }
        return nil
    }

    static func getArtCacheByFileName(_ filename:String, systemIdentifier:String) ->  [String: AnyObject]? {
        if RomDatabase.artMD5DBCache.isEmpty ||
            RomDatabase.artFileNameToMD5Cache.isEmpty{
            NSLog("RomDatabase:getArtCacheByFileName:ArtCache not found, reloading")
            self.reloadArtDBCache()
        }
        if  let systemID = PVEmulatorConfiguration.databaseID(forSystemID: systemIdentifier),
            let md5 = artFileNameToMD5Cache[String(systemID) + ":" + filename],
            let art = artMD5DBCache[md5] {
            return art
        }
        return nil
    }

    static func getArtCacheByFileName(_ filename:String) -> [String: AnyObject]? {
        if RomDatabase.artMD5DBCache.isEmpty || RomDatabase.artFileNameToMD5Cache.isEmpty {
            ILOG("RomDatabase:getArtCacheByFileName: ArtCache not found, reloading")
            self.reloadArtDBCache()
        }
        if let md5 = artFileNameToMD5Cache[filename],
           let art = artMD5DBCache[md5] {
            return art
        }
        return nil
    }
}

fileprivate extension RomDatabase {
    static func addFileSystemBIOSCache(_ system: PVSystem, files: [String:[String]]) -> [String:[String]] {
        var files = files
        let systemDir = system.biosDirectory
        if !FileManager.default.fileExists(atPath: systemDir.path) {
            do {
                try FileManager.default.createDirectory(atPath: systemDir.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG(error.localizedDescription)
            }
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
              !contents.isEmpty else {
            return files
        }
        contents
            .forEach {
                file in
                var bioses:[String]=files[system.identifier] ?? []
                bioses.append(system.identifier + "/" + file.lastPathComponent.lowercased())
                files[system.identifier] = bioses
            }
        return files
    }
}
