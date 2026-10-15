//
//  PPFApplier.swift
//  PVPatchEngine
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adapted from Provenance PVPatching (PPFPatcher.swift) and rewritten to stream: the source is
//  copied to the output in chunks, then records are written in place. PPF never grows the image.
//
//  Layouts follow the PPF3.0 specification by Icarus/Paradox:
//
//  Common header (all versions):
//    0x00  5   magic "PPF10" / "PPF20" / "PPF30"
//    0x05  1   version index: 0x00 = 1.0, 0x01 = 2.0, 0x02 = 3.0
//    0x06  50  description (space padded)
//
//  PPF 1.0:  0x38  records: offset (4 LE), length (1), data
//  PPF 2.0:  0x38  size of the original image (4 LE), 0x3C block check (1024 bytes of the original
//            image from 0x9320), 0x43C records as in 1.0
//  PPF 3.0:  0x38  image type (0 = BIN block check from 0x9320, 1 = GI from 0x80A0), 0x39 block check
//            present, 0x3A undo data present, 0x3B dummy, 0x3C block check (when flagged),
//            then records: offset (8 LE), length (1), data, [undo data: length bytes]
//
//  v2 and v3 may be followed by "@BEGIN_FILE_ID.DIZ" ... which ends the records.
//

import Foundation

enum PPFApplier {
    static let commonHeaderLength: UInt64 = 56
    static let descriptionOffset: UInt64 = 6
    static let descriptionLength = 50
    private static let blockCheckLength = 1024
    private static let binBlockCheckOffset: UInt64 = 0x9320
    private static let giBlockCheckOffset: UInt64 = 0x80A0
    private static let fileIDMarker = Array("@BEGIN_FILE_ID.DIZ".utf8)

    enum Version {
        case v1, v2, v3
    }

    /// Returns the version for a "PPFnn" magic, nil when the magic is not a PPF header at all.
    static func parseVersion(magic: [UInt8]) throws -> Version? {
        guard magic.count >= 5, magic.prefix(3).elementsEqual("PPF".utf8) else { return nil }
        switch String(decoding: magic[3...4], as: UTF8.self) {
        case "10": return .v1
        case "20": return .v2
        case "30": return .v3
        default: throw PatchError.unsupportedFormat
        }
    }

    static func apply(_ inputs: ApplyInputs) throws -> ApplyOutcome {
        let context = inputs.context
        let reader = PatchStreamReader(file: inputs.patch, end: inputs.patch.size)
        var magic = [UInt8](repeating: 0, count: 5)
        try magic.withUnsafeMutableBytes { try reader.readBytes(into: $0.baseAddress!, count: 5) }
        guard let version = try parseVersion(magic: magic) else { throw PatchError.corruptPatch("invalid PPF header") }
        guard inputs.patch.size >= commonHeaderLength else { throw PatchError.truncatedPatch }
        try reader.skip(commonHeaderLength - 5)

        let source = inputs.source
        let ignoreSource = inputs.options.ignoreSourceChecksum
        var verified: [VerifiedChecksum] = []
        var offsetWidth = 4
        var hasUndoData = false
        var blockCheck: (patchBlock: [UInt8], sourceOffset: UInt64)?

        switch version {
        case .v1:
            break
        case .v2:
            let declaredSize = try reader.readLittleEndian(4)
            if !ignoreSource, declaredSize != 0, declaredSize != source.size {
                throw PatchError.sourceSizeMismatch(expected: declaredSize, actual: source.size)
            }
            blockCheck = (try readBlock(reader), binBlockCheckOffset)
        case .v3:
            let imageType = try reader.readByte()
            let hasBlockCheck = try reader.readByte() != 0
            hasUndoData = try reader.readByte() != 0
            _ = try reader.readByte()
            offsetWidth = 8
            if hasBlockCheck {
                blockCheck = (try readBlock(reader), imageType == 1 ? giBlockCheckOffset : binBlockCheckOffset)
            }
        }

        if !ignoreSource, let blockCheck, try verifyBlock(blockCheck.patchBlock, at: blockCheck.sourceOffset, source: source) {
            verified.append(.sourceBlockCheck)
        }

        context.phase = .patching
        context.plan(source.size)
        try copyPrefix(from: source, to: inputs.output, count: source.size, context: context)

        let scratch = ScratchBuffer(capacity: 256)
        while reader.remaining > 0 {
            if let head = try reader.peek(fileIDMarker.count), head.elementsEqual(fileIDMarker) { break }
            let offset = try reader.readLittleEndian(offsetWidth)
            let length = Int(try reader.readByte())
            guard length > 0 else { throw PatchError.corruptPatch("PPF record with no data") }
            try reader.readBytes(into: scratch.pointer, count: length)
            if hasUndoData { try reader.skip(UInt64(length)) }
            guard offset <= source.size, UInt64(length) <= source.size - offset else {
                throw PatchError.corruptPatch("PPF record writes past the end of the image (offset \(offset), length \(length))")
            }
            try inputs.output.write(scratch.pointer, count: length, at: offset)
            try context.checkCancelled()
        }
        return ApplyOutcome(bytesWritten: source.size, verified: verified)
    }

    static func readBlock(_ reader: PatchStreamReader) throws -> [UInt8] {
        var block = [UInt8](repeating: 0, count: blockCheckLength)
        try block.withUnsafeMutableBytes { try reader.readBytes(into: $0.baseAddress!, count: blockCheckLength) }
        return block
    }

    /// Compares the patch's block check against the same window of the source. Images shorter than
    /// the window and all-zero blocks (the author skipped the check) are not compared.
    /// Returns true when a comparison happened and matched.
    private static func verifyBlock(_ patchBlock: [UInt8], at offset: UInt64, source: PosixFile) throws -> Bool {
        guard source.size >= offset + UInt64(blockCheckLength), patchBlock.contains(where: { $0 != 0 }) else {
            return false
        }
        let scratch = ScratchBuffer(capacity: blockCheckLength)
        let got = try source.read(into: scratch.pointer, count: blockCheckLength, at: offset)
        let actual = UnsafeRawBufferPointer(start: scratch.pointer, count: got)
        guard got == blockCheckLength, actual.elementsEqual(patchBlock) else {
            let expectedCRC = patchBlock.withUnsafeBytes { Checksums.crc32(0, $0.baseAddress!, count: $0.count) }
            throw PatchError.sourceMismatch(expected: expectedCRC, actual: Checksums.crc32(0, scratch.pointer, count: got))
        }
        return true
    }
}
