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

public enum RelativeRoot: Int {
    case documents
    case caches
    case iCloud

    #if os(tvOS)
        public static let platformDefault = RelativeRoot.caches
    #else
        public static let platformDefault = RelativeRoot.documents
    #endif

    static let documentsDirectory: URL = PVEmulatorConfiguration.documentsPath
    static let cachesDirectory: URL = PVEmulatorConfiguration.cachesPath
    static var iCloudDocumentsDirectory: URL? { return PVEmulatorConfiguration.iCloudDocumentsDirectory }

    var directoryURL: URL {
        switch self {
        case .documents:
            return RelativeRoot.documentsDirectory
        case .caches:
            return RelativeRoot.cachesDirectory
        case .iCloud:
            return RelativeRoot.iCloudDocumentsDirectory ?? Self.platformDefault.directoryURL
        }
    }

    func createRelativePath(fromURL url: URL) -> String {
        // We need the dropFirst to remove the leading /
        return String(url.path.replacingOccurrences(of: directoryURL.path, with: "").dropFirst())
    }

    func appendingPath(_ path: String) -> URL {
        let directoryURL = self.directoryURL
        let url = directoryURL.appendingPathComponent(path)
//        let url = URL(fileURLWithPath: path, relativeTo: directoryURL)
        return url
    }
}

@objcMembers
public class PVFile: Object, LocalFileProvider, Codable, DomainConvertibleType {
    public typealias DomainType = LocalFile

    internal dynamic var partialPath: String = ""
    internal dynamic var md5Cache: String?
    //    @objc private dynamic var crcCache: String?
    public private(set) dynamic var createdDate = Date()
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
    internal(set) var relativeRoot: RelativeRoot {
        get {
            return RelativeRoot(rawValue: _relativeRoot)!
        } set {
            _relativeRoot = newValue.rawValue
        }
    }

    private(set) var url: URL {
        get {
            if partialPath.contains("iCloud") || partialPath.contains("private") {
                var pathComponents = (partialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                let iCloudBase = path.contains("Documents") ? PVEmulatorConfiguration.iCloudContainerDirectory : PVEmulatorConfiguration.iCloudDocumentsDirectory
                let url = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                return url
            }
            let root = relativeRoot
            let resolvedURL = root.appendingPath(partialPath)
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

    private(set) var md5: String? {
        get {
            if let md5 = md5Cache {
                return md5
            }

            // Lazy make MD5
            guard let calculatedMD5 = FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0) else {
				ELOG("calculatedMD5 nil")
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

    var size: UInt64 {
        let fileSize: UInt64
        guard FileManager.default.fileExists(atPath: url.path) else {
            ELOG("No file at path: \(url.path)")
            return 0
        }

        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path) as NSDictionary {
            fileSize = attr.fileSize()
        } else {
			ELOG("No attributesOfItem at path: \(url.path)")
            fileSize = 0
        }
        return fileSize
    }

    var online: Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    var pathExtension: String {
        return url.pathExtension
    }

    var fileName: String {
        return url.lastPathComponent
    }

    var fileNameWithoutExtension: String {
        return url.deletingPathExtension().lastPathComponent
    }
}
