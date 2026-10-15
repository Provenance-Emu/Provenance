//
//  UPSApplier.swift
//  PVPatchEngine
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapted from Provenance PVPatching (UPSPatcher.swift) and rewritten to stream: the output is
//  produced front to back, XOR-ing patch bytes onto source bytes read in chunks.
//
//  UPS layout: "UPS1", input size, output size (variable-length numbers), hunks (relative offset,
//  XOR bytes, 0x00 terminator), then input CRC32, output CRC32 and patch CRC32 (little endian).
//  UPS patches apply in either direction; the direction is picked from the source CRC32.
//

import Foundation

enum UPSApplier {
    static let minimumPatchSize: UInt64 = 18
    static let footerSize: UInt64 = 12
    private static let xorRunLimit = 64 * 1024

    struct Header {
        var inputSize: UInt64
        var outputSize: UInt64
        var hunksStart: UInt64
        var inputCRC32: UInt32
        var outputCRC32: UInt32
        var patchCRC32: UInt32
    }

    static func readHeader(_ patch: PosixFile) throws -> Header {
        guard patch.size >= minimumPatchSize else { throw PatchError.truncatedPatch }
        let hunksEnd = patch.size - footerSize
        let reader = PatchStreamReader(file: patch, end: hunksEnd)
        var magic = [UInt8](repeating: 0, count: 4)
        try magic.withUnsafeMutableBytes { try reader.readBytes(into: $0.baseAddress!, count: 4) }
        guard magic.elementsEqual("UPS1".utf8) else { throw PatchError.corruptPatch("invalid UPS header") }
        let inputSize = try reader.readVariableLength()
        let outputSize = try reader.readVariableLength()

        let footer = PatchStreamReader(file: patch, start: hunksEnd, end: patch.size)
        return Header(
            inputSize: inputSize,
            outputSize: outputSize,
            hunksStart: reader.position,
            inputCRC32: UInt32(try footer.readLittleEndian(4)),
            outputCRC32: UInt32(try footer.readLittleEndian(4)),
            patchCRC32: UInt32(try footer.readLittleEndian(4))
        )
    }

    static func apply(_ inputs: ApplyInputs) throws -> ApplyOutcome {
        let context = inputs.context
        let patch = inputs.patch
        let source = inputs.source
        let ignoreSource = inputs.options.ignoreSourceChecksum

        let header = try readHeader(patch)
        guard max(header.inputSize, header.outputSize) <= inputs.options.maxOutputSize else {
            throw PatchError.outputTooLarge
        }

        let patchBody = patch.size - 4
        context.plan(patchBody)
        if !ignoreSource { context.plan(source.size) }
        context.plan(max(header.inputSize, header.outputSize))
        context.phase = .verifying

        let patchCRC = try Checksums.prefixCRC32s(of: patch, lengths: [patchBody], context: context)[0]
        guard patchCRC == header.patchCRC32 else { throw PatchError.corruptPatch("patch checksum mismatch") }
        var verified: [VerifiedChecksum] = [.patchCRC32(patchCRC)]

        let reverse: Bool
        if ignoreSource {
            reverse = source.size == header.outputSize && source.size != header.inputSize
        } else {
            let canGoForward = source.size == header.inputSize
            let canGoBackward = source.size == header.outputSize
            guard canGoForward || canGoBackward else {
                throw PatchError.sourceSizeMismatch(expected: header.inputSize, actual: source.size)
            }
            // A longer image can share its first bytes with a shorter one, so the whole file is
            // checked and the size must match the direction.
            let crc = try Checksums.prefixCRC32s(of: source, lengths: [source.size], context: context)[0]
            if canGoForward, crc == header.inputCRC32 {
                reverse = false
            } else if canGoBackward, crc == header.outputCRC32 {
                reverse = true
            } else {
                throw PatchError.sourceMismatch(expected: canGoForward ? header.inputCRC32 : header.outputCRC32, actual: crc)
            }
            verified.append(.sourceCRC32(crc))
        }

        let outputSize = reverse ? header.inputSize : header.outputSize
        let baseSize = min(reverse ? header.outputSize : header.inputSize, outputSize, source.size)
        let expectedCRC = reverse ? header.inputCRC32 : header.outputCRC32

        context.phase = .patching
        let sink = SequentialSink(file: inputs.output, context: context)
        try applyHunks(inputs, header: header, outputSize: outputSize, baseSize: baseSize, sink: sink)

        let targetCRC = try sink.finish()
        var outcome = ApplyOutcome(bytesWritten: outputSize)
        if targetCRC == expectedCRC {
            verified.append(.targetCRC32(targetCRC))
        } else if ignoreSource {
            outcome.ignoredTargetMismatch = ChecksumMismatch(expected: expectedCRC, actual: targetCRC)
        } else {
            throw PatchError.targetMismatch(expected: expectedCRC, actual: targetCRC)
        }
        outcome.verified = verified
        return outcome
    }

