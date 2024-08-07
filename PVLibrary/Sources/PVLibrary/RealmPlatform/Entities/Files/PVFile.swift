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

public enum RelativeRoot: Int, Sendable {
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
    static var iCloudDocumentsDirectory: URL? {
        get async {
            return await PVEmulatorConfiguration.iCloudDocumentsDirectory
        }
    }

    var directoryURL: URL {
        get async {
            switch self {
            case .documents:
                return RelativeRoot.documentsDirectory
            case .caches:
                return RelativeRoot.cachesDirectory
            case .iCloud:
                if let iCloudDocumentsDirectory = await RelativeRoot.iCloudDocumentsDirectory { return iCloudDocumentsDirectory }
                else { return await Self.platformDefault.directoryURL }
            }
        }
    }

    func createRelativePath(fromURL url: URL) async -> String {
        // We need the dropFirst to remove the leading /
        return await String(url.path.replacingOccurrences(of: directoryURL.path, with: "").dropFirst())
    }

    func appendingPath(_ path: String) async -> URL {
        let directoryURL = await self.directoryURL
        let url = directoryURL.appendingPathComponent(path)
//        let url = URL(fileURLWithPath: path, relativeTo: directoryURL)
        return url
    }
}

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

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) async {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) async {
        self.init()
        self.relativeRoot = relativeRoot
        partialPath = await relativeRoot.createRelativePath(fromURL: url)
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
        get async {
            if partialPath.contains("iCloud") || partialPath.contains("private") {
                var pathComponents = (partialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                let isDocumentsDir = path.contains("Documents")

                if isDocumentsDir {
                    let iCloudBase = PVEmulatorConfiguration.iCloudContainerDirectory
                    let url = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                    return url
                } else {
                    if let iCloudBase = await PVEmulatorConfiguration.iCloudDocumentsDirectory {
                        return iCloudBase.appendingPathComponent(path)
                    } else {
                        return RelativeRoot.documentsDirectory.appendingPathComponent(path)
                    }
                }
            }
            let root = relativeRoot
            let resolvedURL = await root.appendingPath(partialPath)
            return resolvedURL
        }
    }

    private func setURL(_ url: URL) async {
        do {
            let newPath = await relativeRoot.createRelativePath(fromURL: url)
            try realm?.write {
                partialPath = newPath
            }
        } catch {
            ELOG("\(error)")
        }
    }

    var md5: String? {
        get async {
            if let md5 = md5Cache {
                return md5
            }
            let path = await url.path
            // Lazy make MD5
            guard let calculatedMD5 = FileManager.default.md5ForFile(atPath: path, fromOffset: 0) else {
                ELOG("calculatedMD5 nil")
                return nil
            }

            Task {
                do {
                    try realm?.write {
                        md5Cache = calculatedMD5
                    }
                } catch {
                    ELOG("\(error)")
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

    var size: UInt64 { get async {
        return await Task {
            let path = await url.path
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
        }.value
    }}

    var online: Bool { get async {
        return await FileManager.default.fileExists(atPath: url.path)
    }}

    var pathExtension: String {get async {
        return await url.pathExtension
    }}

    nonisolated(unsafe)
        var fileName: String {get async {
            return await url.lastPathComponent
        }}

    var fileNameWithoutExtension: String {get async {
        return await url.deletingPathExtension().lastPathComponent
    }}
}
