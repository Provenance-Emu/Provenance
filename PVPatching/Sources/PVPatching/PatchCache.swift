//
//  PatchCache.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Manages a disk cache of pre-applied patched ROMs.
///
/// Cache entries are keyed by a hash derived from both the source ROM and the patch file,
/// so changing either invalidates the cache entry. Original ROMs are never modified.
///
/// Cache directory: `Library/Caches/PVPatchedROMs/<key>/patched.<ext>`
public actor PatchCache {

    private let cacheDirectory: URL

    public init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.cacheDirectory = dir
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.cacheDirectory = caches.appendingPathComponent("PVPatchedROMs", isDirectory: true)
        }
    }

    /// Look up a cached patched ROM using already-loaded file data.
    ///
    /// - Parameters:
    ///   - romData: The source ROM data (used to compute cache key).
    ///   - patchData: The patch file data (used to compute cache key).
    ///   - ext: The file extension of the original ROM (for the cached filename).
    /// - Returns: URL of the cached patched ROM, or `nil` if not cached.
    public func cachedURL(romData: Data, patchData: Data, extension ext: String) -> URL? {
        let key = cacheKey(romData: romData, patchData: patchData)
        let candidate = cacheEntry(for: key, extension: ext)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Store patched ROM data in the cache.
    ///
    /// - Parameters:
    ///   - data: The patched ROM data to cache.
    ///   - romData: The source ROM data (used to compute cache key).
    ///   - patchData: The patch file data (used to compute cache key).
    ///   - ext: File extension for the cached output file.
    /// - Returns: URL of the saved cached file.
    public func store(_ data: Data, romData: Data, patchData: Data, extension ext: String) throws -> URL {
        let key = cacheKey(romData: romData, patchData: patchData)
        let entryDir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: entryDir, withIntermediateDirectories: true)
        let outputURL = cacheEntry(for: key, extension: ext)
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    /// Remove all cached patched ROMs.
    public func clearAll() throws {
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
    }

    /// Remove the cached entry for a specific ROM + patch pair.
    public func remove(romData: Data, patchData: Data) throws {
        let key = cacheKey(romData: romData, patchData: patchData)
        let entryDir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        if FileManager.default.fileExists(atPath: entryDir.path) {
            try FileManager.default.removeItem(at: entryDir)
        }
    }

    // MARK: - Private helpers

    private func cacheEntry(for key: String, extension ext: String) -> URL {
        let dir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        return dir.appendingPathComponent("patched.\(ext.isEmpty ? "rom" : ext)")
    }

    /// Cache key derived from the rom and patch data.
    private func cacheKey(romData: Data, patchData: Data) -> String {
#if canImport(CryptoKit)
        let romHash = SHA256.hash(data: romData).compactMap { String(format: "%02x", $0) }.joined()
        let patchHash = SHA256.hash(data: patchData).compactMap { String(format: "%02x", $0) }.joined()
        let combined = Data((romHash + patchHash).utf8)
        return String(SHA256.hash(data: combined).compactMap { String(format: "%02x", $0) }.joined().prefix(32))
#else
        // Linux fallback: use shared CRC32 helper for deterministic key on platforms without CryptoKit.
        let romCRC = patchCRC32(romData)
        let patchCRC = patchCRC32(patchData)
        return String(format: "%08x%08x%08x%08x", romCRC, patchCRC, romData.count, patchData.count)
#endif
    }
}
