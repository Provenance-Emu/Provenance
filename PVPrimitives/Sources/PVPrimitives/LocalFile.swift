//
//  LocalFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLogging

public struct LocalFile: LocalFileProvider, Codable, Equatable, Sendable {
    public let url: URL
    public var data: Data? { get {
        return try? Data(contentsOf: url)
    }}

    private var md5Cache: String?

    public var md5: String? {
        mutating get {
            guard online else {
                return nil
            }

            if let md5Cache = md5Cache {
                return md5Cache.uppercased()
            } else {
                let md5 = FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0)
                md5Cache = md5
                return md5
            }
        }
    }

    public var size: UInt64 { get {
        do {
            guard let s = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                return 0
            }

            return UInt64(s)
        } catch {
            ELOG("\(error.localizedDescription)")
            return 0
        }
    }}

    public init?(url: URL) {
        guard url.isFileURL else {
            return nil
        }

        self.url = url
    }
}
 
// MARK: - Hashable
extension LocalFile: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(md5)
    }
}

// MARK: - Comparable
extension LocalFile: Comparable {
    public static func < (lhs: LocalFile, rhs: LocalFile) -> Bool {
        return lhs.url.path < rhs.url.path
    }
}

// MARK: - CustomStringConvertible
extension LocalFile: CustomStringConvertible {
    public var description: String {
        return "Path: \(url.path), MD5: \(md5 ?? "n/a"), Size: \(size)"
    }
}

// MARK: - LocalFileProvider
extension LocalFile {
    public var online: Bool { get {
        return FileManager.default.fileExists(atPath: url.path)
    }}
}

// MARK: - Equatable
public func == (lhs: LocalFile, rhs: LocalFile) -> Bool {
    return lhs.url == rhs.url || lhs.md5 == rhs.md5
}

#if canImport(CoreTransferable)
import CoreTransferable
import UniformTypeIdentifiers
@available(iOS 16.0, *)
extension LocalFile: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .fileURL)
    }
}
#endif