    // MARK: - Hunks

    private static func applyHunks(
        _ inputs: ApplyInputs,
        header: Header,
        outputSize: UInt64,
        baseSize: UInt64,
        sink: SequentialSink
    ) throws {
        let reader = PatchStreamReader(file: inputs.patch, start: header.hunksStart, end: inputs.patch.size - footerSize)
        let base = BaseReader(source: inputs.source, baseSize: baseSize)
        let xorBytes = ScratchBuffer(capacity: xorRunLimit)
        let baseBytes = ScratchBuffer(capacity: xorRunLimit)
        // No hunk lies beyond the larger of the two images, whichever way the patch is applied.
        let limit = max(header.inputSize, header.outputSize)
        var offset: UInt64 = 0

        while reader.remaining > 0 {
            let skip = try reader.readVariableLength()
            let (moved, overflow) = offset.addingReportingOverflow(skip)
            guard !overflow, moved <= limit else { throw PatchError.corruptPatch("UPS hunk offset lies beyond the image") }
            offset = moved
            try emitBase(upTo: min(offset, outputSize), base: base, sink: sink, scratch: baseBytes)

            var terminated = false
            while !terminated {
                var count = 0
                while count < xorRunLimit {
                    let byte = try reader.readByte()
                    if byte == 0 {
                        terminated = true
                        break
                    }
                    xorBytes.bytes[count] = byte
                    count += 1
                }
                let writable = Int(min(UInt64(count), offset < outputSize ? outputSize - offset : 0))
                if writable > 0 {
                    try base.read(at: offset, count: writable, into: baseBytes.pointer)
                    for index in 0..<writable {
                        baseBytes.bytes[index] ^= xorBytes.bytes[index]
                    }
                    try sink.append(baseBytes.pointer, count: writable)
                }
                let (end, overflow) = offset.addingReportingOverflow(UInt64(count))
                guard !overflow, end <= limit else { throw PatchError.corruptPatch("UPS hunk runs beyond the image") }
                offset = end
            }
            // The terminator stands for one unchanged byte, which may be the one just past the end.
            offset += 1
        }
        try emitBase(upTo: outputSize, base: base, sink: sink, scratch: baseBytes)
    }

    /// Appends unmodified base bytes until the output is `target` bytes long.
    private static func emitBase(upTo target: UInt64, base: BaseReader, sink: SequentialSink, scratch: ScratchBuffer) throws {
        while sink.position < target {
            let count = Int(min(target - sink.position, UInt64(scratch.capacity)))
            try base.read(at: sink.position, count: count, into: scratch.pointer)
            try sink.append(scratch.pointer, count: count)
        }
    }

    /// The bytes a UPS hunk modifies: the source up to `baseSize`, zeros after.
    private struct BaseReader {
        let source: PosixFile
        let baseSize: UInt64

        func read(at offset: UInt64, count: Int, into buffer: UnsafeMutableRawPointer) throws {
            let available = offset < baseSize ? Int(min(UInt64(count), baseSize - offset)) : 0
            let got = available > 0 ? try source.read(into: buffer, count: available, at: offset) : 0
            if got < count { memset(buffer + got, 0, count - got) }
        }
    }
}
