//
//  PatchEngine.swift
//  PVPatchEngine
//
//  Applies ROM and disc patches by streaming to an output file, so a 1.4 GB GameCube image or an
//  8.5 GB Wii image patches within a fixed memory budget on a phone.
//

import Foundation

public enum PatchEngine {
    // MARK: - Detection and inspection

    /// Identifies a patch by its magic bytes. `.ips32` is told apart from `.ips` by the "IPS32"
    /// magic or, for IPS32 files that start with "PATCH", the `.ips32` extension.
    /// Returns nil when the file is unreadable or not a supported patch.
    public static func detectFormat(_ patchURL: URL) -> PatchFormat? {
        guard let file = try? PosixFile(readingAt: patchURL.path) else { return nil }
        var head = [UInt8](repeating: 0, count: 8)
        let got = head.withUnsafeMutableBytes { (try? file.read(into: $0.baseAddress!, count: 8, at: 0)) ?? 0 }
        let magic = Array(head.prefix(got))
        func hasPrefix(_ text: String) -> Bool { magic.starts(with: Array(text.utf8)) }

        if hasPrefix("IPS32") { return .ips32 }
        if hasPrefix("PATCH") { return patchURL.pathExtension.lowercased() == "ips32" ? .ips32 : .ips }
        if hasPrefix("BPS1") { return .bps }
        if hasPrefix("UPS1") { return .ups }
        if (try? PPFApplier.parseVersion(magic: magic)) ?? nil != nil { return .ppf }
        if magic.starts(with: [0xD6, 0xC3, 0xC4]) { return .xdelta3 }
        return nil
    }

    /// Reads what the patch declares about itself without applying it.
    public static func inspect(patch patchURL: URL) throws -> PatchInfo {
        guard let format = detectFormat(patchURL) else { throw PatchError.unsupportedFormat }
        let file = try PosixFile(readingAt: patchURL.path)
        var info = PatchInfo(format: format, patchSize: file.size)
        switch format {
        case .ips, .ips32:
            break
        case .bps:
            let header = try BPSApplier.readHeader(file)
            info.sourceSize = header.sourceSize
            info.targetSize = header.targetSize
            info.sourceCRC32 = header.sourceCRC32
            info.targetCRC32 = header.targetCRC32
            info.patchCRC32 = header.patchCRC32
            info.description = text(header.metadata)
            info.canVerifyIntegrity = true
        case .ups:
            let header = try UPSApplier.readHeader(file)
            info.sourceSize = header.inputSize
            info.targetSize = header.outputSize
            info.sourceCRC32 = header.inputCRC32
            info.targetCRC32 = header.outputCRC32
            info.patchCRC32 = header.patchCRC32
            info.canVerifyIntegrity = true
        case .ppf:
            try inspectPPF(file, into: &info)
        case .xdelta3:
            let summary = try VCDIFFScanner.scan(file)
            info.targetSize = summary.targetSize
            info.minimumSourceSize = summary.requiredSourceSize > 0 ? summary.requiredSourceSize : nil
            info.secondaryCompression = summary.secondaryCompression
            info.canVerifyIntegrity = summary.windowsWithAdler32 > 0
        }
        return info
    }

    private static func inspectPPF(_ file: PosixFile, into info: inout PatchInfo) throws {
        let reader = PatchStreamReader(file: file, end: file.size)
        var header = [UInt8](repeating: 0, count: Int(PPFApplier.commonHeaderLength))
        try header.withUnsafeMutableBytes { try reader.readBytes(into: $0.baseAddress!, count: $0.count) }
        let start = Int(PPFApplier.descriptionOffset)
        info.description = text(Data(header[start..<(start + PPFApplier.descriptionLength)]))
        switch try PPFApplier.parseVersion(magic: header) {
        case .v2:
            let declared = try reader.readLittleEndian(4)
            info.sourceSize = declared > 0 ? declared : nil
            info.canVerifyIntegrity = try PPFApplier.readBlock(reader).contains { $0 != 0 }
        case .v3:
            try reader.skip(1)
            let hasBlockCheck = try reader.readByte() != 0
            try reader.skip(2)
            info.canVerifyIntegrity = try hasBlockCheck && PPFApplier.readBlock(reader).contains { $0 != 0 }
        default:
            break
        }
    }

    private static func text(_ data: Data) -> String? {
        let trimmed = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0")))
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Applying

    /// Applies `patch` to `source` and writes the result to `output`.
    ///
    /// The result is written to `<output>.partial` and renamed on success; the partial file is
    /// removed on failure and on cancellation. Cancelling the calling task stops the work between
    /// chunks and throws `PatchError.cancelled`. `progress` is called from a background thread.
    public static func apply(
        patch: URL,
        source: URL,
        output: URL,
        options: PatchOptions = PatchOptions(),
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> PatchResult {
        let flag = CancelFlag()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: Task.currentPriority) {
                try applySynchronously(
                    patch: patch, source: source, output: output,
                    options: options, cancelFlag: flag, progress: progress
                )
            }.value
        } onCancel: {
            flag.cancel()
        }
    }

    private static func applySynchronously(
        patch patchURL: URL,
        source sourceURL: URL,
        output outputURL: URL,
        options: PatchOptions,
        cancelFlag: CancelFlag,
        progress: (@Sendable (PatchProgress) -> Void)?
    ) throws -> PatchResult {
        let context = WorkContext(cancelFlag: cancelFlag, progress: progress)
        try context.checkCancelled()
        guard let format = detectFormat(patchURL) else { throw PatchError.unsupportedFormat }

        let outputPath = outputURL.standardizedFileURL.path
        guard outputPath != sourceURL.standardizedFileURL.path, outputPath != patchURL.standardizedFileURL.path else {
            throw PosixFile.posixError(EINVAL)
        }
        let partialPath = outputPath + ".partial"

        do {
            let outcome = try withFiles(patch: patchURL.path, source: sourceURL.path, partial: partialPath) { patch, source, partial in
                let inputs = ApplyInputs(patch: patch, source: source, output: partial, options: options, context: context)
                let outcome = try run(format, inputs)
                try context.checkCancelled()
                try partial.synchronize()
                return outcome
            }
            guard rename(partialPath, outputPath) == 0 else { throw PosixFile.posixError() }
            context.finish()
            return PatchResult(
                output: outputURL,
                bytesWritten: outcome.bytesWritten,
                verifiedChecksums: outcome.verified,
                ignoredTargetMismatch: outcome.ignoredTargetMismatch
            )
        } catch {
            unlink(partialPath)
            throw error
        }
    }

    private static func withFiles<T>(
        patch: String,
        source: String,
        partial: String,
        _ body: (PosixFile, PosixFile, PosixFile) throws -> T
    ) throws -> T {
        let patchFile = try PosixFile(readingAt: patch)
        let sourceFile = try PosixFile(readingAt: source)
        let partialFile = try PosixFile(creatingAt: partial)
        defer { partialFile.close() }
        return try body(patchFile, sourceFile, partialFile)
    }

    private static func run(_ format: PatchFormat, _ inputs: ApplyInputs) throws -> ApplyOutcome {
        switch format {
        case .ips: return try IPSApplier.apply(inputs, isIPS32: false)
        case .ips32: return try IPSApplier.apply(inputs, isIPS32: true)
        case .bps: return try BPSApplier.apply(inputs)
        case .ups: return try UPSApplier.apply(inputs)
        case .ppf: return try PPFApplier.apply(inputs)
        case .xdelta3: return try XDelta3Applier.apply(inputs)
        }
    }
}
