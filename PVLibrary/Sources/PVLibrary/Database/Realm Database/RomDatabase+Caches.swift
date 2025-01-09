//
//  RomDatabase+Caches.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/26/24.
//

import PVRealm
import Foundation
import PVLogging
import PVLookup
import PVSystems
import AsyncAlgorithms

public extension RomDatabase {

    // MARK: - Reloads


    /// Reload all caches
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadCaches(force: Bool = false) {
        Task {
            self.reloadSystemsCache(force: force)
            self.reloadBIOSCache()
            self.reloadCoresCache(force: force)
            self.reloadGamesCache(force: force)
        }
    }

    /// Refreash Realm and reload caches
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadCache(force: Bool = false) {
        VLOG("RomDatabase:reloadCache")
        self.refresh()
        self.reloadCaches(force: force)
    }

    /// Reload BIOS cache
    /// - Parameter force: force a reload even if cache sizes match
    static func reloadBIOSCache() {
        var files:[String:[String]]=[:]
        systemCache.values.forEach { system in
            files = addFileSystemBIOSCache(system, files:files)
        }
        _biosCache = files
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
        var cache:[String:PVGame] = cache
        game.relatedFiles.forEach {
            relatedFile in
            cache = addRelativeFileCache(relatedFile.url, game:game, cache:cache)
        }
        cache[game.romPath] = game.detached()
        cache[altName(game.file.url, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    static func addRelativeFileCache(_ file:URL, game: PVGame) async {
        if let cache = _gamesCache {
            _gamesCache = addRelativeFileCache(file, game: game, cache: cache)
        }
    }
    static func addRelativeFileCache(_ file:URL, game: PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        var cache = cache
        cache[(game.systemIdentifier as NSString)
            .appendingPathComponent(file.lastPathComponent)] = game.detached()
        cache[altName(file, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    static func addGamesCache(_ game:PVGame) {
        Task {
            if await RomDatabase.gamesCache == nil {
                self.reloadCache()
            }
            _gamesCache = await addGameCache(game, cache: RomDatabase.gamesCache ?? [:])
        }
    }
    static func altName(_ romPath:URL, systemIdentifier:String) -> String {
        var similarName = romPath.deletingPathExtension().lastPathComponent
        similarName = PVEmulatorConfiguration.stripDiscNames(fromFilename: similarName)
        return (systemIdentifier as NSString).appendingPathComponent(similarName)
    }
    
    static func altName(_ romPath:URL, systemIdentifier:SystemIdentifier) -> String {
        var similarName = romPath.deletingPathExtension().lastPathComponent
        similarName = PVEmulatorConfiguration.stripDiscNames(fromFilename: similarName)
        return (systemIdentifier.rawValue as NSString).appendingPathComponent(similarName)
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
        guard let contents = try? FileManager.default.contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
              !contents.isEmpty else {
            return files
        }
        contents
            .filter { system.extensions.contains($0.pathExtension) }
            .forEach {
                file in
                files[file] = system.detached()
            }
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
