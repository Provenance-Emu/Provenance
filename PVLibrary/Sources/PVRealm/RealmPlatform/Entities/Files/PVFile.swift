//
//  PVFile.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging
#if canImport(UIKit)
import UIKit
#endif
import PVPrimitives
import PVFileSystem
import PVSettings

@objcMembers
public class PVFile: Object, LocalFileProvider, Codable, DomainConvertibleType {
    public typealias DomainType = LocalFile

    nonisolated(unsafe)
    public dynamic var partialPath: String = ""
    nonisolated(unsafe)
    public internal(set) dynamic var md5Cache: String?
    //    @objc private dynamic var crcCache: String?
    nonisolated(unsafe)
    public private(set) dynamic var createdDate = Date()
    nonisolated(unsafe)
    internal dynamic var _relativeRoot: Int = RelativeRoot.documents.rawValue

    /// Cache the file size to avoid frequent disk access
    nonisolated(unsafe)
    internal dynamic var sizeCache: Int = 0

    /// Last time size was checked
    nonisolated(unsafe)
    internal dynamic var lastSizeCheck: Date?
    nonisolated(unsafe)
    internal var _actualPartialPath: String?

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault, size: Int = 0, md5: String? = nil) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
        self.md5Cache = md5
        if size > 0 {
            self.sizeCache = size
            self.lastSizeCheck = Date()
        }
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault, size: Int = 0, md5: String? = nil) {
        self.init()
        self.relativeRoot = relativeRoot
        //TODO: this isn't working to get the partial path in all cases
        partialPath = relativeRoot.createRelativePath(fromURL: url)
        self.md5Cache = md5
        if size > 0 {
            self.sizeCache = size
            self.lastSizeCheck = Date()
        }
    }

    public override static func ignoredProperties() -> [String] {
        return ["lastSizeCheck", "_actualPartialPath"]
    }
}

public extension PVFile {

    nonisolated(unsafe)
    internal(set) var relativeRoot: RelativeRoot {
        get {
            return RelativeRoot(rawValue: _relativeRoot)!
        } set {
            _relativeRoot = newValue.rawValue
        }
    }

    /// Get the real path for this file based on the current iCloud sync mode
    /// This handles the differences between CloudKit and iCloud Drive paths
    var realPath: URL {
        let fixedPartialPath = actualPartialPath
        let syncMode = Defaults[.iCloudSyncMode]

        // If we're using CloudKit, use the local documents directory
        if syncMode.isCloudKit {
            #if os(tvOS)
            return RelativeRoot.cachesDirectory.appendingPathComponent(fixedPartialPath)
            #else
            return RelativeRoot.documentsDirectory.appendingPathComponent(fixedPartialPath)
            #endif
        }

        // For iCloud Drive, use the iCloud container if available.
        // IMPORTANT: avoid filesystem hits from rendering-time URL resolution.
        if let iCloudContainer = URL.iCloudContainerDirectory {
            return iCloudContainer.appendingPathComponent(fixedPartialPath)
        }

        // Fallback to the local documents directory
        #if os(tvOS)
        return RelativeRoot.cachesDirectory.appendingPathComponent(fixedPartialPath)
        #else
        return RelativeRoot.documentsDirectory.appendingPathComponent(fixedPartialPath)
        #endif
    }

