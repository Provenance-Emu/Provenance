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

    var url: URL? {
        get {
            if partialPath.contains("iCloud") || partialPath.contains("private") {
                var pathComponents = (partialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                let isDocumentsDir = path.contains("Documents")

                if isDocumentsDir {
                    let iCloudBase = URL.iCloudContainerDirectory
                    let url = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                    return url
                } else {
                    if let iCloudBase = URL.iCloudDocumentsDirectory {
                        return iCloudBase.appendingPathComponent(path)
                    } else {
                        return RelativeRoot.documentsDirectory.appendingPathComponent(path)
                    }
                }
            }
            let root = relativeRoot
            let resolvedURL = root.appendingPath(partialPath)
            return resolvedURL
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
            let path = url.path
            // Lazy make MD5
            guard let calculatedMD5 = FileManager.default.md5ForFile(atPath: path, fromOffset: 0) else {
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
