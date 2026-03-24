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
///
/// ## Usage
/// ```swift
/// let applier = PatchApplier()
/// let patchedURL = try await applier.apply(patchURL: patchURL, to: romURL)
/// // Pass patchedURL to the emulator core
/// ```
public actor PatchApplier {

    private let cache: PatchCache

    public init(cache: PatchCache = PatchCache()) {
        self.cache = cache
    }

    /// Apply a patch file to a ROM, returning the URL of the patched ROM.
    ///
    /// If a valid cached result exists, it is returned immediately without re-patching.
    ///
    /// - Parameters:
    ///   - patchURL: URL of the patch file.
    ///   - romURL: URL of the source ROM to patch.
    /// - Returns: URL of the patched ROM in the patch cache.
    /// - Throws: `PatchError` if the format is unsupported or patching fails.
    public func apply(patchURL: URL, to romURL: URL) async throws -> URL {
        guard FileManager.default.fileExists(atPath: patchURL.path) else {
            throw PatchError.patchFileNotFound(patchURL)
        }
        guard FileManager.default.fileExists(atPath: romURL.path) else {
            throw PatchError.sourceROMNotFound(romURL)
        }

        guard let format = PatchFormat.detect(from: patchURL) else {
            throw PatchError.unsupportedFormat(patchURL.pathExtension)
        }

        // Load files once; use data for both the cache key check and patch application.
        let patchFileData = try Data(contentsOf: patchURL, options: .mappedIfSafe)
        let romData       = try Data(contentsOf: romURL, options: .mappedIfSafe)

        // Return cached result if available
        if let cached = await cache.cachedURL(romData: romData, patchData: patchFileData, extension: romURL.pathExtension) {
            ILOG("PatchApplier: returning cached result for \(patchURL.lastPathComponent)")
            return cached
        }

        ILOG("PatchApplier: applying \(format.displayName) patch '\(patchURL.lastPathComponent)' to '\(romURL.lastPathComponent)'")

        let patched = try applyPatch(format: format, patch: patchFileData, source: romData)

        do {
            let cachedURL = try await cache.store(patched, romData: romData, patchData: patchFileData, extension: romURL.pathExtension)
            ILOG("PatchApplier: cached patched ROM at \(cachedURL.path)")
            return cachedURL
        } catch {
            throw PatchError.outputWriteFailed(error)
        }
    }

    /// Invalidate the cache entry for a specific ROM + patch pair.
    public func invalidateCache(patchURL: URL, romURL: URL) async throws {
        let romData   = try Data(contentsOf: romURL, options: .mappedIfSafe)
        let patchData = try Data(contentsOf: patchURL, options: .mappedIfSafe)
        try await cache.remove(romData: romData, patchData: patchData)
    }

    /// Clear the entire patch cache.
    public func clearCache() async throws {
        try await cache.clearAll()
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
