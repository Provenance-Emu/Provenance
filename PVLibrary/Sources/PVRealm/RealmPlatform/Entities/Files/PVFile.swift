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
    internal dynamic var partialPath: String = ""
    nonisolated(unsafe)
    internal dynamic var md5Cache: String?
    //    @objc private dynamic var crcCache: String?
    nonisolated(unsafe)
    public private(set) dynamic var createdDate = Date()
    nonisolated(unsafe)
    internal dynamic var _relativeRoot: Int = RelativeRoot.documents.rawValue

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        partialPath = relativeRoot.createRelativePath(fromURL: url)
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

    var url: URL {
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
            let path = url.path
            // Lazy make MD5
            guard let calculatedMD5 = FileManager.default.md5ForFile(atPath: path, fromOffset: 0) else {
                ELOG("calculatedMD5 nil")
                return nil
            }

//            Task {
                guard let realm = self.realm else {
                    return nil
                }
                do {
                    try realm.write {
                        md5Cache = calculatedMD5
                    }
                } catch {
                    ELOG("\(error)")
                }
//            }

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

    var size: UInt64 { get {
//        return await Task {
            let path = url.path
            guard FileManager.default.fileExists(atPath: path) else {
                ELOG("No file at path: \(path)")
                return 0
            }
            
            let fileSize: UInt64
            if let attr = try? FileManager.default.attributesOfItem(atPath: path) as NSDictionary {
                fileSize = attr.fileSize()
            } else {
                ELOG("No attributesOfItem at path: \(path)")
                fileSize = 0
            }
            return fileSize
//        }.value
    }}

    // TODO: Make this live update and observable
    var online: Bool { get {
        return FileManager.default.fileExists(atPath: url.path)
    }}

    var pathExtension: String {get {
        return url.pathExtension
    }}

    nonisolated(unsafe)
        var fileName: String {get {
            return url.lastPathComponent
        }}

    var fileNameWithoutExtension: String {get {
        return url.deletingPathExtension().lastPathComponent
    }}
}
