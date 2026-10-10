//
//  PatchCache.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Manages a disk cache of pre-applied patched ROMs.
///
/// Cache entries are keyed by a hash derived from both the source ROM and the patch file,
/// so changing either invalidates the cache entry. Original ROMs are never modified.
///
/// Cache directory: `Library/Caches/PVPatchedROMs/<key>/<outputStem>.<ext>`
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
    public func cachedURL(
        romData: Data,
        patchData: Data,
        outputStem: String,
        extension ext: String
    ) -> URL? {
        let key = PatchHashing.cacheKey(romData: romData, patchData: patchData)
        let candidate = cacheEntry(for: key, outputStem: outputStem, extension: ext)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        // Migrate older "patched.<ext>" cache entries into the unique name.
        let legacy = cacheEntry(for: key, outputStem: "patched", extension: ext)
        if FileManager.default.fileExists(atPath: legacy.path) {
            do {
                try FileManager.default.moveItem(at: legacy, to: candidate)
                return candidate
            } catch {
                return legacy
            }
        }
        return nil
    }

    /// Store patched ROM data in the cache.
    public func store(
        _ data: Data,
        romData: Data,
        patchData: Data,
        outputStem: String,
        extension ext: String
    ) throws -> URL {
        let key = PatchHashing.cacheKey(romData: romData, patchData: patchData)
        let entryDir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: entryDir, withIntermediateDirectories: true)
        let outputURL = cacheEntry(for: key, outputStem: outputStem, extension: ext)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    /// Copy a cached (or newly applied) artifact into a destination directory with a
    /// collision-safe filename. Never overwrites an existing different file.
    public func export(
        artifactURL: URL,
        to directory: URL,
        preferredName: String
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preferred = directory.appendingPathComponent(preferredName)
        if !FileManager.default.fileExists(atPath: preferred.path) {
            try FileManager.default.copyItem(at: artifactURL, to: preferred)
            return preferred
        }
        let stem = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var index = 1
        while true {
            let candidateName = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                try FileManager.default.copyItem(at: artifactURL, to: candidate)
                return candidate
            }
            index += 1
        }
    }

    /// Remove all cached patched ROMs.
    public func clearAll() throws {
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
    }

    /// Remove the cached entry for a specific ROM + patch pair.
    public func remove(romData: Data, patchData: Data) throws {
        let key = PatchHashing.cacheKey(romData: romData, patchData: patchData)
        let entryDir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        if FileManager.default.fileExists(atPath: entryDir.path) {
            try FileManager.default.removeItem(at: entryDir)
        }
    }

    // MARK: - Private helpers

    private func cacheEntry(for key: String, outputStem: String, extension ext: String) -> URL {
        let dir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        let safeStem = sanitizedStem(outputStem)
        let suffix = ext.isEmpty ? "rom" : ext
        return dir.appendingPathComponent("\(safeStem).\(suffix)")
    }

    private func sanitizedStem(_ stem: String) -> String {
        let trimmed = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = trimmed.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }
        let value = String(cleaned)
        return value.isEmpty ? "patched" : value
    }
}
