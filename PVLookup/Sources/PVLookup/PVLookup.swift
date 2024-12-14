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
    private let database: OpenVGDB

    // MARK: - Initialization
    private init() {
        self.database = OpenVGDB()
    }

    // MARK: - ROMMetadataProvider Implementation
    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let result = try database.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)?.first
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let result = try database.searchDatabase(usingFilename: filename, systemID: systemID)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let result = try database.system(forRomMD5: md5, or: filename)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - ArtworkLookupService Implementation
    public func getArtworkMappings() async throws -> ArtworkMapping {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let result = try database.getArtworkMappings()
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Database Type Enums
public enum LocalDatabases: CaseIterable {
    case openVGDB
}

public enum RemoteDatabases: CaseIterable {
    case theGamesDB
}
