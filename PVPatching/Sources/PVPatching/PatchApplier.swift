//
//  PatchApplier.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Options for one patch application.
public struct PatchApplyOptions: Sendable, Equatable {
    /// Apply even when the ROM does not match what the patch was made for: skips the source
    /// CRC32 (BPS, UPS), the size and block checks (PPF) and the window checksums (xdelta3).
    /// The patched result then usually differs from what the patch author shipped.
    public var ignoreSourceChecksum: Bool

    public init(ignoreSourceChecksum: Bool = false) {
        self.ignoreSourceChecksum = ignoreSourceChecksum
    }
}

/// Orchestrates ROM patch application.
///
/// `PatchApplier` hands the patch to PVPatchEngine, which streams the result straight into the
/// patch cache, so disc images of several gigabytes patch in bounded memory. Inputs and outputs
/// are hashed by streaming too. A cache hit returns without patching.
///
/// Original ROM files are **never modified**.
public actor PatchApplier {

    private let cache: PatchCache
    /// Running applications by output path, so two launches of the same variant share one run
    /// instead of both writing the same `.partial` file.
    private var inFlight: [String: Task<PatchArtifact, Error>] = [:]

    /// Room kept free beyond the patched file itself.
    static let freeSpaceMargin: UInt64 = 64 * 1024 * 1024

    public init(cache: PatchCache = PatchCache()) {
        self.cache = cache
    }

    /// Apply a patch file to a ROM, returning a typed artifact with hashes and URL.
    ///
    /// - Parameters:
    ///   - patchURL: URL of the patch file.
    ///   - romURL: URL of the source ROM to patch.
    ///   - outputStem: Unique human-readable stem for the cached file / save directories.
    ///   - options: Per-application options, such as ignoring a source mismatch.
    ///   - progress: Optional progress callback (0...1), called from a background thread.
    public func apply(
        patchURL: URL,
        to romURL: URL,
        outputStem: String? = nil,
        options: PatchApplyOptions = PatchApplyOptions(),
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> PatchArtifact {
        guard FileManager.default.fileExists(atPath: patchURL.path) else {
            throw PatchError.patchFileNotFound(patchURL)
        }
        guard FileManager.default.fileExists(atPath: romURL.path) else {
            throw PatchError.sourceROMNotFound(romURL)
        }
        guard let format = PatchFormat.detect(fileAt: patchURL) else {
            throw PatchError.unsupportedFormat(patchURL.pathExtension)
        }
        guard format.isImplemented else {
            throw PatchError.unsupportedFormat("\(format.displayName) — not yet implemented")
        }

        let stem = outputStem ?? Self.defaultOutputStem(
            romURL: romURL,
            patchURL: patchURL
        )

        // Fast path: unchanged inputs (size + mtime) and an intact output → no ROM read at all.
        if let fast = await cache.fastLookup(romURL: romURL, patchURL: patchURL, outputStem: stem) {
            progress?(PatchProgress(fractionCompleted: 1.0, status: "Using cached patch…"))
            ILOG("PatchApplier: fingerprint hit for \(patchURL.lastPathComponent)")
            return fast
        }

        let info = try EngineBridge.inspect(patchURL)
        if let reason = info.unsupportedReason {
            throw PatchError.unsupportedFormat(reason)
        }

        // Hashing runs off the actor (a disc takes seconds, and other launches' fast lookups
        // must not wait) and stops when the caller is cancelled.
        progress?(PatchProgress(fractionCompleted: 0, status: "Checking ROM…"))
        let (romSHA, patchSHA) = try await Self.mapCancellation {
            try await Self.inputDigests(romURL: romURL, patchURL: patchURL, progress: progress)
        }

        let key = PatchHashing.cacheKey(romSHA256: romSHA, patchSHA256: patchSHA)
        let ext = romURL.pathExtension
        let outputURL = try await cache.preparedEntryURL(key: key, outputStem: stem, extension: ext)

        if let running = inFlight[outputURL.path] {
            return try await running.value
        }
        let cache = self.cache
        let task = Task<PatchArtifact, Error> {
            let artifact = try await Self.resolve(
                ResolveRequest(
                    patchURL: patchURL, romURL: romURL, outputURL: outputURL, key: key, stem: stem, ext: ext,
                    format: format, info: info, romSHA: romSHA, patchSHA: patchSHA, options: options
                ),
                cache: cache,
                progress: progress
            )
            await cache.recordFastLookup(artifact, romURL: romURL, patchURL: patchURL)
            return artifact
        }
        inFlight[outputURL.path] = task
        defer { inFlight[outputURL.path] = nil }
        return try await Self.mapCancellation {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        }
    }

    /// Export a patched ROM copy into `directory` with a collision-safe name.
    public func exportPatchedCopy(
        patchURL: URL,
        romURL: URL,
        to directory: URL,
        preferredName: String? = nil,
        options: PatchApplyOptions = PatchApplyOptions(),
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> URL {
        let artifact = try await apply(
            patchURL: patchURL,
            to: romURL,
            outputStem: preferredName.map { ($0 as NSString).deletingPathExtension },
            options: options,
            progress: progress
        )
        let name = preferredName ?? "\(artifact.outputStem).\(romURL.pathExtension)"
        return try await cache.export(artifactURL: artifact.url, to: directory, preferredName: name)
    }

    /// Invalidate the cache entry for a specific ROM + patch pair.
    public func invalidateCache(patchURL: URL, romURL: URL) async throws {
        let (romSHA, patchSHA) = try await Self.inputDigests(romURL: romURL, patchURL: patchURL, progress: nil)
        try await cache.remove(key: PatchHashing.cacheKey(romSHA256: romSHA, patchSHA256: patchSHA))
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

    /// Shares of the progress bar: hashing the ROM, then patching, then hashing the result.
    private static let hashingShare = 0.2
    private static let patchingShare = 0.6

    private struct ResolveRequest: Sendable {
        var patchURL: URL
        var romURL: URL
        var outputURL: URL
        var key: String
        var stem: String
        var ext: String
        var format: PatchFormat
        var info: EnginePatchInfo
        var romSHA: String
        var patchSHA: String
        var options: PatchApplyOptions
    }

    /// SHA-256 of the ROM and the patch, streamed. Nonisolated, so it runs off the actor.
    private nonisolated static func inputDigests(
        romURL: URL,
        patchURL: URL,
        progress: (@Sendable (PatchProgress) -> Void)?
    ) async throws -> (rom: String, patch: String) {
        let romSize = fileSize(romURL)
        let rom = try FileDigest.compute(romURL, kinds: .sha256) { done in
            guard romSize > 0 else { return }
            progress?(PatchProgress(fractionCompleted: hashingShare * Double(done) / Double(romSize), status: "Checking ROM…"))
        }
        let patch = try FileDigest.compute(patchURL, kinds: .sha256)
        return (rom.sha256 ?? "", patch.sha256 ?? "")
    }

    /// Reports a cancelled hash or wait as `PatchError.cancelled`, like a cancelled engine run.
    private nonisolated static func mapCancellation<T: Sendable>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch is CancellationError {
            throw PatchError.cancelled
        }
    }

    /// Returns the cached entry, or patches into it.
    private nonisolated static func resolve(
        _ request: ResolveRequest,
        cache: PatchCache,
        progress: (@Sendable (PatchProgress) -> Void)?
    ) async throws -> PatchArtifact {
        let outputURL: URL
        let wasCached: Bool
        var checked: Bool?
        if let cached = await cache.cachedURL(key: request.key, outputStem: request.stem, extension: request.ext) {
            ILOG("PatchApplier: returning cached result for \(request.patchURL.lastPathComponent)")
            outputURL = cached
            wasCached = true
        } else {
            try ensureFreeSpace(for: request, in: cache.rootDirectory)
            let status = "Applying \(request.format.displayName)…"
            ILOG("PatchApplier: applying \(request.format.displayName) patch '\(request.patchURL.lastPathComponent)' to '\(request.romURL.lastPathComponent)'")
            progress?(PatchProgress(fractionCompleted: hashingShare, status: status))
            let report: EngineApplyReport
            do {
                report = try await EngineBridge.apply(
                    patch: request.patchURL,
                    source: request.romURL,
                    output: request.outputURL,
                    format: request.format,
                    ignoreSourceChecksum: request.options.ignoreSourceChecksum
                ) { fraction in
                    progress?(PatchProgress(fractionCompleted: hashingShare + patchingShare * fraction, status: status))
                }
            } catch {
                removeEntryDirectoryIfEmpty(request.outputURL.deletingLastPathComponent())
                throw error
            }
            if report.ignoredTargetMismatch {
                WLOG("PatchApplier: '\(request.patchURL.lastPathComponent)' applied to a ROM it was not made for; the result differs from the patch's target")
            }
            outputURL = request.outputURL
            wasCached = false
            checked = report.checkedAgainstSource
        }

        let outputSize = fileSize(outputURL)
        let base = hashingShare + patchingShare
        let digest = try FileDigest.compute(outputURL, kinds: .all) { done in
            guard outputSize > 0 else { return }
            progress?(PatchProgress(
                fractionCompleted: base + (1 - base) * Double(done) / Double(outputSize),
                status: "Hashing patched ROM…"
            ))
        }
        progress?(PatchProgress(fractionCompleted: 1.0, status: wasCached ? "Using cached patch…" : "Done"))
        return PatchArtifact(
            url: outputURL,
            outputStem: request.stem,
            patchedMD5: digest.md5 ?? "",
            patchedSHA256: digest.sha256 ?? "",
            sourceSHA256: request.romSHA,
            patchSHA256: request.patchSHA,
            format: request.format,
            wasCached: wasCached,
            patchedCRC32: digest.crc32,
            checkedAgainstSource: checked
        )
    }

    /// A failed or refused apply leaves no empty entry directory behind.
    private nonisolated static func removeEntryDirectoryIfEmpty(_ directory: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path), contents.isEmpty else {
            return
        }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Refuses to start a patch whose output cannot fit, instead of failing near the end of a disc.
    private nonisolated static func ensureFreeSpace(for request: ResolveRequest, in directory: URL) throws {
        let sourceSize = fileSize(request.romURL)
        // Formats without a declared size patch roughly in place (IPS, PPF) or grow modestly.
        let required = (request.info.targetSize ?? sourceSize) + freeSpaceMargin
        guard let available = availableCapacity(at: directory), available < required else { return }
        removeEntryDirectoryIfEmpty(request.outputURL.deletingLastPathComponent())
        throw PatchError.insufficientStorage(required: required, available: available)
    }

    nonisolated static func availableCapacity(at directory: URL) -> UInt64? {
        var probe = directory
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
#if os(tvOS) || os(watchOS)
        guard let capacity = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity else {
            return nil
        }
        return UInt64(max(capacity, 0))
#else
        guard let capacity = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        return UInt64(max(capacity, 0))
#endif
    }

    private nonisolated static func fileSize(_ url: URL) -> UInt64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
