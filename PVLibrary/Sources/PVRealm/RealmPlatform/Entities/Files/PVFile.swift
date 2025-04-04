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
    
    //TODO: add unit test
    /// attempts to fix `partialPath`
    internal func fixPartialPath() {
        guard !isPartialPathFixed
        else {
            return
        }
        if partialPath.contains("file:///private/") {
            partialPath = partialPath.replacingOccurrences(of: "file:///private/", with: "", options: .caseInsensitive)
        }
        
        if partialPath.contains("file:///") {
            partialPath = partialPath.replacingOccurrences(of: "file:///", with: "", options: .caseInsensitive)
        }
        
        DLOG("documents directory: \(URL.documentsDirectory)")
        fixPartialPath(of: URL.documentsDirectory)
        DLOG("applications directory: \(URL.applicationDirectory)")
        fixPartialPath(of: URL.applicationDirectory)
        if let iCloudDocumentsDirectory = URL.iCloudDocumentsDirectory {
            DLOG("iCloud documents directory: \(iCloudDocumentsDirectory)")
            fixPartialPath(of: iCloudDocumentsDirectory)
        }
        if let iCloudContainerDirectory = URL.iCloudContainerDirectory {
            DLOG("iCloud container directory: \(iCloudContainerDirectory)")
            fixPartialPath(of: iCloudContainerDirectory)
        }
        /*
             private/var/mobile/Library/Mobile
             var/mobile/Containers/Data/Application
             var/mobile/Containers/
             private/var/mobile
         }
         */
    }
    
    internal func fixPartialPath(of url: URL) {
        let privatePrefix = "private"
        fixPartialPath(of: url, withPercentEncoded: true)
        fixPartialPath(of: url, withPercentEncoded: true, prefix: privatePrefix)
        fixPartialPath(of: url, withPercentEncoded: false)
        fixPartialPath(of: url, withPercentEncoded: false, prefix: privatePrefix)
    }
    
    /// if `partialPath` contains `url.path` with the given percent encoding, then it replaces it with an empty string
    /// - Parameters:
    ///   - url: url to find within `partialPath`
    ///   - percentEncoded: whether or not to add percent encoding
    ///   - prefix: optional prefix to do a search on
    internal func fixPartialPath(of url: URL, withPercentEncoded percentEncoded: Bool, prefix: String = "") {
        if partialPath.contains("\(prefix)\(url.path(percentEncoded: percentEncoded))") {
            partialPath = partialPath.replacingOccurrences(of: url.path(percentEncoded: percentEncoded), with: "", options: .caseInsensitive)
        }
    }
