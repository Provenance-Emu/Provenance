//
//  PVLookup.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Foundation
import OpenVGDB
import ROMMetadataProvider
import PVLookupTypes
import libretrodb

/// Protocol for basic ROM metadata lookup operations
public protocol ROMMetadataLookup {
    /// Search database using a filename
    func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]?

    /// Search database using a specific key/value pair
    func searchDatabase(usingKey key: String, value: String, systemID: Int?) async throws -> [ROMMetadata]?

    /// Search database using filename across multiple systems
    func searchDatabase(usingFilename filename: String, systemIDs: [Int]) async throws -> [ROMMetadata]?

    /// Get system ID for a ROM using MD5 or filename
    func system(forRomMD5 md5: String, or filename: String?) async throws -> Int?
}

/// Protocol specifically for artwork lookup operations
public protocol ArtworkLookupService {
    /// Get artwork mappings for ROMs
    func getArtworkMappings() async throws -> ArtworkMapping
}

/// Main lookup service that combines ROM metadata and artwork lookup capabilities
@globalActor
public actor PVLookup: ROMMetadataProvider, ArtworkLookupService {
    // MARK: - Singleton
    public static let shared = PVLookup()

    // MARK: - Properties
    private let openVGDB: OpenVGDB
    private let libreTroDB: libretrodb

    // MARK: - Initialization
    private init() {
        self.openVGDB = OpenVGDB()
        self.libreTroDB = libretrodb()
    }

    // MARK: - ROMMetadataProvider Implementation
    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        // Try OpenVGDB first
        if let result = try await searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)?.first {
            return result
        }

        // Fall back to libretrodb if no results
        return try libreTroDB.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)?.first
    }

    public func searchDatabase(usingKey key: String, value: String, systemID: Int?) async throws -> [ROMMetadata]? {
        // Try OpenVGDB first
        if let results = try openVGDB.searchDatabase(usingKey: key, value: value, systemID: systemID) {
            if !results.isEmpty {
                return results
            }
        }

        // Fall back to libretrodb if no results
        return try libreTroDB.searchDatabase(usingKey: key, value: value, systemID: systemID)
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]? {
        // Try OpenVGDB first
        if let results = try openVGDB.searchDatabase(usingFilename: filename, systemID: systemID) {
            if !results.isEmpty {
                return results
            }
        }

        // Fall back to libretrodb if no results
        return try libreTroDB.searchDatabase(usingFilename: filename, systemID: systemID)
    }

    public func searchDatabase(usingFilename filename: String, systemIDs: [Int]) async throws -> [ROMMetadata]? {
        // Try OpenVGDB first
        if let results = try openVGDB.searchDatabase(usingFilename: filename, systemIDs: systemIDs) {
            if !results.isEmpty {
                return results
            }
        }

        // Fall back to libretrodb if no results
        return try libreTroDB.searchDatabase(usingFilename: filename, systemIDs: systemIDs)
    }

    public func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        // Try OpenVGDB first
        if let systemID = try openVGDB.system(forRomMD5: md5, or: filename) {
            return systemID
        }

        // Fall back to libretrodb if no results
        return try libreTroDB.system(forRomMD5: md5, or: filename)
    }

    // MARK: - ArtworkLookupService Implementation
    public func getArtworkMappings() async throws -> ArtworkMapping {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let result = try openVGDB.getArtworkMappings()
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Database Search Methods
    public func searchDatabase(usingMD5 md5: String, systemID: Int?) async throws -> [ROMMetadata]? {
        return try await searchDatabase(usingKey: "romHashMD5", value: md5, systemID: systemID)
    }
}

// MARK: - Database Type Enums
public enum LocalDatabases: CaseIterable {
    case openVGDB
}

public enum RemoteDatabases: CaseIterable {
    case theGamesDB
}
