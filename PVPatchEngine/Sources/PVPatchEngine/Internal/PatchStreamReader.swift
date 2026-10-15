//
//  PatchStreamReader.swift
//  PVPatchEngine
//
//  Buffered forward reader over a byte range of a patch file. Reading past the end of
//  the range throws `truncatedPatch`.
//

import Foundation

final class PatchStreamReader {
    private static let bufferSize = 256 * 1024

    private let file: PosixFile
    private let buffer = ScratchBuffer(capacity: PatchStreamReader.bufferSize)
    /// File offset of `buffer[0]`.
    private var bufferStart: UInt64
    private var bufferLength = 0
    private var cursor = 0
    /// Exclusive end of the readable range.
    let end: UInt64

    init(file: PosixFile, start: UInt64 = 0, end: UInt64) {
        self.file = file
        self.end = end
        bufferStart = start
    }

    var position: UInt64 {
        bufferStart + UInt64(cursor)
    }

    var remaining: UInt64 {
        end > position ? end - position : 0
    }

    /// Reads more of the range into the buffer, keeping any bytes not consumed yet.
    private func refill() throws {
        let leftover = bufferLength - cursor
        if leftover > 0 {
            memmove(buffer.pointer, buffer.pointer + cursor, leftover)
        }
        bufferStart += UInt64(cursor)
        cursor = 0
        bufferLength = leftover
        let fileOffset = bufferStart + UInt64(bufferLength)
        let want = Int(min(UInt64(buffer.capacity - bufferLength), end > fileOffset ? end - fileOffset : 0))
        guard want > 0 else { return }
        let got = try file.read(into: buffer.pointer + bufferLength, count: want, at: fileOffset)
        bufferLength += got
    }

    /// Makes at least `count` bytes (at most 4 KiB) available without consuming them.
    /// Returns false when the range ends sooner.
    func peek(_ count: Int) throws -> UnsafeRawBufferPointer? {
        if bufferLength - cursor < count {
            try refill()
        }
        guard bufferLength - cursor >= count else { return nil }
        return UnsafeRawBufferPointer(start: buffer.pointer + cursor, count: count)
    }

    func readByte() throws -> UInt8 {
        if cursor >= bufferLength {
            try refill()
            guard bufferLength > 0 else { throw PatchError.truncatedPatch }
        }
        let value = buffer.bytes[cursor]
        cursor += 1
        return value
    }

    func readBigEndian(_ width: Int) throws -> UInt64 {
        var value: UInt64 = 0
        for _ in 0..<width {
            value = value << 8 | UInt64(try readByte())
        }
        return value
    }

    func readLittleEndian(_ width: Int) throws -> UInt64 {
        var value: UInt64 = 0
        for shift in 0..<width {
            value |= UInt64(try readByte()) << UInt64(8 * shift)
        }
        return value
    }

    /// BPS / UPS variable-length integer. The accumulation is an addition, not an OR:
    /// the implicit `+ shift` carry can set the bit the next group contributes
    /// (`[0x00, 0x81]` is 256, not 128).
    func readVariableLength() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 1
        while true {
            let byte = UInt64(try readByte())
            let (scaled, scaleOverflow) = (byte & 0x7F).multipliedReportingOverflow(by: shift)
            let (added, addOverflow) = result.addingReportingOverflow(scaled)
            guard !scaleOverflow, !addOverflow else { throw PatchError.corruptPatch("variable-length number overflows") }
            result = added
            if byte & 0x80 != 0 { return result }
            guard shift <= UInt64.max >> 7 else { throw PatchError.corruptPatch("variable-length number overflows") }
            shift <<= 7
            let (carried, carryOverflow) = result.addingReportingOverflow(shift)
            guard !carryOverflow else { throw PatchError.corruptPatch("variable-length number overflows") }
            result = carried
        }
    }

    func readBytes(into destination: UnsafeMutableRawPointer, count: Int) throws {
        var done = 0
        while done < count {
            if cursor >= bufferLength {
                try refill()
                guard bufferLength > 0 else { throw PatchError.truncatedPatch }
            }
            let take = min(count - done, bufferLength - cursor)
            memcpy(destination + done, buffer.pointer + cursor, take)
            cursor += take
            done += take
        }
    }

    /// Hands the next `count` bytes to `consume` in buffer-sized pieces.
    func stream(_ count: UInt64, to consume: (UnsafeRawPointer, Int) throws -> Void) throws {
        guard count <= remaining else { throw PatchError.truncatedPatch }
        var left = count
        while left > 0 {
            if cursor >= bufferLength {
                try refill()
                guard bufferLength > 0 else { throw PatchError.truncatedPatch }
            }
            let take = Int(min(left, UInt64(bufferLength - cursor)))
            try consume(buffer.pointer + cursor, take)
            cursor += take
            left -= UInt64(take)
        }
    }

    func skip(_ count: UInt64) throws {
        try stream(count) { _, _ in }
    }
}
