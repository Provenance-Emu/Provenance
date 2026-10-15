//
//  SequentialSink.swift
//  PVPatchEngine
//
//  Buffered append-only writer for formats that produce the output front to back (BPS, UPS).
//  Keeps a running CRC32 of everything written and can read finished output back, which
//  BPS TargetCopy needs.
//

import Foundation

final class SequentialSink {
    private let file: PosixFile
    private let context: WorkContext
    private let buffer = ScratchBuffer(capacity: WorkContext.chunkSize)
    private var used = 0
    private var flushedBytes: UInt64 = 0
    private var runningCRC: UInt32 = 0

    init(file: PosixFile, context: WorkContext) {
        self.file = file
        self.context = context
    }

    /// Bytes appended so far, including those still buffered.
    var position: UInt64 {
        flushedBytes + UInt64(used)
    }

    func append(_ data: UnsafeRawPointer, count: Int) throws {
        var done = 0
        while done < count {
            let take = min(count - done, buffer.capacity - used)
            memcpy(buffer.pointer + used, data + done, take)
            used += take
            done += take
            if used == buffer.capacity { try flush() }
        }
    }

    func flush() throws {
        guard used > 0 else { return }
        try file.write(buffer.pointer, count: used, at: flushedBytes)
        runningCRC = Checksums.crc32(runningCRC, buffer.pointer, count: used)
        flushedBytes += UInt64(used)
        let written = UInt64(used)
        used = 0
        try context.advance(written)
    }

    /// CRC32 of everything appended.
    func finish() throws -> UInt32 {
        try flush()
        return runningCRC
    }

    /// Reads `count` bytes that were already appended.
    func readBack(at offset: UInt64, count: Int, into destination: UnsafeMutableRawPointer) throws {
        try flush()
        let got = try file.read(into: destination, count: count, at: offset)
        guard got == count else { throw PatchError.corruptPatch("output is shorter than a TargetCopy expects") }
    }
}
