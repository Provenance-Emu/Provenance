//
//  Files.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/19/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

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
    var fileName: String { get async }
    var md5: String? { get async }
    //	var crc : String? { get }
    var size: UInt64 { get async }
    var online: Bool { get async }
}

public protocol LocalFileInfoProvider: FileInfoProvider {
    var url: URL { get async }
}

public protocol LocalFileProvider: LocalFileInfoProvider, DataProvider {}

public extension LocalFileProvider {
    func readData() async throws -> Data {
        return try await Data(contentsOf: url)
    }
}

public protocol DataProvider {
    var data: Data? { get async }
    func readData() async throws -> Data
}

public extension DataProvider {
    var data: Data? { get async { return try? await readData() } }
}

public protocol RemoteFileInfoProvider: FileInfoProvider {
    var dataProvider: DataProvider { get }
}

// Cache for storing md5's
@MainActor
private let md5Cache: Cache<URL, String> = {
    let c = Cache<URL, String>(lowMemoryAware: false)
    c.countLimit = 1024
    let d = Data()

    return c
}()

extension LocalFileInfoProvider {
    public var size: UInt64 { get async {
        let fileSize: UInt64

        if let attr = try? await FileManager.default.attributesOfItem(atPath: url.path) as NSDictionary {
            fileSize = attr.fileSize()
        } else {
            fileSize = 0
        }
        return fileSize
    } }

    public var online: Bool { get async {
        return await FileManager.default.fileExists(atPath: url.path)
    }}

    public var pathExtension: String { get async {
        return await url.pathExtension
    }}

    public var fileName: String { get async {
        return await url.lastPathComponent
    }}

    public var fileNameWithoutExtension: String { get async {
        return await url.deletingPathExtension().lastPathComponent
    }}

    public var md5: String? { get async {
        if let md5 = await md5Cache.object(forKey: url) {
            return md5
        }

        // Lazy make MD5
        guard let calculatedMD5 = await FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0) else {
            return nil
        }

        await md5Cache.setObject(calculatedMD5, forKey: url)
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
