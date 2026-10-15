//
//  EngineBridge.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The only file that imports PVPatchEngine. The engine declares its own `PatchFormat`,
//  `PatchError` and `PatchProgress`; keeping the import here means every other PVPatching file
//  (and every client) sees PVPatching's types only.
//

import Foundation
import PVPatchEngine

/// What the engine reads from a patch header, in PVPatching terms.
struct EnginePatchInfo: Sendable, Equatable {
    var format: PatchFormat
    var sourceSize: UInt64?
    var minimumSourceSize: UInt64?
    var targetSize: UInt64?
    var sourceCRC32: UInt32?
    var targetCRC32: UInt32?
    var patchDescription: String?
    var canVerifyIntegrity: Bool
    /// Set when the engine cannot apply the patch (an xdelta3 secondary compressor it lacks).
    var unsupportedReason: String?
}

/// What one engine run produced.
struct EngineApplyReport: Sendable, Equatable {
    var bytesWritten: UInt64
    /// The source or the result was checked against the patch and matched.
    var checkedAgainstSource: Bool
    /// `ignoreSourceChecksum` was set and the result differs from the target the patch describes.
    var ignoredTargetMismatch: Bool
}

enum EngineBridge {
    /// Images an IPS record may extend past the source by. The in-memory IPS patcher refused more
    /// than this; the engine's own limit (64 GiB) is meant for disc formats with a declared size.
    static let maxIPSGrowth: UInt64 = 256 * 1024 * 1024

    // MARK: - Formats

    static func engineFormat(_ format: PatchFormat) -> PVPatchEngine.PatchFormat? {
        switch format {
        case .ips: return .ips
        case .ips32: return .ips32
        case .bps: return .bps
        case .ups: return .ups
        case .ppf: return .ppf
        case .xdelta, .xdelta3: return .xdelta3
        case .aps, .rup, .nsp: return nil
        }
    }

    /// Format from the file's magic bytes. `nameHint` keeps the extension's case when it agrees
    /// (a `.xdelta` file stays `.xdelta`, which is what `PVPatch.formatRawValue` already stores).
    static func detect(fileAt url: URL, nameHint: PatchFormat?) -> PatchFormat? {
        guard let detected = PVPatchEngine.PatchEngine.detectFormat(url) else { return nil }
        switch detected {
        case .ips: return .ips
        case .ips32: return .ips32
        case .bps: return .bps
        case .ups: return .ups
        case .ppf: return .ppf
        case .xdelta3: return nameHint == .xdelta ? .xdelta : .xdelta3
        }
    }

    // MARK: - Inspect

    static func inspect(_ url: URL) throws -> EnginePatchInfo {
        let info: PVPatchEngine.PatchInfo
        do {
            info = try PVPatchEngine.PatchEngine.inspect(patch: url)
        } catch let error as PVPatchEngine.PatchError {
            throw map(error, patchURL: url)
        }
        let hint = PatchFormat.detect(from: url)
        let format = detect(fileAt: url, nameHint: hint) ?? hint ?? .xdelta3
        var unsupported: String?
        if let compression = info.secondaryCompression, !compression.isSupported {
            unsupported = "\(format.displayName) patches compressed with \(compression) are not supported"
        }
        return EnginePatchInfo(
            format: format,
            sourceSize: info.sourceSize,
            minimumSourceSize: info.minimumSourceSize,
            targetSize: info.targetSize,
            sourceCRC32: info.sourceCRC32,
            targetCRC32: info.targetCRC32,
            patchDescription: info.description,
            canVerifyIntegrity: info.canVerifyIntegrity,
            unsupportedReason: unsupported
        )
    }

    // MARK: - Apply

