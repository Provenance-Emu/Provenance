//
//  IPSApplier.swift
//  PVPatchEngine
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapted from Provenance PVPatching (IPSPatcher.swift) and rewritten to stream:
//  the source is copied to the output in chunks, then records are written in place.
//
//  IPS:   "PATCH", records (3-byte BE offset, 2-byte BE length, data; length 0 is an RLE
//         record of a 2-byte count and one byte), "EOF", optional 3-byte BE truncation size.
//  IPS32: "IPS32" (or "PATCH"), 4-byte BE offsets, "EEOF" terminator.
//

import Foundation

enum IPSApplier {
    private static let maxRecordLength = 0xFFFF

    static func apply(_ inputs: ApplyInputs, isIPS32: Bool) throws -> ApplyOutcome {
        let context = inputs.context
        let reader = PatchStreamReader(file: inputs.patch, end: inputs.patch.size)
        try checkHeader(reader, isIPS32: isIPS32)

        let offsetWidth = isIPS32 ? 4 : 3
        let terminator = Array((isIPS32 ? "EEOF" : "EOF").utf8)
        let trailerLength = isIPS32 ? 0 : 3

        context.phase = .patching
        context.plan(inputs.source.size)
        try copyPrefix(from: inputs.source, to: inputs.output, count: inputs.source.size, context: context)

        var imageSize = inputs.source.size
        let scratch = ScratchBuffer(capacity: maxRecordLength)
        var truncateTo: UInt64?

        while true {
            let remaining = reader.remaining
            guard remaining > 0 else { throw PatchError.truncatedPatch }

            // "EOF" is also a valid 3-byte record offset (0x454F46). It ends the patch only when
            // nothing but the optional truncation size can follow.
            if remaining >= UInt64(terminator.count),
               let head = try reader.peek(terminator.count),
               head.elementsEqual(terminator) {
                let isTerminator = remaining == UInt64(terminator.count)
                    || (trailerLength > 0 && remaining == UInt64(terminator.count + trailerLength))
                if isTerminator {
                    try reader.skip(UInt64(terminator.count))
                    if reader.remaining > 0 {
                        truncateTo = try reader.readBigEndian(trailerLength)
                    }
                    break
                }
            }

            let offset = try reader.readBigEndian(offsetWidth)
            let length = Int(try reader.readBigEndian(2))
            if length == 0 {
                let count = Int(try reader.readBigEndian(2))
                let value = try reader.readByte()
                try writeRun(value, count: count, at: offset, scratch: scratch, inputs)
                imageSize = max(imageSize, offset + UInt64(count))
            } else {
                guard offset + UInt64(length) <= inputs.options.maxOutputSize else { throw PatchError.outputTooLarge }
                try reader.readBytes(into: scratch.pointer, count: length)
                try inputs.output.write(scratch.pointer, count: length, at: offset)
                imageSize = max(imageSize, offset + UInt64(length))
            }
            try context.checkCancelled()
        }

        if let size = truncateTo, size > 0, size < imageSize {
            try inputs.output.truncate(to: size)
            imageSize = size
        }
        return ApplyOutcome(bytesWritten: imageSize)
    }

    private static func checkHeader(_ reader: PatchStreamReader, isIPS32: Bool) throws {
        var header = [UInt8](repeating: 0, count: 5)
        try header.withUnsafeMutableBytes { try reader.readBytes(into: $0.baseAddress!, count: 5) }
        let accepted = isIPS32 ? ["IPS32", "PATCH"] : ["PATCH"]
        guard accepted.contains(where: { header.elementsEqual($0.utf8) }) else {
            throw PatchError.corruptPatch("invalid IPS header")
        }
    }

    private static func writeRun(
        _ value: UInt8,
        count: Int,
        at offset: UInt64,
        scratch: ScratchBuffer,
        _ inputs: ApplyInputs
    ) throws {
        guard offset + UInt64(count) <= inputs.options.maxOutputSize else { throw PatchError.outputTooLarge }
        memset(scratch.pointer, Int32(value), count)
        try inputs.output.write(scratch.pointer, count: count, at: offset)
    }
}
