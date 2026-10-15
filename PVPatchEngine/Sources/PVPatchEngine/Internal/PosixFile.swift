//
//  PosixFile.swift
//  PVPatchEngine
//
//  Thin pread/pwrite wrapper. Every offset is 64-bit and nothing is memory mapped,
//  so resident memory does not grow with the size of the image.
//

import Foundation

/// Page-aligned scratch memory with a fixed size.
final class ScratchBuffer {
    let pointer: UnsafeMutableRawPointer
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        pointer = UnsafeMutableRawPointer.allocate(byteCount: max(capacity, 1), alignment: 16384)
    }

    deinit {
        pointer.deallocate()
    }

    var bytes: UnsafeMutablePointer<UInt8> {
        pointer.assumingMemoryBound(to: UInt8.self)
    }
}

final class PosixFile {
    private var descriptor: Int32
    let path: String
    /// Size when the file was opened for reading.
    private(set) var size: UInt64 = 0

    static func posixError(_ code: Int32 = errno) -> PatchError {
        .io(POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO))
    }

    init(readingAt path: String) throws {
        self.path = path
        descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { throw Self.posixError() }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else {
            let failure = Self.posixError()
            Darwin.close(descriptor)
            throw failure
        }
        size = UInt64(max(info.st_size, 0))
    }

    init(creatingAt path: String) throws {
        self.path = path
        descriptor = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o644)
        guard descriptor >= 0 else { throw Self.posixError() }
    }

    deinit {
        close()
    }

    func close() {
        guard descriptor >= 0 else { return }
        Darwin.close(descriptor)
        descriptor = -1
    }

    private func fileOffset(_ offset: UInt64) throws -> off_t {
        guard offset <= UInt64(Int64.max) else { throw PatchError.outputTooLarge }
        return off_t(offset)
    }

    /// Reads up to `count` bytes at `offset`. Returns fewer only at end of file.
    func read(into buffer: UnsafeMutableRawPointer, count: Int, at offset: UInt64) throws -> Int {
        var total = 0
        while total < count {
            guard offset <= UInt64(Int64.max) - UInt64(total) else { break }
            let result = pread(descriptor, buffer + total, count - total, off_t(offset + UInt64(total)))
            if result < 0 {
                if errno == EINTR { continue }
                throw Self.posixError()
            }
            if result == 0 { break }
            total += result
        }
        return total
    }

    func write(_ buffer: UnsafeRawPointer, count: Int, at offset: UInt64) throws {
        var total = 0
        while total < count {
            let position = try fileOffset(offset + UInt64(total))
            let result = pwrite(descriptor, buffer + total, count - total, position)
            if result < 0 {
                if errno == EINTR { continue }
                throw Self.posixError()
            }
            total += result
        }
    }

    func truncate(to length: UInt64) throws {
        guard ftruncate(descriptor, try fileOffset(length)) == 0 else { throw Self.posixError() }
    }

    func synchronize() throws {
        guard fsync(descriptor) == 0 else { throw Self.posixError() }
    }
}
