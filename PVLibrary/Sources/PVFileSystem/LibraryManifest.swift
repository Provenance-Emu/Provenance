//
//  LibraryManifest.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  `.provenance-library.json` at the root of a shared library folder: the layout contract shared with iCube
//  and iFly (spec § "Folder layout contract"). Written once by whichever app created the library, never
//  rewritten. Readers ignore keys they don't know and tolerate a missing `createdAt`.
//

import Foundation

public struct LibraryManifest: Codable, Sendable, Equatable {
    public static let fileName = ".provenance-library.json"
    public static let currentVersion = 1

    public var version: Int
    /// Bundle identifier of the app that created the library.
    public var createdBy: String
    public var createdAt: Date?

    public init(createdBy: String, createdAt: Date? = Date()) {
        version = Self.currentVersion
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    public static func url(in root: URL) -> URL {
        root.appendingPathComponent(fileName, isDirectory: false)
    }

    public static func exists(in root: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: url(in: root).path)
    }

    public static func read(from root: URL) throws -> LibraryManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LibraryManifest.self, from: Data(contentsOf: url(in: root)))
    }

    /// Writes a manifest naming `createdBy` unless the folder already has one.
    /// - Returns: `true` when a manifest was written.
    @discardableResult
    public static func writeIfAbsent(in root: URL, createdBy: String, fileManager: FileManager = .default) throws -> Bool {
        guard !exists(in: root, fileManager: fileManager) else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(LibraryManifest(createdBy: createdBy)).write(to: url(in: root), options: .atomic)
        return true
    }
}
