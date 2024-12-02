//
//  GameImporter+Utils.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//


extension GameImporter {
    
    
    /// Checks if a given ROM file is a CD-ROM
    internal func isCDROM(_ queueItem: ImportQueueItem) -> Bool {
        return isCDROM(queueItem.url)
    }
    
    /// Checks if a given path is a CD-ROM
    internal func isCDROM(_ path: URL) -> Bool {
        let cdromExtensions: Set<String> = Extensions.discImageExtensions.union(Extensions.playlistExtensions)
        let fileExtension = path.pathExtension.lowercased()
        return cdromExtensions.contains(fileExtension)
    }
    
    /// Checks if a given path is artwork
    internal func isArtwork(_ queueItem: ImportQueueItem) -> Bool {
        let artworkExtensions = Extensions.artworkExtensions
        let fileExtension = queueItem.url.pathExtension.lowercased()
        return artworkExtensions.contains(fileExtension)
    }
    
    internal func isBIOS(_ queueItem: ImportQueueItem) throws -> Bool {
        guard let md5 = queueItem.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }
        
        DLOG("Checking MD5: \(md5) for possible BIOS match")
        
        // First check if this is a BIOS file by MD5
        let biosMatches = PVEmulatorConfiguration.biosEntries.filter("expectedMD5 == %@", md5).map({ $0 })
        
        //it's a bios if it's md5 matches known BIOS
        return !biosMatches.isEmpty
    }
}
