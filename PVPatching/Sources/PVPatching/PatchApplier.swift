//
//  PatchApplier.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Orchestrates ROM patch application.
///
/// `PatchApplier` selects the correct patcher for a given format, applies the patch
/// (or returns a cached result), and writes the output to the patch cache.
///
/// Original ROM files are **never modified**.
public actor PatchApplier {

    private let cache: PatchCache

    public init(cache: PatchCache = PatchCache()) {
        self.cache = cache
    }

    /// Apply a patch file to a ROM, returning a typed artifact with hashes and URL.
    ///
    /// - Parameters:
    ///   - patchURL: URL of the patch file.
    ///   - romURL: URL of the source ROM to patch.
    ///   - outputStem: Unique human-readable stem for the cached file / save directories.
    ///   - progress: Optional progress callback (0...1).
    public func apply(
        patchURL: URL,
        to romURL: URL,
        outputStem: String? = nil,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> PatchArtifact {
        guard FileManager.default.fileExists(atPath: patchURL.path) else {
            throw PatchError.patchFileNotFound(patchURL)
        }
        guard FileManager.default.fileExists(atPath: romURL.path) else {
            throw PatchError.sourceROMNotFound(romURL)
        }
        guard let format = PatchFormat.detect(from: patchURL) else {
            throw PatchError.unsupportedFormat(patchURL.pathExtension)
        }

        progress?(PatchProgress(fractionCompleted: 0.05, status: "Reading files…"))
        let patchFileData = try Data(contentsOf: patchURL, options: .mappedIfSafe)
        let romData = try Data(contentsOf: romURL, options: .mappedIfSafe)
        let stem = outputStem ?? Self.defaultOutputStem(
            romURL: romURL,
            patchURL: patchURL
        )
        let sourceSHA = PatchHashing.sha256Hex(romData)
        let patchSHA = PatchHashing.sha256Hex(patchFileData)

        if let cached = await cache.cachedURL(
            romData: romData,
            patchData: patchFileData,
            outputStem: stem,
            extension: romURL.pathExtension
        ) {
            progress?(PatchProgress(fractionCompleted: 1.0, status: "Using cached patch…"))
            let patchedData = try Data(contentsOf: cached, options: .mappedIfSafe)
            ILOG("PatchApplier: returning cached result for \(patchURL.lastPathComponent)")
            return PatchArtifact(
                url: cached,
                outputStem: stem,
                patchedMD5: PatchHashing.md5Hex(patchedData),
                patchedSHA256: PatchHashing.sha256Hex(patchedData),
                sourceSHA256: sourceSHA,
                patchSHA256: patchSHA,
                format: format,
                wasCached: true
            )
        }

        progress?(PatchProgress(fractionCompleted: 0.25, status: "Applying \(format.displayName)…"))
        ILOG("PatchApplier: applying \(format.displayName) patch '\(patchURL.lastPathComponent)' to '\(romURL.lastPathComponent)'")
        let patched = try applyPatch(format: format, patch: patchFileData, source: romData)
        progress?(PatchProgress(fractionCompleted: 0.85, status: "Caching patched ROM…"))

        do {
            let cachedURL = try await cache.store(
                patched,
                romData: romData,
                patchData: patchFileData,
                outputStem: stem,
                extension: romURL.pathExtension
            )
            progress?(PatchProgress(fractionCompleted: 1.0, status: "Done"))
            ILOG("PatchApplier: cached patched ROM at \(cachedURL.path)")
            return PatchArtifact(
                url: cachedURL,
                outputStem: stem,
                patchedMD5: PatchHashing.md5Hex(patched),
                patchedSHA256: PatchHashing.sha256Hex(patched),
                sourceSHA256: sourceSHA,
                patchSHA256: patchSHA,
                format: format,
                wasCached: false
            )
        } catch {
            throw PatchError.outputWriteFailed(error)
        }
    }

    /// Export a patched ROM copy into `directory` with a collision-safe name.
    public func exportPatchedCopy(
        patchURL: URL,
        romURL: URL,
        to directory: URL,
        preferredName: String? = nil,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> URL {
        let artifact = try await apply(
            patchURL: patchURL,
            to: romURL,
            outputStem: preferredName.map { ($0 as NSString).deletingPathExtension },
            progress: progress
        )
        let name = preferredName ?? "\(artifact.outputStem).\(romURL.pathExtension)"
        return try await cache.export(artifactURL: artifact.url, to: directory, preferredName: name)
    }

    /// Invalidate the cache entry for a specific ROM + patch pair.
    public func invalidateCache(patchURL: URL, romURL: URL) async throws {
        let romData = try Data(contentsOf: romURL, options: .mappedIfSafe)
        let patchData = try Data(contentsOf: patchURL, options: .mappedIfSafe)
        try await cache.remove(romData: romData, patchData: patchData)
    }

    /// Clear the entire patch cache.
    public func clearCache() async throws {
        try await cache.clearAll()
    }

    public static func defaultOutputStem(romURL: URL, patchURL: URL) -> String {
        let romStem = romURL.deletingPathExtension().lastPathComponent
        let patchStem = patchURL.deletingPathExtension().lastPathComponent
        if patchStem.localizedCaseInsensitiveContains(romStem) {
            return variantSafeStem(patchStem, romURL: romURL)
        }
        return "\(romStem) [\(patchStem)]"
    }

    /// Save states and battery saves are keyed by the ROM file stem (see `Paths.saveStatePath(forROM:)`).
    /// A variant whose stem equals the base ROM's stem would share — and on delete, wipe — the
    /// base game's saves. The same-filename convention (`Game.gba` + `Game.ips`) hits this
    /// exactly, so make sure a variant stem never equals the base stem.
    public static func variantSafeStem(_ stem: String, romURL: URL) -> String {
        let romStem = romURL.deletingPathExtension().lastPathComponent
        let trimmed = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(romStem) [patched]" }
        if trimmed.compare(romStem, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return "\(romStem) [patched]"
        }
        return trimmed
    }

    // MARK: - Private

    private func applyPatch(format: PatchFormat, patch: Data, source: Data) throws -> Data {
        switch format {
        case .ips:
            return try IPSPatcher().apply(patch: patch, to: source)
        case .ips32:
            return try IPSPatcher().apply(patch: patch, to: source, isIPS32: true)
        case .bps:
            return try BPSPatcher().apply(patch: patch, to: source)
        case .ups:
            return try UPSPatcher().apply(patch: patch, to: source)
        case .xdelta, .xdelta3:
            throw PatchError.unsupportedFormat("\(format.rawValue) — xdelta support coming in a future update")
        case .ppf:
            return try PPFPatcher().apply(patch: patch, to: source)
        case .aps, .rup, .nsp:
            throw PatchError.unsupportedFormat("\(format.displayName) — not yet implemented")
        }
    }
}
