//
//  PatchCache.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import CryptoKit

/// Manages a disk cache of pre-applied patched ROMs.
///
/// Cache entries are keyed by a hash derived from both the source ROM and the patch file,
/// so changing either invalidates the cache entry. Original ROMs are never modified.
///
/// Cache directory: `Library/Caches/PVPatchedROMs/<key>/patched.<ext>`
public actor PatchCache: Sendable {

    private let cacheDirectory: URL

    public init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.cacheDirectory = dir
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = caches.appendingPathComponent("PVPatchedROMs", isDirectory: true)
        }
    }

    /// Look up a cached patched ROM for the given source + patch combination.
    ///
    /// - Parameters:
    ///   - romURL: URL of the original (source) ROM.
    ///   - patchURL: URL of the patch file.
    /// - Returns: URL of the cached patched ROM, or `nil` if not cached.
    public func cachedURL(romURL: URL, patchURL: URL) -> URL? {
        guard let key = cacheKey(romURL: romURL, patchURL: patchURL) else { return nil }
        let candidate = cacheEntry(for: key, extension: romURL.pathExtension)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Store patched ROM data in the cache.
    ///
    /// - Parameters:
    ///   - data: The patched ROM data to cache.
    ///   - romURL: URL of the original source ROM (used for key + extension).
    ///   - patchURL: URL of the patch file (used for key).
    /// - Returns: URL of the saved cached file.
    public func store(_ data: Data, romURL: URL, patchURL: URL) throws -> URL {
        guard let key = cacheKey(romURL: romURL, patchURL: patchURL) else {
            throw PatchError.patchApplicationFailed("Could not compute cache key")
        }
        let entryDir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: entryDir, withIntermediateDirectories: true)
        let outputURL = cacheEntry(for: key, extension: romURL.pathExtension)
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
    public func remove(romURL: URL, patchURL: URL) throws {
        guard let key = cacheKey(romURL: romURL, patchURL: patchURL) else { return }
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

    /// Cache key is SHA256(romSHA256 + patchSHA256).
    private func cacheKey(romURL: URL, patchURL: URL) -> String? {
        guard let romData = try? Data(contentsOf: romURL, options: .mappedIfSafe),
              let patchData = try? Data(contentsOf: patchURL, options: .mappedIfSafe) else {
            return nil
        }
        let romHash = SHA256.hash(data: romData).compactMap { String(format: "%02x", $0) }.joined()
        let patchHash = SHA256.hash(data: patchData).compactMap { String(format: "%02x", $0) }.joined()
        let combined = Data((romHash + patchHash).utf8)
        return SHA256.hash(data: combined).compactMap { String(format: "%02x", $0) }.joined().prefix(32).description
    }
}
