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
    private var isPartialPathFixed = false

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
        partialPath = relativeRoot.createRelativePath(fromURL: url)
        self.md5Cache = md5
        if size > 0 {
            self.sizeCache = size
            self.lastSizeCheck = Date()
        }
    }

    public override static func ignoredProperties() -> [String] {
        return ["sizeCache", "lastSizeCheck"]
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
    internal func fixPartialPath() {
        guard !isPartialPathFixed
        else {
            return
        }
        fixPartialPath(substring: "file:///private/")
        fixPartialPath(substring: "file:///")
        fixPartialPath(remove: URL.documentsDirectory)
        fixPartialPath(remove: URL.applicationDirectory)
        fixPartialPath(remove: URL.iCloudDocumentsDirectory)
        fixPartialPath(remove: URL.iCloudContainerDirectory)
        /*
             private/var/mobile/Library/Mobile
             var/mobile/Containers/Data/Application
             var/mobile/Containers/
             private/var/mobile
         }
         */
        isPartialPathFixed = true
    }
    
    /// tries to remove url from `partialPath`
    /// - Parameter optionalUrl: if nil, then does nothing
    internal func fixPartialPath(remove optionalUrl: URL?) {
        guard let url = optionalUrl
        else {
            return
        }
        let privatePrefix = "private/"
        DLOG("attempting to remove from partialPath: \(url) with and without prefix: \(privatePrefix)")
        fixPartialPath(remove: url, withPercentEncoded: true)
        fixPartialPath(remove: url, withPercentEncoded: true, prefix: privatePrefix)
        fixPartialPath(remove: url, withPercentEncoded: false)
        fixPartialPath(remove: url, withPercentEncoded: false, prefix: privatePrefix)
    }
    
    /// if `partialPath` contains `url.path` with the given percent encoding, then it replaces it with an empty string
    /// - Parameters:
    ///   - url: url to find within `partialPath`
    ///   - percentEncoded: whether or not to add percent encoding
    ///   - prefix: optional prefix to do a search on
    internal func fixPartialPath(remove url: URL, withPercentEncoded percentEncoded: Bool, prefix: String = "") {
        let substring = "\(prefix)\(url.path(percentEncoded: percentEncoded))"
        fixPartialPath(substring: substring)
    }
    
    /// if `substring` exists in `partialPath`, then it removes it
    /// - Parameter substring: substring to test/remove
    internal func fixPartialPath(substring: String) {
        if partialPath.contains(substring) {
            partialPath = partialPath.replacingOccurrences(of: substring, with: "", options: .caseInsensitive)
        }
    }

    var url: URL? {
        get {
            fixPartialPath()
            var returnUrl: URL?
            defer {
                DLOG("partialPath: \(partialPath), url: \(returnUrl)")
            }
            if partialPath.contains("iCloud") || partialPath.contains("private") {
                DLOG("invalid partial path: \(partialPath)")
                var pathComponents = (partialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                let isDocumentsDir = path.contains("Documents")
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
            DLOG("valid partial path: \(partialPath)")
            returnUrl = relativeRoot.appendingPath(partialPath)
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