/*
 file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~contributions~provenance/Documents/
 vs
 file:///var/mobile/Library/Mobile%20Documents/iCloud~com~contributions~provenance/Documents/
 */
    var url: URL? {
        get {
            fixPartialPath()
            let url2 = urlUpdate
            //DLOG("url2=\(url2)\tpartialPath=\(partialPath)")
            if partialPath.contains("iCloud") || partialPath.contains("private") {
                var pathComponents = (partialPath as NSString).pathComponents
                pathComponents.removeFirst()
                let path = pathComponents.joined(separator: "/")
                let isDocumentsDir = path.contains("Documents")
                
                if isDocumentsDir {
                    let iCloudBase = URL.iCloudContainerDirectory
                    let url = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
                    DLOG("url:\(url)")
                    return url
                } else {
                    if let iCloudBase = URL.iCloudDocumentsDirectory {
                        let appendedICloudBase = iCloudBase.appendingPathComponent(path)
                        DLOG("appendedICloudBase:\(appendedICloudBase))")
                        return appendedICloudBase
                    } else {
                        let appendedRelativeRoot = RelativeRoot.documentsDirectory.appendingPathComponent(path)
                        DLOG("appendedRelativeRoot:\(appendedRelativeRoot)")
                        return appendedRelativeRoot
                    }
                }
            }
            let root = relativeRoot
            let resolvedURL = root.appendingPath(partialPath)
            DLOG("resolvedURL:\(resolvedURL)")
            return resolvedURL
        }
    }
    var urlUpdate:URL {
        get {
//            DLOG("relativeRoot=\(relativeRoot)\tpartialPath=\(partialPath)")
            //TODO: lazy load this so it's only done once
            let pathSuffix: String
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
//                DLOG("Bundle Identifier: \(bundleIdentifier)")
                let bundleComponents = bundleIdentifier.split(separator: ".")
//                DLOG("bundleComponents=\(bundleComponents)")
                let joined = bundleComponents.joined(separator: "~")
//                DLOG("joined=\(joined)")
                pathSuffix = joined
            } else {
                pathSuffix = "org~provenance-emu~provenance"
            }
            let privateDirectory = "private"
            if partialPath.contains("/iCloud~\(pathSuffix)/") {//&& partialPath.hasPrefix("\(privateDirectory)/") {
                let completePath: String
                let filePrefix = "file:///"
                if !partialPath.hasPrefix(filePrefix) {
                   completePath = "\(filePrefix)\(partialPath)"
                } else {
                    completePath = partialPath
                }
                if let urlPath = URL(string: completePath) {
//                    DLOG("urlPath=\(urlPath)")
                    return urlPath
                }
                
                var pathComponents = (partialPath as NSString).pathComponents
//                DLOG("pathComponents=\(pathComponents)")
                //["private", "var", "mobile", "Library", "Mobile Documents", "iCloud~\(pathSuffix)", "Documents"]
                let mobileDocumentsEncoded = "Mobile%20Documents"
                let mobileDocumentsDecoded = "Mobile Documents"
                let directoryPath: String
                
                if let iCloudDocumentsDirectoryContainer = URL.iCloudDocumentsDirectory {
                    var tmp = "\(iCloudDocumentsDirectoryContainer)"
                    let filePrefix = "file://"
                    if tmp.hasPrefix(filePrefix) {
                        tmp = tmp.replacingOccurrences(of: filePrefix, with: "")
                    }
                    directoryPath = tmp
                } else {
                    directoryPath = "\(privateDirectory)/var/mobile/Library/\(mobileDocumentsDecoded)/\(mobileDocumentsDecoded)/iCloud~\(pathSuffix)"
                }
//                DLOG("directoryPath=\(directoryPath)")
                var prefixes = directoryPath.split(separator: "/")
                let mobileDocumentsEncodedSub = mobileDocumentsEncoded.prefix(mobileDocumentsEncoded.count)
                //we also add an encoded one.
                if !prefixes.contains(mobileDocumentsEncodedSub) {
                    prefixes.append(mobileDocumentsEncodedSub)
                }
                let mobileDocumentsDecodedSub = mobileDocumentsDecoded.prefix(mobileDocumentsDecoded.count)
                //we also add a decoded one.
                if !prefixes.contains(mobileDocumentsDecodedSub) {
                    prefixes.append(mobileDocumentsDecodedSub)
                }
//                DLOG("prefixes=\(prefixes)")
                while prefixes.contains(where: {String($0) == pathComponents.first}) {
                    /*
                     Action Button Pressed  1706495469592 Optional(1706495461875)
                     relativeRoot=documents    partialPath=private/var/mobile/Library/Mobile Documents/iCloud~com~pqskapps~provenance/Documents/Save States/Gremlins (USA).a52/DC271E475B4766E80151F1DA5B764E52.728185244.058265.svs
                     pathComponents=["private", "var", "mobile", "Library", "Mobile Documents", "iCloud~com~pqskapps~provenance", "Documents", "Save States", "Gremlins (USA).a52", "DC271E475B4766E80151F1DA5B764E52.728185244.058265.svs"]
                     pathComponentslremoveFirst()=["var", "mobile", "Library", "Mobile Documents", "iCloud~com~pqskapps~provenance", "Documents", "Save States", "Gremlins (USA).a52", "DC271E475B4766E80151F1DA5B764E52.728185244.058265.svs"]
                     path=var/mobile/Library/Mobile Documents/iCloud~com~pqskapps~provenance/Documents/Save States/Gremlins (USA).a52/DC271E475B4766E80151F1DA5B764E52.728185244.058265.svs
                     PVEmulatorConfiguration.iCloudContainerDirectory=Optional(file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~pqskapps~provenance/)
                     PVEmulatorConfiguration.iCloudDocumentsDirectory=Optional(file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~pqskapps~provenance/Documents/)
                     iCloudBase=Optional(file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~pqskapps~provenance/)
                     url=file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~pqskapps~provenance/var/mobile/Library/Mobile%20Documents/iCloud~com~pqskapps~provenance/Documents/Save%20States/Gremlins%20(USA).a52/DC271E475B4766E80151F1DA5B764E52.728185244.058265.svs
                     */
                    pathComponents.removeFirst()
//                    DLOG("pathComponentslremoveFirst()=\(pathComponents)")
                }
                let path = pathComponents.joined(separator: "/")
//                DLOG("path=\(path)")
//                DLOG("PVEmulatorConfiguration.iCloudContainerDirectory=\(String(describing: URL.iCloudContainerDirectory))")
//                DLOG("PVEmulatorConfiguration.iCloudDocumentsDirectory=\(String(describing: URL.iCloudDocumentsDirectory))")
                let iCloudBase = path.contains("Documents") ? URL.iCloudContainerDirectory : URL.iCloudDocumentsDirectory
//                DLOG("iCloudBase=\(String(describing: iCloudBase))")
                let url = (iCloudBase ?? RelativeRoot.documentsDirectory).appendingPathComponent(path)
//                DLOG("url=\(url)")
                return url
            }
            let root = relativeRoot
//            DLOG("root=\(root)")
            var actualPartialPath = partialPath
            if root == .iCloud && partialPath.starts(with: "var/mobile/Containers/Data/Application/") {
//                DLOG("iCloud path, but partialPath does NOT contain iCloud path, but instead local path")
                var partialPathComponents = partialPath.components(separatedBy: "/")
                let directoriesToRemove = partialPathComponents.count >= 7 ? 7 : partialPathComponents.count
                partialPathComponents.removeFirst(directoriesToRemove)
                actualPartialPath = partialPathComponents.joined(separator: "/")
            }
//            DLOG("actualPartialPath=\(actualPartialPath)")
            if partialPath.hasPrefix(privateDirectory) {
                var tmp = partialPath.split(separator: "/")
                tmp.removeFirst()
                actualPartialPath = tmp.joined(separator: "/")
            }
//            DLOG("actualPartialPath=\(actualPartialPath)")
            let resolvedURL = root.appendingPath(actualPartialPath)
//            DLOG("resolvedURL=\(resolvedURL)")
            return resolvedURL
            /*
             relativeRoot=iCloud    partialPath=var/mobile/Containers/Data/Application/B8153B85-9BB5-44B6-A189-FDE9D8ABC29C/Documents/PVCache/F62D5AA941BB70E1913B787A65CD7EFC
             Bundle Identifier: com.pqskapps.provenance
             bundleComponents=["com", "pqskapps", "provenance"]
             joined=com~pqskapps~provenance
             resolvedURL=file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~pqskapps~provenance/Documents/var/mobile/Containers/Data/Application/B8153B85-9BB5-44B6-A189-FDE9D8ABC29C/Documents/PVCache/F62D5AA941BB70E1913B787A65CD7EFC
             */
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