    /// Streams `patch` onto `source` into `output`. The engine writes `<output>.partial` and renames it,
    /// so `output` is either the complete result or untouched.
    ///
    /// - Parameter progress: fraction of the engine's own work, 0...1.
    static func apply(
        patch: URL,
        source: URL,
        output: URL,
        format: PatchFormat,
        ignoreSourceChecksum: Bool,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> EngineApplyReport {
        guard let engineFormat = engineFormat(format) else {
            throw PatchError.unsupportedFormat("\(format.displayName) — not yet implemented")
        }
        var options = PVPatchEngine.PatchOptions(ignoreSourceChecksum: ignoreSourceChecksum)
        if engineFormat == .ips || engineFormat == .ips32 {
            let sourceSize = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?
                .uint64Value ?? 0
            options.maxOutputSize = sourceSize + maxIPSGrowth
        }
        var engineProgress: (@Sendable (PVPatchEngine.PatchProgress) -> Void)?
        if let progress {
            engineProgress = { update in progress(update.fractionCompleted) }
        }
        do {
            let result = try await PVPatchEngine.PatchEngine.apply(
                patch: patch,
                source: source,
                output: output,
                options: options,
                progress: engineProgress
            )
            return EngineApplyReport(
                bytesWritten: result.bytesWritten,
                checkedAgainstSource: result.checkedAgainstSource,
                ignoredTargetMismatch: result.ignoredTargetMismatch != nil
            )
        } catch let error as PVPatchEngine.PatchError {
            throw map(error, patchURL: patch)
        } catch is CancellationError {
            throw PatchError.cancelled
        }
    }

    /// Applies in-memory buffers through temporary files, for the `Data` patcher API.
    static func apply(format: PatchFormat, patch: Data, source: Data) async throws -> Data {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVPatching-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        // The extension matters for IPS32 patches that start with "PATCH".
        let ext = format.fileExtensions.first ?? "patch"
        let patchURL = scratch.appendingPathComponent("patch.\(ext)")
        let sourceURL = scratch.appendingPathComponent("source.bin")
        let outputURL = scratch.appendingPathComponent("output.bin")
        try patch.write(to: patchURL)
        try source.write(to: sourceURL)
        // The Data API names its format; refuse a patch whose magic says otherwise, as the
        // per-format patchers did, instead of applying it as whatever it really is.
        guard let wanted = engineFormat(format) else {
            throw PatchError.unsupportedFormat("\(format.displayName) — not yet implemented")
        }
        let detected = PVPatchEngine.PatchEngine.detectFormat(patchURL)
        let sameFamily = detected == wanted || (wanted == .ips32 && detected == .ips)
        guard sameFamily else {
            if detected == nil, format == .ppf, patch.starts(with: Array("PPF".utf8)) {
                throw PatchError.unsupportedFormat("PPF version is not supported (only 1.0, 2.0, 3.0)")
            }
            throw PatchError.corruptPatchFile("Invalid \(format.displayName) header")
        }
        _ = try await apply(
            patch: patchURL,
            source: sourceURL,
            output: outputURL,
            format: format,
            ignoreSourceChecksum: false
        )
        return try Data(contentsOf: outputURL)
    }

    // MARK: - Errors

    static func map(_ error: PVPatchEngine.PatchError, patchURL: URL) -> PatchError {
        switch error {
        case .sourceMismatch, .sourceSizeMismatch:
            return .sourceROMMismatch
        case .targetMismatch:
            return .patchedROMVerificationFailed
        case .truncatedPatch:
            return .corruptPatchFile("The patch file is incomplete")
        case .corruptPatch(let reason):
            return .corruptPatchFile(reason)
        case .unsupportedFormat:
            let ext = patchURL.pathExtension
            return .unsupportedFormat(ext.isEmpty ? "unknown patch format" : ext)
        case .unsupportedSecondaryCompression:
            return .unsupportedFormat("xdelta3 patch compressed with LZMA")
        case .outputTooLarge:
            return .corruptPatchFile("The patched file would be larger than allowed")
        case .cancelled:
            return .cancelled
        case .io(let underlying):
            return .outputWriteFailed(underlying)
        }
    }
}
