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
/// Cache directory: `Documents/PatchedROMs/<key>/<outputStem>.<ext>` on iOS/macOS
/// (so `FileLocationResolver` / `PVFile` can resolve them), and
/// `Library/Caches/PatchedROMs/...` on tvOS.
public actor PatchCache {

    private let cacheDirectory: URL

    public init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.cacheDirectory = dir
        } else {
            self.cacheDirectory = Self.defaultCacheDirectory()
        }
    }

    /// Platform-appropriate root for patched ROM artifacts.
    public static func defaultCacheDirectory() -> URL {
#if os(tvOS)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
#else
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
#endif
        return base.appendingPathComponent("PatchedROMs", isDirectory: true)
    }

    // MARK: - Fingerprint fast path

    /// Cheap identity of the inputs: paths, sizes and modification dates. If none of these
    /// changed since the artifact was produced, the artifact is still valid and we can skip
    /// reading and hashing a possibly multi-hundred-megabyte ROM on every launch.
    struct InputFingerprint: Codable, Equatable {
        var romPath: String
        var romSize: Int
        var romModified: Double
        var patchPath: String
        var patchSize: Int
        var patchModified: Double
        var outputStem: String
        var revision: String

        static func make(romURL: URL, patchURL: URL, outputStem: String) -> InputFingerprint? {
            guard let rom = stat(romURL), let patch = stat(patchURL) else { return nil }
            return InputFingerprint(
                romPath: romURL.standardizedFileURL.path, romSize: rom.size, romModified: rom.modified,
                patchPath: patchURL.standardizedFileURL.path, patchSize: patch.size, patchModified: patch.modified,
                outputStem: outputStem, revision: PatchHashing.patcherRevision
            )
        }

        /// Stable file name for the sidecar; derived from the fingerprint itself.
        var fileName: String {
            let text = "\(romPath)|\(romSize)|\(romModified)|\(patchPath)|\(patchSize)|\(patchModified)|\(outputStem)|\(revision)"
            return String(PatchHashing.sha256Hex(Data(text.utf8)).prefix(32)) + ".json"
        }
    }

    struct CachedArtifactRecord: Codable {
        var fingerprint: InputFingerprint
        var artifact: PatchArtifact
        var outputSize: Int
        var outputModified: Double
    }

    static func stat(_ url: URL) -> (size: Int, modified: Double)? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.intValue,
              let date = attrs[.modificationDate] as? Date else { return nil }
        return (size, date.timeIntervalSince1970)
    }

    private var fingerprintDirectory: URL {
        cacheDirectory.appendingPathComponent(".fingerprints", isDirectory: true)
    }

    /// Return the artifact for these inputs without touching ROM bytes, when the sidecar
    /// says nothing changed and the cached output is still intact.
    public func fastLookup(romURL: URL, patchURL: URL, outputStem: String) -> PatchArtifact? {
        guard let fingerprint = InputFingerprint.make(romURL: romURL, patchURL: patchURL, outputStem: outputStem) else {
            return nil
        }
        let sidecar = fingerprintDirectory.appendingPathComponent(fingerprint.fileName)
        guard let data = try? Data(contentsOf: sidecar),
              let record = try? JSONDecoder().decode(CachedArtifactRecord.self, from: data),
              record.fingerprint == fingerprint,
              let output = Self.stat(record.artifact.url),
              output.size == record.outputSize,
              output.modified == record.outputModified else {
            return nil
        }
        var artifact = record.artifact
        artifact.wasCached = true
        return artifact
    }

    /// Remember a produced (or verified) artifact so the next lookup can skip hashing.
    public func recordFastLookup(_ artifact: PatchArtifact, romURL: URL, patchURL: URL) {
        guard let fingerprint = InputFingerprint.make(romURL: romURL, patchURL: patchURL, outputStem: artifact.outputStem),
              let output = Self.stat(artifact.url) else { return }
        let record = CachedArtifactRecord(
            fingerprint: fingerprint, artifact: artifact,
            outputSize: output.size, outputModified: output.modified
        )
        do {
            try FileManager.default.createDirectory(at: fingerprintDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(record)
            try data.write(to: fingerprintDirectory.appendingPathComponent(fingerprint.fileName), options: .atomic)
        } catch {
            // Best effort: the slow path still works without the sidecar.
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
