//
//  BPSApplier.swift
//  PVPatchEngine
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapted from Provenance PVPatching (BPSPatcher.swift) and rewritten to stream: the output is
//  appended front to back, SourceCopy reads the source and TargetCopy reads the output back through
//  buffered preads, and the CRC32s are computed over chunks.
//
//  BPS layout: "BPS1", source size, target size, metadata size (variable-length numbers), metadata,
//  actions, then source CRC32, target CRC32 and patch CRC32 (little endian). The patch CRC covers
//  everything before it.
//

import Foundation

enum BPSApplier {
    static let minimumPatchSize: UInt64 = 19
    static let footerSize: UInt64 = 12
    private static let maxKeptMetadata: UInt64 = 64 * 1024

    private enum Action: UInt64 {
        case sourceRead = 0
        case targetRead = 1
        case sourceCopy = 2
        case targetCopy = 3
    }

    struct Header {
        var sourceSize: UInt64
        var targetSize: UInt64
        var metadata: Data
        var actionsStart: UInt64
        var sourceCRC32: UInt32
        var targetCRC32: UInt32
        var patchCRC32: UInt32
    }

    /// Parses everything but the actions. Does not verify the patch CRC.
    static func readHeader(_ patch: PosixFile) throws -> Header {
        guard patch.size >= minimumPatchSize else { throw PatchError.truncatedPatch }
        let actionsEnd = patch.size - footerSize
        let reader = PatchStreamReader(file: patch, end: actionsEnd)
        var magic = [UInt8](repeating: 0, count: 4)
        try magic.withUnsafeMutableBytes { try reader.readBytes(into: $0.baseAddress!, count: 4) }
        guard magic.elementsEqual("BPS1".utf8) else { throw PatchError.corruptPatch("invalid BPS header") }
        let sourceSize = try reader.readVariableLength()
        let targetSize = try reader.readVariableLength()
        let metadataSize = try reader.readVariableLength()
        guard metadataSize <= reader.remaining else { throw PatchError.corruptPatch("BPS metadata overruns the patch") }
        // Metadata is informational; keep a bounded prefix and skip the rest.
        let kept = Int(min(metadataSize, maxKeptMetadata))
        var metadata = Data(count: kept)
        try metadata.withUnsafeMutableBytes { buffer in
            if let base = buffer.baseAddress { try reader.readBytes(into: base, count: kept) }
        }
        try reader.skip(metadataSize - UInt64(kept))

        let footer = PatchStreamReader(file: patch, start: actionsEnd, end: patch.size)
        return Header(
            sourceSize: sourceSize,
            targetSize: targetSize,
            metadata: metadata,
            actionsStart: reader.position,
            sourceCRC32: UInt32(try footer.readLittleEndian(4)),
            targetCRC32: UInt32(try footer.readLittleEndian(4)),
            patchCRC32: UInt32(try footer.readLittleEndian(4))
        )
    }

    static func apply(_ inputs: ApplyInputs) throws -> ApplyOutcome {
        let context = inputs.context
        let patch = inputs.patch
        let source = inputs.source
        let ignoreSource = inputs.options.ignoreSourceChecksum

        let header = try readHeader(patch)
        guard header.targetSize <= inputs.options.maxOutputSize else { throw PatchError.outputTooLarge }
        if !ignoreSource, source.size < header.sourceSize {
            throw PatchError.sourceSizeMismatch(expected: header.sourceSize, actual: source.size)
        }

        let patchBody = patch.size - 4
        context.plan(patchBody)
        if !ignoreSource { context.plan(min(header.sourceSize, source.size)) }
        context.plan(header.targetSize)
        context.phase = .verifying

        let patchCRC = try Checksums.prefixCRC32s(of: patch, lengths: [patchBody], context: context)[0]
        guard patchCRC == header.patchCRC32 else { throw PatchError.corruptPatch("patch checksum mismatch") }
        var verified: [VerifiedChecksum] = [.patchCRC32(patchCRC)]

        if !ignoreSource {
            let sourceCRC = try Checksums.prefixCRC32s(of: source, lengths: [header.sourceSize], context: context)[0]
            guard sourceCRC == header.sourceCRC32 else {
                throw PatchError.sourceMismatch(expected: header.sourceCRC32, actual: sourceCRC)
            }
            verified.append(.sourceCRC32(sourceCRC))
        }

        context.phase = .patching
        let sink = SequentialSink(file: inputs.output, context: context)
        try runActions(inputs, header: header, sink: sink)
        guard sink.position == header.targetSize else {
            throw PatchError.corruptPatch("BPS actions do not fill the target")
        }

        let targetCRC = try sink.finish()
        var outcome = ApplyOutcome(bytesWritten: header.targetSize)
        if targetCRC == header.targetCRC32 {
            verified.append(.targetCRC32(targetCRC))
        } else if ignoreSource {
            outcome.ignoredTargetMismatch = ChecksumMismatch(expected: header.targetCRC32, actual: targetCRC)
        } else {
            throw PatchError.targetMismatch(expected: header.targetCRC32, actual: targetCRC)
        }
        outcome.verified = verified
        return outcome
    }

