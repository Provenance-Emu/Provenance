//
//  VCDIFFScanner.swift
//  PVPatchEngine
//
//  Walks the window headers of a VCDIFF (RFC 3284) file without decoding it. Gives the sizes a
//  patch declares and the secondary compressor it needs, before any output is written.
//
//  File:   0xD6 0xC3 0xC4 0x00, Hdr_Indicator, [secondary compressor id], [code table], [app header]
//  Window: Win_Indicator, [source size, source position], delta length, then the delta, which
//          starts with the target window length. Window headers are never secondary-compressed.
//

import Foundation

struct VCDIFFSummary {
    /// nil when no secondary compressor is declared.
    var secondaryCompression: SecondaryCompression?
    var targetSize: UInt64 = 0
    /// Furthest source byte any window copies from (0 when none do).
    var requiredSourceSize: UInt64 = 0
    var windowCount = 0
    var windowsWithAdler32 = 0
}

enum VCDIFFScanner {
    private static let sourceFlag: UInt8 = 0x01
    private static let targetFlag: UInt8 = 0x02
    private static let adler32Flag: UInt8 = 0x04
    private static let secondaryHeaderFlag: UInt8 = 0x01
    private static let codeTableHeaderFlag: UInt8 = 0x02
    private static let appHeaderFlag: UInt8 = 0x04
    private static let magic: [UInt8] = [0xD6, 0xC3, 0xC4, 0x00]

    private struct Cursor {
        let file: PosixFile
        var position: UInt64 = 0

        mutating func byte() throws -> UInt8 {
            var value: UInt8 = 0
            let got = try withUnsafeMutablePointer(to: &value) { try file.read(into: $0, count: 1, at: position) }
            guard got == 1 else { throw PatchError.truncatedPatch }
            position += 1
            return value
        }

        /// RFC 3284 base-128 integer, most significant group first.
        mutating func integer() throws -> UInt64 {
            var value: UInt64 = 0
            for _ in 0..<10 {
                let next = try byte()
                guard value >> 57 == 0 else { throw PatchError.corruptPatch("VCDIFF integer overflows") }
                value = value << 7 | UInt64(next & 0x7F)
                if next & 0x80 == 0 { return value }
            }
            throw PatchError.corruptPatch("VCDIFF integer is too long")
        }
    }

    static func scan(_ patch: PosixFile) throws -> VCDIFFSummary {
        var cursor = Cursor(file: patch)
        for expected in magic {
            guard try cursor.byte() == expected else { throw PatchError.corruptPatch("invalid VCDIFF header") }
        }
        var summary = VCDIFFSummary()
        let indicator = try cursor.byte()
        if indicator & secondaryHeaderFlag != 0 {
            summary.secondaryCompression = SecondaryCompression(compressorID: try cursor.byte())
        }
        guard indicator & codeTableHeaderFlag == 0 else { throw PatchError.unsupportedFormat }
        if indicator & appHeaderFlag != 0 {
            let length = try cursor.integer()
            guard length <= patch.size - cursor.position else { throw PatchError.truncatedPatch }
            cursor.position += length
        }

        while cursor.position < patch.size {
            let windowIndicator = try cursor.byte()
            var sourceEnd: UInt64 = 0
            if windowIndicator & (sourceFlag | targetFlag) != 0 {
                guard windowIndicator & (sourceFlag | targetFlag) != sourceFlag | targetFlag else {
                    throw PatchError.corruptPatch("VCDIFF window copies from both source and target")
                }
                let size = try cursor.integer()
                let start = try cursor.integer()
                let (end, overflow) = start.addingReportingOverflow(size)
                guard !overflow else { throw PatchError.corruptPatch("VCDIFF source segment overflows") }
                if windowIndicator & sourceFlag != 0 { sourceEnd = end }
            }
            let deltaLength = try cursor.integer()
            let deltaStart = cursor.position
            guard deltaLength <= patch.size - deltaStart else { throw PatchError.truncatedPatch }
            let targetLength = try cursor.integer()

            guard targetLength <= XDelta3Applier.maxTargetWindow else {
                throw PatchError.corruptPatch("window of \(targetLength) bytes exceeds the \(XDelta3Applier.maxTargetWindow) byte limit")
            }
            let (total, overflow) = summary.targetSize.addingReportingOverflow(targetLength)
            guard !overflow else { throw PatchError.corruptPatch("VCDIFF target size overflows") }
            summary.windowCount += 1
            summary.targetSize = total
            summary.requiredSourceSize = max(summary.requiredSourceSize, sourceEnd)
            if windowIndicator & adler32Flag != 0 { summary.windowsWithAdler32 += 1 }
            cursor.position = deltaStart + deltaLength
        }
        return summary
    }
}
