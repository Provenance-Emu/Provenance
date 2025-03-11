//
//  Files.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/19/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVHashing

public enum FileSystemType: Sendable {
    case local
    case remote
    case iCloud
}

public struct FileInfo: Codable, FileInfoProvider, Sendable {
    public let fileName: String
    public let size: UInt64
    public let md5: String?
    public let online: Bool
    public let local: Bool

    public init(fileName: String, size: UInt64 = 0, md5: String? = nil, online: Bool = true, local: Bool = true) {
        self.fileName = fileName
        self.size = size
        self.md5 = md5
        self.online = online
        self.local = local
    }
}

public typealias FileProviderFetch = (() throws -> Data) -> Void
/// A type that can represent a file for library import usage
///
///
public protocol FileInfoProvider {
    var fileName: String { get }
    var md5: String? { get }
    //	var crc : String? { get }
    var size: UInt64 { get }
    var online: Bool { get }
}

public protocol LocalFileInfoProvider: FileInfoProvider {
    var url: URL? { get }
}

public protocol LocalFileProvider: LocalFileInfoProvider, DataProvider {}

public extension LocalFileProvider {
    func readData() async throws -> Data? {
        guard let url = url else { return nil }
        return try Data(contentsOf: url)
    }
}

public protocol DataProvider {
    var data: Data? { get async }
    func readData() async throws -> Data?
}

public extension DataProvider {
    var data: Data? { get async { return try? await readData() } }
}

public protocol RemoteFileInfoProvider: FileInfoProvider {
    var dataProvider: DataProvider { get }
}

//private final class MD5Cache: Cache<KeyWrapper<URL>, String> {
//    public init() {
//        super.init(lowMemoryAware: false)
//    }
//    
//    public func md5(for url: URL) async throws -> String {
//        if let cached = try? await self.object(forKey: KeyWrapper(url)) {
//            return cached.md5
//        }
//    }
//}

// Cache for storing md5's
//@MainActor
nonisolated(unsafe) private let md5Cache: Cache<URL, String> = {
    let c = Cache<URL, String>(lowMemoryAware: false)
    c.countLimit = 1024
    let d = Data()

    return c
}()

public extension LocalFileInfoProvider {
    var size: UInt64 { get {
        guard let url = url else { return 0 }
        let fileSize: UInt64

        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path) as NSDictionary {
            fileSize = attr.fileSize()
        } else {
            fileSize = 0
        }
        return fileSize
    } }

    var online: Bool { get {
        guard let url = url else { return true }
        return FileManager.default.fileExists(atPath: url.path)
    }}

    var pathExtension: String { get {
        guard let url = url else { return "" }

        return url.pathExtension
    }}

    var fileName: String { get {
        guard let url = url else { return "" }
        return url.lastPathComponent
    }}

    var fileNameWithoutExtension: String { get {
        guard let url = url else { return "" }
        return url.deletingPathExtension().lastPathComponent
    }}

    @preconcurrency
    var md5: String? { get {
        guard let url = url else { return nil }

        if let md5 = md5Cache.object(forKey: url) {
            return md5
        }

        // Lazy make MD5
        guard let calculatedMD5 = FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0) else {
            return nil
        }

        md5Cache.setObject(calculatedMD5, forKey: url)
        return calculatedMD5
    }}
}

public protocol FileBacked {
    associatedtype FileInfoProviderType: FileInfoProvider
    var fileInfo: FileInfoProviderType? { get }
}

public protocol LocalFileBacked: FileBacked where FileInfoProviderType: LocalFileInfoProvider {}

public protocol ExpectedMD5Provider {
    var expectedMD5: String { get }
}

public protocol ExpectedFilenameProvider {
    var expectedFilename: String { get }
}

public protocol ExpectedSizeProvider {
    var expectedSize: Int { get }
}

public protocol ExpectedExistentInfoProvider {
    var optional: Bool { get }
}
