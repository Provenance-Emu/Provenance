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
    
    /// Checks if a given path is a Skin file by extension
    internal func isSkin(_ path: URL) -> Bool {
        let fileExtension = path.pathExtension.lowercased()
        return Extensions.skinExtensions.contains(fileExtension)
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

    internal func isBIOS(_ item: ImportQueueItem) -> Bool {
        let urlPath = item.url.path
        let filenameLowercased = item.url.lastPathComponent.lowercased()
        let md5Upper = item.md5?.uppercased()

        // 1. Check if the file is already in a known BIOS subdirectory
        //    and if it's already linked to an existing PVBIOS entry.
        //    Assumes PVBIOS has a `file: PVFile?` relationship.
        //    If a file is in /BIOS/ and already linked, it's a known BIOS but not a *new* one to import.
        //    If it's in /BIOS/ and *not* linked, it's a BIOS we should import.
        if urlPath.contains("/BIOS/") { // Consider making "/BIOS/" a configurable/constant path segment
            let existingLinkedBIOS = PVEmulatorConfiguration.biosEntries.first { biosFromDB in
                if let linkedFile = biosFromDB.file { // Check PVBIOS.file relationship
                    return linkedFile.fileName.lowercased() == filenameLowercased // Or more robust ID check
                }
                return false
            }

            if existingLinkedBIOS != nil {
                ILOG("BIOS file \(filenameLowercased) in /BIOS/ directory is already linked. Not flagging as new BIOS for import.")
                return false // Already accounted for, not a *new* BIOS import target via this check
            } else {
                ILOG("BIOS file \(filenameLowercased) in /BIOS/ directory, not linked. Flagging as BIOS for import.")
                return true // Is a BIOS file type, and needs to be processed/linked
            }
        }

        // 2. If not in /BIOS/ dir handled above, or needs further checking,
        //    iterate over all PVBIOS entries to match by expected filename or MD5.
        for biosEntry in PVEmulatorConfiguration.biosArray {
            // A. Check expected filename (case-insensitive)
            if biosEntry.expectedFilename.lowercased() == filenameLowercased {
                VLOG("BIOS match by expected filename: \(filenameLowercased)")
                return true
            }

            // B. Check expected MD5 (if item's MD5 is available and BIOS entry has an expected MD5)
            if let itemMD5 = md5Upper, !biosEntry.expectedMD5.isEmpty, biosEntry.expectedMD5.lowercased() == itemMD5.lowercased() {
                VLOG("BIOS match by MD5: \(itemMD5) for file: \(filenameLowercased)")
                return true
            }
        }

        VLOG("No BIOS match for file: \(filenameLowercased), MD5: \(md5Upper ?? "N/A")")
        return false
    }
}