    /// attempts to fix `partialPath`
    var actualPartialPath: String {
        if let fixedPartialPath = _actualPartialPath {
            return fixedPartialPath
        }
        var mutatingPartialPath = partialPath

        // Fast-path: in SwiftUI rendering hot paths, avoid repeated full-string scans.
        // Most values are already clean relative paths ("Save States/...", "ROMs/...", etc).
        // Only run the fixup logic when the string *starts* like a known-bad format.
        if let firstByte = mutatingPartialPath.utf8.first {
            switch firstByte {
            case UInt8(ascii: "/"), // absolute path
                 UInt8(ascii: "f"), // "file://..."
                 UInt8(ascii: "p"), // "private/..."
                 UInt8(ascii: "v"), // "var/mobile/..."
                 UInt8(ascii: "D"), // "Documents/..."
                 UInt8(ascii: "C"), // "Caches/..." / "Containers/..."
                 UInt8(ascii: "i"): // "iCloud..."
                break
            default:
                _actualPartialPath = mutatingPartialPath
                return mutatingPartialPath
            }
        }

        // Fix common path issues
        fixPartialPath(substring: "file:///private/", &mutatingPartialPath)
        fixPartialPath(substring: "file:///", &mutatingPartialPath)
        fixPartialPath(substring: "private/", &mutatingPartialPath)

        // Remove document directory paths (use cached URLs; avoid Foundation URL.documentsDirectory and iCloudDocumentsDirectory side effects)
        fixPartialPath(remove: URL.documentsPath, &mutatingPartialPath)

        // Don't call URL.iCloudDocumentsDirectory here (it can touch the filesystem / create dirs).
        let iCloudDocumentsNoCreate = URL.iCloudContainerDirectory?.appendingPathComponent("Documents")
        fixPartialPath(remove: iCloudDocumentsNoCreate, &mutatingPartialPath)
        fixPartialPath(remove: URL.iCloudContainerDirectory, &mutatingPartialPath)

        // Check if this looks like an absolute path from a different app bundle
        // (e.g., /var/mobile/Containers/Data/Application/.../Documents/...)
        // Check for app bundle paths with or without leading slash, and anywhere in the string
        let containsAppBundlePath = mutatingPartialPath.contains("/var/mobile/") ||
                                   mutatingPartialPath.contains("var/mobile/") ||
                                   mutatingPartialPath.contains("/private/var/mobile/") ||
                                   mutatingPartialPath.contains("private/var/mobile/") ||
                                   mutatingPartialPath.contains("/Containers/Data/Application/") ||
                                   mutatingPartialPath.contains("Containers/Data/Application/")

        if containsAppBundlePath {
            // Try to extract relative path by finding common directory patterns
            let pathComponents = (mutatingPartialPath as NSString).pathComponents

            // Extract relative path starting from "Documents" or "Caches" to preserve "Save States" folder
            // This ensures paths like "Documents/Save States/Game/file.svs" are preserved correctly
            if let documentsIndex = pathComponents.firstIndex(where: {
                $0 == "Documents" || $0 == "Caches"
            }) {
                // Extract everything after "Documents" or "Caches" (includes "Save States" if present)
                let relativeComponents = Array(pathComponents[(documentsIndex + 1)...])
                mutatingPartialPath = relativeComponents.joined(separator: "/")
            } else if pathComponents.count >= 2 {
                // If we can't find a pattern, take the last two components (directory + filename)
                let relativeComponents = Array(pathComponents.suffix(2))
                mutatingPartialPath = relativeComponents.joined(separator: "/")
            } else {
                // Fallback: just the filename
                mutatingPartialPath = pathComponents.last ?? mutatingPartialPath
            }
        }

        // Fix any remaining issues with the path
        if mutatingPartialPath.hasPrefix("/") {
            mutatingPartialPath = String(mutatingPartialPath.dropFirst())
        }

        _actualPartialPath = mutatingPartialPath
        return mutatingPartialPath
    }

    /// tries to remove url from `partialPath`
    /// - Parameter optionalUrl: if nil, then does nothing
    internal func fixPartialPath(remove optionalUrl: URL?, _ mutatingPartialPath: inout String) {
        guard let url = optionalUrl
        else {
            return
        }
        let privatePrefix = "private/"
        fixPartialPath(remove: url, withPercentEncoded: true, &mutatingPartialPath)
        fixPartialPath(remove: url, withPercentEncoded: true, &mutatingPartialPath, prefix: privatePrefix)
        fixPartialPath(remove: url, withPercentEncoded: false, &mutatingPartialPath)
        fixPartialPath(remove: url, withPercentEncoded: false, &mutatingPartialPath, prefix: privatePrefix)
    }

