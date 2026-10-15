//
//  XDelta3Applier.swift
//  PVPatchEngine
//
//  Decodes xdelta3 / VCDIFF patches with the vendored xdelta3 decoder (CXdelta3). Swift runs the
//  non-blocking xd3 loop: patch bytes in, output chunks written to the file, and source blocks
//  served from a small cache of positioned reads, so no whole-file buffer ever exists.
//

import CXdelta3
import Foundation

enum XDelta3Applier {
    static let sourceBlockSize = 128 * 1024
    private static let cachedBlocks = 32
    private static let inputChunkSize = 256 * 1024
    /// Largest target window the decoder is asked to hold in memory (xdelta3's default is 8 MiB); the scanner rejects bigger ones.
    static let maxTargetWindow: UInt64 = 64 * 1024 * 1024

    static func apply(_ inputs: ApplyInputs) throws -> ApplyOutcome {
        let context = inputs.context
        let patch = inputs.patch
        let source = inputs.source
        let ignoreSource = inputs.options.ignoreSourceChecksum

        let summary = try VCDIFFScanner.scan(patch)
        if let secondary = summary.secondaryCompression, !secondary.isSupported {
            throw PatchError.unsupportedSecondaryCompression
        }
        guard summary.targetSize <= inputs.options.maxOutputSize else { throw PatchError.outputTooLarge }
        if !ignoreSource, source.size < summary.requiredSourceSize {
            throw PatchError.sourceSizeMismatch(expected: summary.requiredSourceSize, actual: source.size)
        }

        guard let decoder = pv_xd3_create(UInt32(sourceBlockSize), source.size, ignoreSource ? 1 : 0) else {
            throw PatchError.io(POSIXError(.ENOMEM))
        }
        defer { pv_xd3_destroy(decoder) }

        context.phase = .patching
        context.plan(summary.targetSize)
        let written = try decode(decoder, inputs: inputs, targetLimit: summary.targetSize)
        guard written == summary.targetSize else {
            throw PatchError.corruptPatch("patch produced \(written) bytes but declares \(summary.targetSize)")
        }

        var outcome = ApplyOutcome(bytesWritten: written)
        if !ignoreSource, summary.windowsWithAdler32 > 0 {
            outcome.verified = [.targetWindowAdler32(windows: summary.windowsWithAdler32)]
        }
        return outcome
    }

    private static func decode(_ decoder: OpaquePointer, inputs: ApplyInputs, targetLimit: UInt64) throws -> UInt64 {
        let context = inputs.context
        let patch = inputs.patch
        let input = ScratchBuffer(capacity: inputChunkSize)
        let blocks = SourceBlockCache(file: inputs.source, blockSize: sourceBlockSize, capacity: cachedBlocks)
        var patchOffset: UInt64 = 0
        var written: UInt64 = 0
        var sawHeader = false

        decoding: while true {
            try context.checkCancelled()
            switch pv_xd3_step(decoder) {
            case PV_XD3_NEED_INPUT:
                guard patchOffset < patch.size else { break decoding }
                let got = try patch.read(into: input.pointer, count: input.capacity, at: patchOffset)
                guard got > 0 else { break decoding }
                patchOffset += UInt64(got)
                pv_xd3_provide_input(decoder, input.bytes, got, patchOffset >= patch.size ? 1 : 0)
            case PV_XD3_OUTPUT:
                var length = 0
                guard let bytes = pv_xd3_output(decoder, &length) else { throw PatchError.corruptPatch("decoder returned no output") }
                guard written + UInt64(length) <= targetLimit else { throw PatchError.corruptPatch("patch writes more than it declares") }
                try inputs.output.write(bytes, count: length, at: written)
                written += UInt64(length)
                pv_xd3_consume_output(decoder)
                try context.advance(UInt64(length))
            case PV_XD3_NEED_SOURCE_BLOCK:
                let block = try blocks.block(pv_xd3_wanted_block(decoder))
                pv_xd3_provide_block(decoder, block.pointer, block.length)
            case PV_XD3_GOT_HEADER:
                sawHeader = true
            case PV_XD3_PROGRESS:
                continue decoding
            case PV_XD3_ERROR_CHECKSUM:
                var expected: UInt32 = 0
                var actual: UInt32 = 0
                pv_xd3_checksums(decoder, &expected, &actual)
                throw PatchError.sourceMismatch(expected: expected, actual: actual)
            case PV_XD3_ERROR_SECONDARY:
                throw PatchError.unsupportedSecondaryCompression
            default:
                throw PatchError.corruptPatch(String(cString: pv_xd3_message(decoder)))
            }
        }

        guard sawHeader, pv_xd3_finish(decoder) == 0 else { throw PatchError.truncatedPatch }
        return written
    }
}

/// Least-recently-used cache of fixed-size source blocks. xd3 keeps a pointer to the block it was
/// last given, so a block is only recycled once a different one has been handed over.
private final class SourceBlockCache {
    private struct Slot {
        let buffer: ScratchBuffer
        var block: UInt64?
        var length = 0
        var lastUsed: UInt64 = 0
    }

    private let file: PosixFile
    private let blockSize: Int
    private var slots: [Slot]
    private var tick: UInt64 = 0

    init(file: PosixFile, blockSize: Int, capacity: Int) {
        self.file = file
        self.blockSize = blockSize
        slots = (0..<capacity).map { _ in Slot(buffer: ScratchBuffer(capacity: blockSize)) }
    }

    func block(_ number: UInt64) throws -> (pointer: UnsafePointer<UInt8>, length: UInt32) {
        tick += 1
        let index: Int
        if let hit = slots.firstIndex(where: { $0.block == number }) {
            index = hit
        } else {
            index = slots.indices.min { slots[$0].lastUsed < slots[$1].lastUsed } ?? 0
            let (offset, overflow) = number.multipliedReportingOverflow(by: UInt64(blockSize))
            let length = overflow || offset >= file.size
                ? 0
                : try file.read(into: slots[index].buffer.pointer, count: blockSize, at: offset)
            slots[index].block = number
            slots[index].length = length
        }
        slots[index].lastUsed = tick
        return (UnsafePointer(slots[index].buffer.bytes), UInt32(slots[index].length))
    }
}
