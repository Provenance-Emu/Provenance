//
//  PVFile.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit
import PVSupport

public enum RelativeRoot: Int {
    case documents
    case caches
    case iCloud

    #if os(tvOS)
    public static let platformDefault = RelativeRoot.caches
    #else
    public static let platformDefault = RelativeRoot.documents
    #endif

    static let documentsDirectory : URL = PVEmulatorConfiguration.documentsPath
    static let cachesDirectory : URL = PVEmulatorConfiguration.cachesPath
    static var iCloudDocumentsDirectory : URL? { return PVEmulatorConfiguration.iCloudDocumentsDirectory }

    var directoryURL: URL {
        switch self {
        case .documents:
            return RelativeRoot.documentsDirectory
        case .caches:
            return RelativeRoot.cachesDirectory
        case .iCloud:
            return RelativeRoot.iCloudDocumentsDirectory ?? RelativeRoot.documentsDirectory
        }
    }

    func createRelativePath(fromURL url: URL) -> String {
        let searchString: String
        switch self {
        case .documents:
            searchString = "Documents/"
        case .caches:
            searchString = "Caches/"
        case .iCloud:
            searchString = "Documents/"
        }

        let path = url.path
        guard let range = path.range(of: searchString) else {
            return path
        }

        let suffixPath = String(path.suffix(from: range.upperBound))
        return suffixPath
    }

    func appendingPath(_ path: String) -> URL {
        if #available(iOS 9.0, *) {
            return URL.init(fileURLWithPath: path, relativeTo: directoryURL)
        } else {
            return directoryURL.appendingPathComponent(path, isDirectory: false)
        }
    }
}

@objcMembers
public class PVFile: Object, LocalFileProvider, Codable, DomainConvertibleType {
    public typealias DomainType = LocalFile

    @objc internal dynamic var partialPath: String = ""
    @objc private dynamic var md5Cache: String?
    //    @objc private dynamic var crcCache: String?
    @objc private(set) dynamic public var createdDate = Date()
    @objc dynamic private var _relativeRoot: Int = RelativeRoot.documents.rawValue

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = relativeRoot.createRelativePath(fromURL: url)
    }
}

public extension PVFile {
    public internal(set) var relativeRoot: RelativeRoot {
        get {
            return RelativeRoot(rawValue: _relativeRoot)!
        } set {
            _relativeRoot = newValue.rawValue
        }
    }

    public private(set) var url: URL {
        get {
            if partialPath.contains("iCloud") {
                var pathComponents = (partialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                let iCloudBase = path.contains("Documents") ? PVEmulatorConfiguration.iCloudContainerDirectory : PVEmulatorConfiguration.iCloudDocumentsDirectory
                let url = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                return url
            }
            let resolvedURL = relativeRoot.appendingPath(partialPath)
            return resolvedURL
        }
        set {
            do {
                try realm?.write {
                    partialPath = relativeRoot.createRelativePath(fromURL: newValue)
                }
            } catch {
                ELOG("\(error)")
            }
        }
    }

    public private(set) var md5: String? {
        get {
            if let md5 = md5Cache {
                return md5
            }

            // Lazy make MD5
            guard let calculatedMD5 = FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0) else {
                return nil
            }

            self.md5 = calculatedMD5
            return calculatedMD5
        }
        set {
            do {
                try realm?.write {
                    md5Cache = newValue
                }
            } catch {
                ELOG("\(error)")
            }
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

    public var size: UInt64 {
        let fileSize: UInt64

        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path) as NSDictionary {
            fileSize = attr.fileSize()
        } else {
            fileSize = 0
        }
        return fileSize
    }

    public var online: Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    public var pathExtension: String {
        return url.pathExtension
    }

    public var fileName: String {
        return url.lastPathComponent
    }

    public var fileNameWithoutExtension: String {
        return url.deletingPathExtension().lastPathComponent
    }
}