    /// if `partialPath` contains `url.path` with the given percent encoding, then it replaces it with an empty string
    /// - Parameters:
    ///   - url: url to find within `partialPath`
    ///   - percentEncoded: whether or not to add percent encoding
    ///   - prefix: optional prefix to do a search on
    internal func fixPartialPath(remove url: URL, withPercentEncoded percentEncoded: Bool, _ mutatingPartialPath: inout String, prefix: String = "") {
        var suffix = url.path(percentEncoded: percentEncoded)
        if suffix.hasPrefix("/") {
            //remove the first character
            suffix = String(suffix.suffix(from: suffix.index(after: suffix.startIndex)))
        }
        //ensure the prefix isn't already contained
        let actualPrefix = suffix.starts(with: prefix) ? "" : prefix
        let substring = "\(actualPrefix)\(suffix)"
        fixPartialPath(substring: substring, &mutatingPartialPath)
        /*DLOG("""
        prefix: \(prefix)
        actualPrefix: \(actualPrefix)
        suffix: \(suffix)
        partialPath: \(mutatingPartialPath)
        """)*/
        guard prefix.isEmpty || !actualPrefix.isEmpty
        else {
            return
        }
        //remove the prefix if it exists already, so if suffix starts with "private/" and the prefix passed in is "private/", then we want to remove "private/" from the beginning of "suffix" and attempt to remove the new substring from mutatingPartialPath
        let newSubstring = String(suffix.suffix(from: suffix.index(suffix.startIndex, offsetBy: prefix.count)))
        fixPartialPath(substring: newSubstring, &mutatingPartialPath)
    }

    /// if `substring` exists in `partialPath`, then it removes it
    /// - Parameter substring: substring to test/remove
    internal func fixPartialPath(substring: String, _ mutatingPartialPath: inout String) {
        //DLOG("attempting to remove \(substring) from partialPath \(mutatingPartialPath)")
        if mutatingPartialPath.localizedCaseInsensitiveContains(substring) {
            mutatingPartialPath = mutatingPartialPath.replacingOccurrences(of: substring, with: "", options: .caseInsensitive)
            //DLOG("removed \(substring) and now partialPath is \(mutatingPartialPath)")
        }
    }

    /// Determines if this file requires syncing to iCloud
    /// Returns true if:
    /// 1. iCloud sync is enabled in settings
    /// 2. The file exists locally but not in iCloud
    var requiresSync: Bool {
        get {
            // Only check if iCloud sync is enabled
            let syncMode = Defaults[.iCloudSyncMode]
            let iCloudSync = Defaults[.iCloudSync]
            guard iCloudSync else {
                return false
            }

            // Check if the file exists locally
            guard let localURL = self.url, FileManager.default.fileExists(atPath: localURL.path) else {
                return false
            }

            // Check if the file exists in iCloud
            guard let iCloudURL = self.iCloudURL else {
                // If we can't determine the iCloud URL, assume sync is required
                return true
            }

            // If the file doesn't exist in iCloud, it requires sync
            return !FileManager.default.fileExists(atPath: iCloudURL.path)
        }
    }