    // MARK: - Actions

    private static func runActions(_ inputs: ApplyInputs, header: Header, sink: SequentialSink) throws {
        let actionsEnd = inputs.patch.size - footerSize
        let reader = PatchStreamReader(file: inputs.patch, start: header.actionsStart, end: actionsEnd)
        let scratch = ScratchBuffer(capacity: WorkContext.chunkSize)
        let fill = ScratchBuffer(capacity: WorkContext.chunkSize)
        var sourceOffset: Int64 = 0
        var targetOffset: Int64 = 0

        while reader.remaining > 0 {
            let word = try reader.readVariableLength()
            let length = (word >> 2) + 1
            guard length <= header.targetSize - sink.position else {
                throw PatchError.corruptPatch("BPS action at output offset \(sink.position) overflows the target")
            }
            guard let action = Action(rawValue: word & 3) else { throw PatchError.corruptPatch("unknown BPS action") }

            switch action {
            case .sourceRead:
                try copyFromSource(at: sink.position, length: length, inputs.source, sink, scratch)
            case .targetRead:
                try reader.stream(length) { bytes, count in try sink.append(bytes, count: count) }
            case .sourceCopy:
                sourceOffset = try relativeOffset(try reader.readVariableLength(), from: sourceOffset)
                guard UInt64(sourceOffset) <= header.sourceSize, length <= header.sourceSize - UInt64(sourceOffset) else {
                    throw PatchError.corruptPatch("BPS SourceCopy reads past the source")
                }
                try copyFromSource(at: UInt64(sourceOffset), length: length, inputs.source, sink, scratch)
                sourceOffset = try advanced(sourceOffset, by: length)
            case .targetCopy:
                targetOffset = try relativeOffset(try reader.readVariableLength(), from: targetOffset)
                try copyFromTarget(at: UInt64(targetOffset), length: length, sink, scratch, fill)
                targetOffset = try advanced(targetOffset, by: length)
            }
        }
    }

    private static func relativeOffset(_ encoded: UInt64, from current: Int64) throws -> Int64 {
        let magnitude = encoded >> 1
        guard magnitude <= UInt64(Int64.max / 2) else { throw PatchError.corruptPatch("BPS offset out of range") }
        let delta = Int64(magnitude)
        let (result, overflow) = encoded & 1 != 0 ? current.subtractingReportingOverflow(delta) : current.addingReportingOverflow(delta)
        guard !overflow, result >= 0 else { throw PatchError.corruptPatch("BPS copy has an offset out of range") }
        return result
    }

    private static func advanced(_ offset: Int64, by length: UInt64) throws -> Int64 {
        guard let step = Int64(exactly: length) else { throw PatchError.corruptPatch("BPS offset out of range") }
        let (result, overflow) = offset.addingReportingOverflow(step)
        guard !overflow else { throw PatchError.corruptPatch("BPS offset out of range") }
        return result
    }

    /// Appends source bytes; anything past the end of the source reads as zero.
    private static func copyFromSource(
        at offset: UInt64,
        length: UInt64,
        _ source: PosixFile,
        _ sink: SequentialSink,
        _ scratch: ScratchBuffer
    ) throws {
        var position = offset
        var left = length
        while left > 0 {
            let want = Int(min(left, UInt64(scratch.capacity)))
            let got = position < source.size ? try source.read(into: scratch.pointer, count: want, at: position) : 0
            if got < want { memset(scratch.pointer + got, 0, want - got) }
            try sink.append(scratch.pointer, count: want)
            position += UInt64(want)
            left -= UInt64(want)
        }
    }

    /// Appends bytes copied from earlier in the output. When the copy overlaps what it is writing,
    /// each byte sees the ones just written: the bytes since `offset` repeat as a pattern.
    private static func copyFromTarget(
        at offset: UInt64,
        length: UInt64,
        _ sink: SequentialSink,
        _ scratch: ScratchBuffer,
        _ fill: ScratchBuffer
    ) throws {
        guard offset < sink.position else {
            throw PatchError.corruptPatch("TargetCopy position \(offset) references unwritten data")
        }
        let distance = sink.position - offset
        if length <= distance || distance >= UInt64(scratch.capacity) {
            var position = offset
            var left = length
            while left > 0 {
                let count = Int(min(left, UInt64(scratch.capacity)))
                try sink.readBack(at: position, count: count, into: scratch.pointer)
                try sink.append(scratch.pointer, count: count)
                position += UInt64(count)
                left -= UInt64(count)
            }
            return
        }

        let period = Int(distance)
        try sink.readBack(at: offset, count: period, into: fill.pointer)
        var filled = period
        while filled < fill.capacity {
            let copy = min(filled, fill.capacity - filled)
            memcpy(fill.pointer + filled, fill.pointer, copy)
            filled += copy
        }
        let usable = fill.capacity / period * period
        var left = length
        while left > 0 {
            let count = Int(min(left, UInt64(usable)))
            try sink.append(fill.pointer, count: count)
            left -= UInt64(count)
        }
    }
}
