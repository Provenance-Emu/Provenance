//
//  PVFile.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

public enum RelativeRoot: Int {
    case documents
    case caches

    #if os(tvOS)
    public static let platformDefault = RelativeRoot.caches
    #else
    public static let platformDefault = RelativeRoot.documents
    #endif

    static let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!)
    static let cachesDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!)

    var directoryURL: URL {
        switch self {
        case .documents:
            return RelativeRoot.documentsDirectory
        case .caches:
            return RelativeRoot.cachesDirectory
        }
    }

    func createRelativePath(fromURL url: URL) -> String {
        let searchString: String
        switch self {
        case .documents:
            searchString = "Documents/"
        case .caches:
            searchString = "Caches/"
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

@objcMembers public class PVImageFile: PVFile {
    @objc private dynamic var _cgsize: String!
    @objc dynamic var ratio: Float = 0.0
    @objc dynamic var width: Int = 0
    @objc dynamic var height: Int = 0
    @objc dynamic var layout: String = ""

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
        calculateSizeData()
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = relativeRoot.createRelativePath(fromURL: url)
        calculateSizeData()
    }

    private func calculateSizeData() {
        guard let image = UIImage(contentsOfFile: url.path) else {
            ELOG("Failed to create UIImage from path <\(url.path)>")
            return
        }

        let size  = image.size
        cgsize = size
    }

    private(set) public var cgsize: CGSize {
        get {
            return CGSizeFromString(_cgsize)
        }
        set {
            width = Int(newValue.width)
            height = Int(newValue.height)
            layout = newValue.width > newValue.height ? "landscape" : "portrait"
            ratio = Float(max(newValue.width, newValue.height) / min(newValue.width, newValue.height))
            _cgsize = NSStringFromCGSize(newValue)
        }
    }
}

@objcMembers public class PVFile: Object, Codable {
    @objc fileprivate dynamic var partialPath: String = ""
    @objc private dynamic var md5Cache: String?
    @objc private(set) public dynamic var createdDate = Date()
    @objc private dynamic var _relativeRoot: Int = RelativeRoot.documents.rawValue

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
    var relativeRoot: RelativeRoot {
        get {
            return RelativeRoot(rawValue: _relativeRoot)!
        } set {
            _relativeRoot = newValue.rawValue
        }
    }

    private(set) var url: URL {
        get {
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

    private(set) var md5: String? {
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

    var size: UInt64 {
        let fileSize: UInt64

        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path) as NSDictionary {
            fileSize = attr.fileSize()
        } else {
            fileSize = 0
        }
        return fileSize
    }

    var missing: Bool {
        return !FileManager.default.fileExists(atPath: url.path)
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
