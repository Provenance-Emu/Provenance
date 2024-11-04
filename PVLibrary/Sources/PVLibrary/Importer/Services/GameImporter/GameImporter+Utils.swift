//
//  GameImporter+Utils.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//


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
    
    /// Checks if a given ROM file is a CD-ROM
    internal func isCDROM(_ romFile: ImportCandidateFile) -> Bool {
        return isCDROM(romFile.filePath)
    }
    
    /// Checks if a given path is a CD-ROM
    internal func isCDROM(_ path: URL) -> Bool {
        let cdromExtensions: Set<String> = Extensions.discImageExtensions.union(Extensions.playlistExtensions)
        let fileExtension = path.pathExtension.lowercased()
        return cdromExtensions.contains(fileExtension)
    }
    
    /// Checks if a given path is artwork
    package func isArtwork(_ path: URL) -> Bool {
        let artworkExtensions = Extensions.artworkExtensions
        let fileExtension = path.pathExtension.lowercased()
        return artworkExtensions.contains(fileExtension)
    }
}