    /// Returns the iCloud URL for this file if available
    var iCloudURL: URL? {
        get {
            guard let iCloudContainerURL = URL.iCloudContainerDirectory else {
                return nil
            }

            // Create the path relative to the iCloud container
            let relativePath = self.partialPath
            return iCloudContainerURL.appendingPathComponent(relativePath)
        }
    }
    var url: URL? {
        get {
            let isPartialPathFixed = _actualPartialPath != nil
            let ogPartialPath = partialPath
            var fixedPartialPath = actualPartialPath
            var returnUrl: URL
            var failedToFixPartialPath = false

            defer {
                if !isPartialPathFixed && failedToFixPartialPath {
                    ELOG("""
                    invalid partial path: \(fixedPartialPath)
                    original partialPath: \(ogPartialPath)
                    url generated: \(returnUrl)
                    relativeRoot: \(relativeRoot)
                    """)
                }
            }

            // Detect and trim erroneous app bundle paths (e.g., /var/mobile/Containers/Data/Application/.../Documents/...)
            // This handles cases where an absolute path was incorrectly stored as partialPath
            // Check for app bundle paths with or without leading slash, and anywhere in the string
            let containsAppBundlePath = fixedPartialPath.contains("/var/mobile/") ||
                                       fixedPartialPath.contains("var/mobile/") ||
                                       fixedPartialPath.contains("/private/var/mobile/") ||
                                       fixedPartialPath.contains("private/var/mobile/") ||
                                       fixedPartialPath.contains("/Containers/Data/Application/") ||
                                       fixedPartialPath.contains("Containers/Data/Application/")

            if containsAppBundlePath {
                let pathComponents = (fixedPartialPath as NSString).pathComponents

                // Extract relative path starting from "Documents" or "Caches" to preserve "Save States" folder
                // This ensures paths like "Documents/Save States/Game/file.svs" are preserved correctly
                if let documentsIndex = pathComponents.firstIndex(where: { $0 == "Documents" || $0 == "Caches" }) {
                    // Extract everything after "Documents" or "Caches" (includes "Save States" if present)
                    let relativeComponents = Array(pathComponents[(documentsIndex + 1)...])
                    fixedPartialPath = relativeComponents.joined(separator: "/")
                    DLOG("Trimmed app bundle path from partialPath. Original: \(ogPartialPath), Fixed: \(fixedPartialPath)")
                } else if pathComponents.count >= 2 {
                    // Fallback: take the last two components (directory + filename)
                    let relativeComponents = Array(pathComponents.suffix(2))
                    fixedPartialPath = relativeComponents.joined(separator: "/")
                    DLOG("Trimmed app bundle path from partialPath (fallback). Original: \(ogPartialPath), Fixed: \(fixedPartialPath)")
                }
            }

            // Check for problematic paths first
            if fixedPartialPath.contains("iCloud") || fixedPartialPath.contains("private") {
                failedToFixPartialPath = true
                var pathComponents = (fixedPartialPath as NSString).pathComponents
                if !pathComponents.isEmpty {
                    pathComponents.removeFirst()
                }
                let path = pathComponents.joined(separator: "/")

                #if os(tvOS)
                let isDocumentsDir = path.contains("Documents") || path.contains("Caches")
                let useiCloudDocs = false
                #else
                let isDocumentsDir = path.contains("Documents")
                let useiCloudDocs = Defaults[.iCloudSync] && Defaults[.iCloudSyncMode] == .iCloudDrive
                #endif

                // If we're using CloudKit, use the local documents directory
                if isDocumentsDir {
                    if useiCloudDocs {
                        let iCloudBase = URL.iCloudContainerDirectory?.appendingPathComponent("Documents")
                        returnUrl = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                        return returnUrl
                    } else {
                        returnUrl = RelativeRoot.documentsDirectory.appendingPathComponent(path)
                        return returnUrl
                    }
                } else {
                    if useiCloudDocs, let iCloudBase = URL.iCloudContainerDirectory?.appendingPathComponent("Documents") {
                        returnUrl = iCloudBase.appendingPathComponent(path)
                        return returnUrl
                    } else {
                        returnUrl = RelativeRoot.documentsDirectory.appendingPathComponent(path)
                        return returnUrl
                    }
                }
            }

            // Use the trimmed fixedPartialPath to construct the URL (handles sync mode differences)
            // This ensures we use the corrected path even if it was trimmed from an app bundle path
            let syncMode = Defaults[.iCloudSyncMode]

            // If we're using CloudKit, use the local documents directory
            if syncMode.isCloudKit {
                #if os(tvOS)
                returnUrl = RelativeRoot.cachesDirectory.appendingPathComponent(fixedPartialPath)
                #else
                returnUrl = RelativeRoot.documentsDirectory.appendingPathComponent(fixedPartialPath)
                #endif
            } else {
                // For iCloud Drive, prefer the iCloud container path if available.
                // IMPORTANT: Do NOT hit the filesystem here (SwiftUI calls this a lot).
                if let iCloudContainer = URL.iCloudContainerDirectory {
                    returnUrl = iCloudContainer.appendingPathComponent(fixedPartialPath)
                } else {
                    #if os(tvOS)
                    returnUrl = RelativeRoot.cachesDirectory.appendingPathComponent(fixedPartialPath)
                    #else
                    returnUrl = RelativeRoot.documentsDirectory.appendingPathComponent(fixedPartialPath)
                    #endif
                }
            }
            /*if !isPartialPathFixed {
                DLOG("""
                valid partial path: \(fixedPartialPath)
                url: \(returnUrl)
                relativeRoot: \(relativeRoot)
                """)
            }*/

            // Fast-path: if we didn't detect any problematic patterns above, avoid any additional work.
            // NOTE: We intentionally do not check filesystem existence here (SwiftUI calls this a lot).
            return returnUrl
        }
    }

