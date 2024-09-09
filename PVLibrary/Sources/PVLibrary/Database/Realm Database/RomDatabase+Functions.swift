//
//  RomDatabase+Functions.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import PVRealm
import Foundation
import PVLookup

public extension RomDatabase {
    func reloadCache() {
        NSLog("RomDatabase:reloadCache")
        self.refresh()
        reloadGamesCache()
        reloadSystemsCache()
        reloadCoresCache()
        reloadBIOSCache()
    }
    func reloadBIOSCache() {
        Task.detached(priority: .medium) { [self] in
            var files:[String:[String]]=[:]
            self.getSystemCache().values.forEach { system in
                files = addFileSystemBIOSCache(system, files:files)
            }
            RomDatabase.biosCache = files
        }
    }
    func addFileSystemBIOSCache(_ system:PVSystem, files:[String:[String]]) -> [String:[String]] {
        var files = files
        let systemDir = system.biosDirectory
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
            .forEach {
                file in
                var bioses:[String]=files[system.identifier] ?? []
                bioses.append(system.identifier + "/" + file.lastPathComponent.lowercased())
                files[system.identifier] = bioses
            }
        return files
    }
    
    func reloadCoresCache() {
        let cores = PVCore.all.toArray()
        RomDatabase.coreCache = cores.reduce(into: [:]) {
            dbCore, core in
            dbCore[core.identifier] = core.detached()
        }
    }
    func reloadSystemsCache() {
        let systems = PVSystem.all.toArray()
        RomDatabase.systemCache = systems.reduce(into: [:]) {
            dbSystem, system in
            dbSystem[system.identifier] = system.detached()
        }
    }
    func reloadGamesCache() {
        let games = PVGame.all.toArray()
        RomDatabase.gamesCache = games.reduce(into: [:]) {
            dbGames, game in
            dbGames = addGameCache(game, cache: dbGames)
        }
    }
    func addGameCache(_ game:PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        var cache:[String:PVGame] = cache
        game.relatedFiles.forEach {
            relatedFile in
            cache = addRelativeFileCache(relatedFile.url, game:game, cache:cache)
        }
        cache[game.romPath] = game.detached()
        cache[altName(game.file.url, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    func addRelativeFileCache(_ file:URL, game: PVGame) {
        if let cache = RomDatabase.gamesCache {
            RomDatabase.gamesCache = addRelativeFileCache(file, game: game, cache: cache)
        }
    }
    func addRelativeFileCache(_ file:URL, game: PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        var cache = cache
        cache[(game.systemIdentifier as NSString)
            .appendingPathComponent(file.lastPathComponent)] = game.detached()
        cache[altName(file, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    func addGamesCache(_ game:PVGame) {
        if RomDatabase.gamesCache == nil {
            self.reloadCache()
        }
        RomDatabase.gamesCache = addGameCache(game, cache: RomDatabase.gamesCache ?? [:])
    }
    func altName(_ romPath:URL, systemIdentifier:String) -> String {
        var similarName = romPath.deletingPathExtension().lastPathComponent
        similarName = PVEmulatorConfiguration.stripDiscNames(fromFilename: similarName)
        return (systemIdentifier as NSString).appendingPathComponent(similarName)
    }
    func getGamesCache() -> [String:PVGame] {
        if RomDatabase.gamesCache == nil {
            self.reloadCache()
        }
        if let gamesCache = RomDatabase.gamesCache {
            return gamesCache
        } else {
            reloadGamesCache()
            return RomDatabase.gamesCache ?? [:]
        }
    }
    func getSystemCache() -> [String:PVSystem] {
        if RomDatabase.systemCache == nil {
            self.reloadCache()
        }
        if let systemCache = RomDatabase.systemCache {
            return systemCache
        } else {
            reloadSystemsCache()
            return RomDatabase.systemCache ?? [:]
        }
    }
    func getCoreCache() -> [String:PVCore] {
        if RomDatabase.coreCache == nil {
            self.reloadCache()
        }
        if let coreCache = RomDatabase.coreCache {
            return coreCache
        } else {
            reloadCoresCache()
            return RomDatabase.coreCache ?? [:]
        }
    }
    func getBIOSCache() -> [String:[String]] {
        if let biosCache = RomDatabase.biosCache {
            return biosCache
        } else {
            reloadBIOSCache()
            return RomDatabase.biosCache ?? [:]
        }
    }
    func reloadFileSystemROMCache() {
        Task {
            ILOG("RomDatabase: reloadFileSystemROMCache")
            var files:[URL:PVSystem]=[:]
            getSystemCache().values.forEach { system in
                files = addFileSystemROMCache(system, files:files)
            }
            RomDatabase.fileSystemROMCache = files
        }
    }
    
    func addFileSystemROMCache(_ system:PVSystem, files:[URL:PVSystem]) -> [URL:PVSystem] {
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
    
    func addFileSystemROMCache(_ system:PVSystem) {
        Task {
            if let files = RomDatabase.fileSystemROMCache {
                RomDatabase.fileSystemROMCache = addFileSystemROMCache(system, files:files)
            }
        }
    }
    
    func getFileSystemROMCache() -> [URL:PVSystem] {
        if RomDatabase.fileSystemROMCache == nil {
            self.reloadFileSystemROMCache()
        }
        var files:[URL:PVSystem] = [:]
        if let fileCache = RomDatabase.fileSystemROMCache {
            files = fileCache
        }
        return files
    }

    func getFileSystemROMCache(for system: PVSystem) -> [URL:PVSystem] {
        if RomDatabase.fileSystemROMCache == nil {
            self.reloadFileSystemROMCache()
        }
        var files:[URL:PVSystem] = [:]
        if let fileCache = RomDatabase.fileSystemROMCache {
            fileCache.forEach({
                key, value in
                if value.identifier == system.identifier {
                    files[key]=system
                }
            })
        }
        return files
    }

    func reloadArtDBCache() {
        VLOG("RomDatabase:reloadArtDBCache")
        if RomDatabase.artMD5DBCache != nil && RomDatabase.artFileNameToMD5Cache != nil {
            ILOG("RomDatabase:reloadArtDBCache:Cache Found, Skipping Data Reload")
        }
        do {

            let openVGDB = OpenVGDB.init()
            let mappings = try openVGDB.getArtworkMappings()
            RomDatabase.artMD5DBCache = mappings.romMD5
            RomDatabase.artFileNameToMD5Cache = mappings.romFileNameToMD5
        } catch {
            NSLog("Failed to execute query: \(error.localizedDescription)")
        }
    }

    func getArtCache(_ md5:String) -> [String: AnyObject]? {
        if RomDatabase.artMD5DBCache == nil {
            NSLog("RomDatabase:getArtCache:Artcache not found reloading")
            self.reloadArtDBCache()
        }
        if let artCache = RomDatabase.artMD5DBCache,
           let art = artCache[md5] {
            return art
        }
        return nil
    }

    func getArtCache(_ md5:String, systemIdentifier:String) -> [String: AnyObject]? {
        if RomDatabase.artMD5DBCache == nil ||
            RomDatabase.artFileNameToMD5Cache == nil {
            NSLog("RomDatabase:getArtCache:ArtCache not found, reloading")
            self.reloadArtDBCache()
        }
        if let systemID = PVEmulatorConfiguration.databaseID(forSystemID: systemIdentifier),
           let artFile = RomDatabase.artFileNameToMD5Cache,
           let artCache = RomDatabase.artMD5DBCache,
           let md5 = artFile[String(systemID) + ":" + md5],
           let art = artCache[md5] {
            return art
        }
        return nil
    }

    func getArtCacheByFileName(_ filename:String, systemIdentifier:String) ->  [String: AnyObject]? {
        if RomDatabase.artMD5DBCache == nil ||
            RomDatabase.artFileNameToMD5Cache == nil {
            NSLog("RomDatabase:getArtCacheByFileName:ArtCache not found, reloading")
            self.reloadArtDBCache()
        }
        if  let systemID = PVEmulatorConfiguration.databaseID(forSystemID: systemIdentifier),
            let artFile = RomDatabase.artFileNameToMD5Cache,
            let artCache = RomDatabase.artMD5DBCache,
            let md5 = artFile[String(systemID) + ":" + filename],
            let art = artCache[md5] {
            return art
        }
        return nil
    }

    func getArtCacheByFileName(_ filename:String) -> [String: AnyObject]? {
        if RomDatabase.artMD5DBCache == nil || RomDatabase.artFileNameToMD5Cache == nil {
            NSLog("RomDatabase:getArtCacheByFileName: ArtCache not found, reloading")
            self.reloadArtDBCache()
        }
        if let artFile = RomDatabase.artFileNameToMD5Cache,
           let artCache = RomDatabase.artMD5DBCache,
           let md5 = artFile[filename],
           let art = artCache[md5] {
            return art
        }
        return nil
    }
}
