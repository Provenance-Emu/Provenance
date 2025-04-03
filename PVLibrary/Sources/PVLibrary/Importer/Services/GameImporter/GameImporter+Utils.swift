//
//  GameImporter+Utils.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//


extension GameImporter {


    /// Checks if a given ROM file is a Skin file
    internal func isSkin(_ queueItem: ImportQueueItem) -> Bool {
        return isSkin(queueItem.url)
    }
    
    /// Checks if a given path is a Sk file
    internal func isSkin(_ path: URL) -> Bool {
        let cdromExtensions: Set<String> = Extensions.skinExtensions.union(Extensions.playlistExtensions)
        let fileExtension = path.pathExtension.lowercased()
        return cdromExtensions.contains(fileExtension)
    }
    
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

    internal func isBIOS(_ queueItem: ImportQueueItem) -> Bool {
        // First check by filename
        let filename = queueItem.url.lastPathComponent.lowercased()
        if RomDatabase.biosFilenamesCache.contains(filename) {
            DLOG("Found BIOS match by filename: \(filename)")
            return true
        }

        // Then check by MD5 if available
        if let md5 = queueItem.md5?.uppercased() {
            DLOG("Checking MD5: \(md5) for possible BIOS match")
            let biosMatches = PVEmulatorConfiguration.biosEntries.filter("expectedMD5 == %@", md5).map({ $0 })
            if !biosMatches.isEmpty {
                return true
            }
        }

        return false
    }
}