    private func setURL(_ url: URL) {
        do {
            let newPath = relativeRoot.createRelativePath(fromURL: url)
            try realm?.write {
                partialPath = newPath
            }
        } catch {
            ELOG("\(error)")
        }
    }

    var md5: String? {
        get {
            if let md5 = md5Cache {
                return md5
            }
            guard let url = url else { return nil }
            // Lazy make MD5
            guard let calculatedMD5 = FileManager.default.md5ForFile(at: url, fromOffset: 0) else {
                ELOG("calculatedMD5 nil")
                return nil
            }

            // Cache the MD5 only if we're not frozen
            if !self.isFrozen, let realm = self.realm {
                if !realm.isInWriteTransaction {
                    do {
                        try realm.write {
                            md5Cache = calculatedMD5
                        }
                    } catch {
                        ELOG("Failed to cache MD5: \(error)")
                    }
                } else {
                    md5Cache = calculatedMD5
                }
            }

            return calculatedMD5
        }
    }

    //    public private(set) var crc: String? {
    //        get {
    //            if let crc = crcCache {
    //                return crc
    //            }
    //
    //            // Lazy make CRC
    //            guard let calculatedCRC = FileManager.default.crcForFile(atPath: url.path, fromOffset: 0) else {
    //                return nil
    //            }
    //
    //            self.crc = calculatedCRC
    //            return calculatedCRC
    //        }
    //        set {
    //            do {
    //                try realm?.write {
    //                    crcCache = newValue
    //                }
    //            } catch {
    //                ELOG("\(error)")
    //            }
    //        }
    //    }

    var size: UInt64 {
        get {
            // If we have a recent cache (within last minute), use it
            if let lastCheck = lastSizeCheck,
               Date().timeIntervalSince(lastCheck) < 60,
               sizeCache > 0 {
                return UInt64(sizeCache)
            }

            guard let url = url else { return 0 }
            // Otherwise check the file system
            let path = url.path
            guard FileManager.default.fileExists(atPath: path) else {
                ELOG("No file at path: \(path)")
                return 0
            }

            let fileSize: UInt64
            if let attr = try? FileManager.default.attributesOfItem(atPath: path) as NSDictionary {
                fileSize = attr.fileSize()

                // Cache the size only if we're not frozen
                if !self.isFrozen, let realm = self.realm, !realm.isInWriteTransaction {
                    do {
                        try realm.write {
                            self.sizeCache = Int(fileSize)
                            self.lastSizeCheck = Date()
                        }
                    } catch {
                        ELOG("Failed to update size cache: \(error)")
                    }
                }
            } else {
                ELOG("No attributesOfItem at path: \(path)")
                fileSize = 0
            }

            return fileSize
        }
    }

    // TODO: Make this live update and observable
    var online: Bool { get {
        guard let url = url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }}

    var pathExtension: String {get {
        return url?.pathExtension ?? ""
    }}

    nonisolated(unsafe)
    var fileName: String {get {
        return url?.lastPathComponent ?? ""
    }}

    var fileNameWithoutExtension: String {get {
        return url?.deletingPathExtension().lastPathComponent ?? ""
    }}
}
