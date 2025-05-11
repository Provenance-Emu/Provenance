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
        // First check if the file is already in a BIOS subdirectory
        let path = queueItem.url.path
        if path.contains("/BIOS/") {
            // If it's already in a BIOS directory, check if we already have a PVBIOS entry with a file for it
            let filename = queueItem.url.lastPathComponent.lowercased()
            
            // Check if any BIOS entry already has this file
            let biosEntries = PVEmulatorConfiguration.biosEntries
            let matchingEntries = biosEntries.filter { bios in
                // Check if the BIOS entry has a file and the filename matches
                if let file = bios.file {
                    return file.fileName.lowercased() == filename
                }
                return false
            }
            
            // If we found matching entries with files, don't add to import queue
            if !matchingEntries.isEmpty {
                ILOG("BIOS file \(filename) already has a PVBIOS entry with a file, skipping import")
                return false
            }
            
            // If we're in a BIOS directory but don't have a matching entry with a file, we should import it
            ILOG("BIOS file \(filename) is in BIOS directory but needs to be imported")
            return true
        }
        
        // Check by filename against our known BIOS filenames
        let filename = queueItem.url.lastPathComponent.lowercased()
        if RomDatabase.biosFilenamesCache.contains(filename) {
            DLOG("Found BIOS match by filename: \(queueItem.url.path(percentEncoded: false))")
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
