//
//  Checksums.swift
//  PVPatchEngine
//
//  Streamed CRC32 over file ranges.
//

import CXdelta3
import Foundation

enum Checksums {
    static func crc32(_ crc: UInt32, _ pointer: UnsafeRawPointer, count: Int) -> UInt32 {
        pv_crc32(crc, pointer.assumingMemoryBound(to: UInt8.self), count)
    }

    /// CRC32 of the first `length` bytes of the file, for each requested length, in one pass.
    /// A length past the end of the file yields the CRC32 of the whole file.
    static func prefixCRC32s(
        of file: PosixFile,
        lengths: [UInt64],
        context: WorkContext
    ) throws -> [UInt32] {
        let order = lengths.indices.sorted { lengths[$0] < lengths[$1] }
        let buffer = ScratchBuffer(capacity: WorkContext.chunkSize)
        var results = [UInt32](repeating: 0, count: lengths.count)
        var crc: UInt32 = 0
        var position: UInt64 = 0
        for index in order {
            let end = min(lengths[index], file.size)
            while position < end {
                let want = Int(min(UInt64(buffer.capacity), end - position))
                let got = try file.read(into: buffer.pointer, count: want, at: position)
                guard got > 0 else { break }
                crc = crc32(crc, buffer.pointer, count: got)
                position += UInt64(got)
                try context.advance(UInt64(got))
            }
            results[index] = crc
        }
        return results
    }
}

/// Copies `count` bytes from the start of `source` to the start of `destination`.
func copyPrefix(
    from source: PosixFile,
    to destination: PosixFile,
    count: UInt64,
    context: WorkContext
) throws {
    let buffer = ScratchBuffer(capacity: WorkContext.chunkSize)
    var position: UInt64 = 0
    while position < count {
        let want = Int(min(UInt64(buffer.capacity), count - position))
        let got = try source.read(into: buffer.pointer, count: want, at: position)
        guard got > 0 else { break }
        try destination.write(buffer.pointer, count: got, at: position)
        position += UInt64(got)
        try context.advance(UInt64(got))
    }
}
