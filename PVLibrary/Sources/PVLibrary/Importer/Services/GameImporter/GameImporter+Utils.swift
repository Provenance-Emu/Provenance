//
//  GameImporter+Utils.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import PVPatching

extension GameImporter {

    /// Checks if a given ROM file is a Skin file
    internal func isSkin(_ queueItem: ImportQueueItem) -> Bool {
        return isSkin(queueItem.url)
    }

    /// Checks if a given path is a Skin file or directory
    /// Supports both .deltaskin/.manicskin files and directories
    /// This function is designed to be fast and reliable, avoiding file system checks that might fail under race conditions
    internal func isSkin(_ path: URL) -> Bool {
        let fileExtension = path.pathExtension.lowercased()
        let fileName = path.lastPathComponent.lowercased()

        // Primary check: extension-based detection (fastest and most reliable)
        // This catches .deltaskin and .manicskin files immediately
        if Extensions.skinExtensions.contains(fileExtension) {
            return true
        }

        // Secondary check: filename suffix for directories
        // Only check if filename suggests it might be a skin directory
        if fileName.hasSuffix(".deltaskin") || fileName.hasSuffix(".manicskin") {
            // For directories, verify it's actually a directory
            // Use a more robust check that handles race conditions better
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory)

            // If file doesn't exist yet (race condition), assume it's a skin based on naming
            // This prevents false negatives when files are being written
            if !exists {
                // If the path suggests a skin directory but doesn't exist yet, still treat as skin
                // This handles the case where DirectoryWatcher detects files before they're fully written
                return true
            }

            // If it exists and is a directory, it's a skin
            if isDirectory.boolValue {
                return true
            }
        }

        return false
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

    /// Checks if a given import queue item is a DOSBox game folder
    internal func isDOSBoxFolder(_ queueItem: ImportQueueItem) -> Bool {
        return isDOSBoxFolder(queueItem.url)
    }

    /// Checks whether a URL points to a directory that looks like a DOSBox game.
    ///
    /// A folder is considered a DOSBox game folder when it is a directory and contains
    /// at least one of: `.conf`, `.exe`, `.bat`, or `.com` file at its root level.
    /// The presence of `dosbox.conf` in particular is a strong indicator.
    internal func isDOSBoxFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        let dosMarkerExtensions: Set<String> = ["conf", "exe", "bat", "com"]
        return contents.contains { fileURL in
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  resourceValues.isRegularFile == true else {
                return false
            }
            return dosMarkerExtensions.contains(fileURL.pathExtension.lowercased())
        }
    /// Returns the `PatchFormat` for the item's file extension, or `nil` if not a patch.
    internal func patchFormat(for item: ImportQueueItem) -> PatchFormat? {
        PatchFormat.detect(from: item.url)
    }

    /// Returns `true` if the item has a recognised ROM-patch file extension.
    internal func isPatch(_ item: ImportQueueItem) -> Bool {
        patchFormat(for: item) != nil
    }

    internal func isBIOS(_ item: ImportQueueItem) -> Bool {
        let urlPath = item.url.path
        let filenameLowercased = item.url.lastPathComponent.lowercased()
        // NOTE: DO NOT compute MD5 upfront - it's expensive and blocks the main thread
        // MD5 is only needed in step 3 if faster checks fail

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

        // 2. Fast-path: Check BIOS filenames cache first (case-insensitive Set lookup)
        //    This is much faster than iterating through biosArray and uses the cache loaded at bootup
        if RomDatabase.biosFilenamesCache.contains(filenameLowercased) {
            VLOG("BIOS match by filename cache: \(filenameLowercased)")
            return true
        }

        // 3. Check MD5 against BIOS entries if available (slower, but needed for files with different names)
        //    SKIP this expensive check for files that are clearly NOT BIOS:
        //    - Files larger than 16MB (BIOS files are typically small, < 4MB)
        //    - Files with extensions that are clearly ROMs (.chd, .iso, .rvz, .wbfs, etc.)
        let fileExtension = item.url.pathExtension.lowercased()
        let largeROMExtensions = Set(["chd", "iso", "rvz", "wbfs", "gcz", "nkit", "wad", "cia", "3ds", "nsp", "xci", "pkg"])
        if largeROMExtensions.contains(fileExtension) {
            VLOG("Skipping MD5 BIOS check for large ROM format: \(filenameLowercased)")
            return false
        }

        // Check file size - skip MD5 for files larger than 16MB
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: item.url.path)[.size] as? Int64,
           fileSize > 16 * 1024 * 1024 {
            VLOG("Skipping MD5 BIOS check for large file (\(fileSize) bytes): \(filenameLowercased)")
            return false
        }

        // Only compute MD5 for small files that could potentially be BIOS
        // This is the expensive operation - only do it for files that passed the size check
        if let itemMD5 = item.md5?.uppercased() {
            for biosEntry in PVEmulatorConfiguration.biosArray {
                if !biosEntry.expectedMD5.isEmpty, biosEntry.expectedMD5.uppercased() == itemMD5 {
                    VLOG("BIOS match by MD5: \(itemMD5) for file: \(filenameLowercased)")
                    return true
                }
            }
        }

        VLOG("No BIOS match for file: \(filenameLowercased)")
        return false
    }
}
