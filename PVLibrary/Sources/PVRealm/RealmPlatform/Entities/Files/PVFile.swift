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
    internal dynamic var md5Cache: String?
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
        return ["sizeCache", "lastSizeCheck", "_actualPartialPath"]
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
    
    /// attempts to fix `partialPath`
    var actualPartialPath: String {
        if let fixedPartialPath = _actualPartialPath {
            return fixedPartialPath
        }
        var mutatingPartialPath = partialPath
        fixPartialPath(substring: "file:///private/", &mutatingPartialPath)
        fixPartialPath(substring: "file:///", &mutatingPartialPath)
        fixPartialPath(remove: URL.documentsDirectory, &mutatingPartialPath)
        fixPartialPath(remove: URL.iCloudDocumentsDirectory, &mutatingPartialPath)
        fixPartialPath(remove: URL.iCloudContainerDirectory, &mutatingPartialPath)
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
            guard Defaults[.iCloudSync] else {
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
            var ogPartialPath = partialPath
            let fixedPartialPath = actualPartialPath
            var returnUrl: URL
            var failedToFixPartialPath = false
            defer {
                /*if !isPartialPathFixed {
                    DLOG("""
                    original partialPath: \(ogPartialPath)
                    fixed partialPath: \(fixedPartialPath)
                    url: \(returnUrl)
                    relativeRoot: \(relativeRoot)
                    """)
                }*/
                if !isPartialPathFixed && failedToFixPartialPath {
                    ELOG("""
                    invalid partial path: \(fixedPartialPath)
                    original partialPath: \(ogPartialPath)
                    url generated: \(returnUrl)
                    relativeRoot: \(relativeRoot)   
                    """)
                }
            }
            if fixedPartialPath.contains("iCloud") || fixedPartialPath.contains("private") {
                failedToFixPartialPath = true
                var pathComponents = (fixedPartialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                #if os(tvOS)
                let isDocumentsDir = path.contains("Documents") || path.contains("Caches")
                #else
                let isDocumentsDir = path.contains("Documents")
                #endif

                if isDocumentsDir {
                    let iCloudBase = URL.iCloudContainerDirectory
                    returnUrl = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                    return returnUrl
                } else {
                    if let iCloudBase = URL.iCloudDocumentsDirectory {
                        returnUrl = iCloudBase.appendingPathComponent(path)
                        return returnUrl
                    } else {
                        returnUrl = RelativeRoot.documentsDirectory.appendingPathComponent(path)
                        return returnUrl
                    }
                }
            }
            returnUrl = relativeRoot.appendingPath(fixedPartialPath)
            /*if !isPartialPathFixed {
                DLOG("""
                valid partial path: \(fixedPartialPath)
                url: \(returnUrl)
                relativeRoot: \(relativeRoot)
                """)
            }*/
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
        guard let url = url else { return true }

        let exists = FileManager.default.fileExists(atPath: url.path)
        let needsDownload = isICloudFile(url) && needsDownload(url)
        return exists && !needsDownload
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
