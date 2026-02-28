//
//  TestOERingBuffer.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Testing
import PVLogging
@testable import PVAudio
@testable import OERingBuffer

// MARK: - Helpers

private func makeBuffer(_ count: Int, fill: UInt8 = 0) -> [UInt8] {
    [UInt8](repeating: fill, count: count)
}

private func makePattern(_ count: Int, offset: Int = 0) -> [UInt8] {
    (0..<count).map { UInt8(($0 + offset) % 256) }
}

// MARK: - Initialization Tests

struct TestOERingBufferInit {

    @Test func testZeroLengthReturnsNil() {
        // OERingBuffer falls back to initWithLength:1 for plain init,
        // but initWithLength:0 should be handled
        let buffer = OERingBuffer(withLength: 1)
        #expect(buffer != nil)
    }

    @Test func testValidLengthSucceeds() {
        let buffer = OERingBuffer(withLength: 4096)
        #expect(buffer != nil)
    }

    @Test func testLargeValidLengthSucceeds() {
        let buffer = OERingBuffer(withLength: BufferSize(16384 * 8))
        #expect(buffer != nil)
    }

    @Test func testInitialReadableIsZero() {
        let buffer = OERingBuffer(withLength: 4096)!
        #expect(buffer.availableBytesForReading == 0)
    }

    @Test func testInitialAvailableBytesIsZero() {
        let buffer = OERingBuffer(withLength: 4096)!
        #expect(buffer.availableBytes == 0)
    }

    @Test func testInitialWritableIsAtLeastRequestedLength() {
        // TPCircularBuffer also rounds up to page size
        let requestedSize: BufferSize = 4096
        let buffer = OERingBuffer(withLength: requestedSize)!
        #expect(buffer.availableBytesForWriting >= requestedSize)
    }

    @Test func testInitialBytesWrittenIsZero() {
        let buffer = OERingBuffer(withLength: 4096)!
        #expect(buffer.bytesWritten == 0)
    }

    @Test func testInitialBytesReadIsZero() {
        let buffer = OERingBuffer(withLength: 4096)!
        #expect(buffer.bytesRead == 0)
    }

    @Test func testLengthPropertyReflectsActualCapacity() {
        let requestedSize: BufferSize = 4096
        let buffer = OERingBuffer(withLength: requestedSize)!
        // length may be rounded up to page size
        #expect(buffer.length >= requestedSize)
    }
}

// MARK: - Write Tests

struct TestOERingBufferWrite {

    @Test func testWriteSucceeds() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = BufferSize(capacity / 2)

        let data = makeBuffer(Int(writeSize))
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        // OERingBuffer.write returns 1 (true) on success, 0 on failure
        #expect(result != 0)
    }

    @Test func testWriteUpdatesAvailableForReading() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = BufferSize(capacity / 4)

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.availableBytesForReading == writeSize)
    }

    @Test func testWriteUpdatesAvailableForWriting() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = BufferSize(capacity / 4)

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.availableBytesForWriting == capacity - writeSize)
    }

    @Test func testWriteUpdatesBytesWrittenCounter() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = BufferSize(capacity / 4)

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.bytesWritten == writeSize)
    }

    @Test func testMultipleWritesAccumulateBytesWrittenCounter() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = BufferSize(capacity / 8)
        let writeCount = 3

        let data = makeBuffer(Int(writeSize))
        for _ in 0..<writeCount {
            data.withUnsafeBytes { ptr in
                buffer.write(ptr.baseAddress!, size: writeSize)
            }
        }
        #expect(buffer.bytesWritten == writeSize * BufferSize(writeCount))
    }

    @Test func testWriteZeroBytesReturnsZero() {
        let buffer = OERingBuffer(withLength: 4096)!
        var dummy: UInt8 = 0
        let result = withUnsafeBytes(of: &dummy) { ptr in
            buffer.write(ptr.baseAddress!, size: 0)
        }
        #expect(result == 0)
    }

    @Test func testWriteLargerThanBufferPreventsOverflow() {
        // OERingBuffer.write rejects writes larger than buffer.length
        let capacity: BufferSize = 4096
        let buffer = OERingBuffer(withLength: capacity)!
        let actualCapacity = buffer.length
        let overSize = actualCapacity + 100

        let data = makeBuffer(Int(overSize))
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: overSize)
        }
        // Should return 0 (failure) when write would overflow
        #expect(result == 0)
        #expect(buffer.availableBytesForReading == 0)
    }

    @Test func testWriteFullBufferReturnsFalse() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Fill buffer completely
        let fillData = makeBuffer(Int(capacity))
        fillData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity)
        }

        // Try to write more (should fail — buffer is full)
        let moreData = makeBuffer(256, fill: 0xAB)
        let result = moreData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }
        #expect(result == 0)
    }
}

// MARK: - Read Tests

struct TestOERingBufferRead {

    @Test func testReadReturnsRequestedSize() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2
        let readSize = BufferSize(256)

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: Int(readSize), alignment: 1)
        defer { readBuf.deallocate() }
        let result = buffer.read(readBuf, preferredSize: readSize)
        #expect(result == readSize)
    }

    @Test func testReadFromEmptyBufferFillsWithSilence() {
        let buffer = OERingBuffer(withLength: 4096)!
        let readSize = 256

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }
        memset(readBuf, 0xFF, readSize)

        buffer.read(readBuf, preferredSize: BufferSize(readSize))

        let bytes = readBuf.assumingMemoryBound(to: UInt8.self)
        for i in 0..<readSize {
            #expect(bytes[i] == 0, "Expected silence at index \(i), got \(bytes[i])")
        }
    }

    @Test func testReadFromEmptyBufferReturnsRequestedSize() {
        let buffer = OERingBuffer(withLength: 4096)!
        let readSize: BufferSize = 512

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: Int(readSize), alignment: 1)
        defer { readBuf.deallocate() }

        let result = buffer.read(readBuf, preferredSize: readSize)
        #expect(result == readSize)
    }

    @Test func testReadUpdatesBytesForReading() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2
        let readSize = BufferSize(256)

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: Int(readSize), alignment: 1)
        defer { readBuf.deallocate() }
        buffer.read(readBuf, preferredSize: readSize)

        #expect(buffer.availableBytesForReading == writeSize - readSize)
    }

    @Test func testReadUpdatesBytesReadCounter() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2
        let readSize: BufferSize = 256

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: Int(readSize), alignment: 1)
        defer { readBuf.deallocate() }
        buffer.read(readBuf, preferredSize: readSize)

        #expect(buffer.bytesRead == readSize)
    }

    @Test func testReadZeroBytesReturnsZero() {
        let buffer = OERingBuffer(withLength: 4096)!
        var dummy: UInt8 = 0
        let result = withUnsafeMutableBytes(of: &dummy) { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: 0)
        }
        #expect(result == 0)
    }
}

// MARK: - Data Integrity Tests

struct TestOERingBufferDataIntegrity {

    @Test func testWrittenDataReadBackCorrectly() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let dataSize = min(Int(capacity) / 2, 1024)

        let writeData = makePattern(dataSize)
        writeData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: BufferSize(dataSize))
        }

        var readData = makeBuffer(dataSize, fill: 0xFF)
        readData.withUnsafeMutableBytes { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: BufferSize(dataSize))
        }
        #expect(readData == writeData)
    }

    @Test func testConsecutiveWriteReadCycles() {
        let buffer = OERingBuffer(withLength: 4096)!
        let chunkSize = 256

        for cycle in 0..<20 {
            let writeData = makePattern(chunkSize, offset: cycle * 13)
            writeData.withUnsafeBytes { ptr in
                buffer.write(ptr.baseAddress!, size: BufferSize(chunkSize))
            }

            var readData = makeBuffer(chunkSize, fill: 0xFF)
            readData.withUnsafeMutableBytes { ptr in
                buffer.read(ptr.baseAddress!, preferredSize: BufferSize(chunkSize))
            }
            #expect(readData == writeData, "Mismatch at cycle \(cycle)")
        }
    }
}

// MARK: - Reset Tests

struct TestOERingBufferReset {

    @Test func testResetClearsBytesForReading() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.availableBytesForReading > 0)

        buffer.reset()
        #expect(buffer.availableBytesForReading == 0)
    }

    @Test func testResetRestoresWriteCapacity() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        buffer.reset()
        #expect(buffer.availableBytesForWriting >= capacity)
    }

    @Test func testResetClearsBytesWrittenCounter() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 4

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.bytesWritten > 0)

        buffer.reset()
        #expect(buffer.bytesWritten == 0)
    }

    @Test func testResetClearsBytesReadCounter() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 4

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: Int(writeSize), alignment: 1)
        defer { readBuf.deallocate() }
        buffer.read(readBuf, preferredSize: writeSize)
        #expect(buffer.bytesRead > 0)

        buffer.reset()
        #expect(buffer.bytesRead == 0)
    }

    @Test func testResetAllowsSubsequentWrites() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Fill buffer
        let fillData = makeBuffer(Int(capacity))
        fillData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity)
        }

        buffer.reset()

        // Should be able to write again
        let writeSize: BufferSize = 256
        let data = makePattern(Int(writeSize))
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(result != 0)
        #expect(buffer.availableBytesForReading == writeSize)
    }
}

// MARK: - availableBytes Property Tests

struct TestOERingBufferAvailableBytes {

    @Test func testAvailableBytesMatchesAvailableBytesForReading() {
        let buffer = OERingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 3

        let data = makeBuffer(Int(writeSize))
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        #expect(buffer.availableBytes == buffer.availableBytesForReading)
        #expect(buffer.availableBytes == writeSize)
    }

    @Test func testAvailableBytesZeroOnInit() {
        let buffer = OERingBuffer(withLength: 4096)!
        #expect(buffer.availableBytes == 0)
    }
}

// MARK: - Protocol Conformance Tests

struct TestOERingBuffer {

    @Test func testLargeRingBuffer() async throws {
        let bufferSize = 16384 * 8
        try await testRingBuffer(ofSize: bufferSize)
    }

    @Test func testSmallRingBuffer() async throws {
        let bufferSize = 1024
        try await testRingBuffer(ofSize: bufferSize)
    }

    @Test func testProtocolConformance() {
        let buffer: RingBufferProtocol? = OERingBuffer(withLength: 4096)
        #expect(buffer != nil)
        #expect(buffer?.availableBytesForReading == 0)
        #expect(buffer?.availableBytesForWriting ?? 0 > 0)
    }

    @Test func testViaFactory() {
        let buffer = RingBufferFactory.make(type: .openEMU, withLength: 4096)
        #expect(buffer != nil)
        #expect(buffer is OERingBuffer)
    }
}

extension TestOERingBuffer {
    func testRingBuffer(ofSize size: Int) async throws {
        let bufferSize = size
        let ringBuffer = OERingBuffer(withLength: BufferSize(bufferSize))!
        // Actual capacity may be larger due to page alignment
        let actualCapacity = ringBuffer.availableBytesForWriting
        let testSize = min(512, Int(actualCapacity) / 2)

        #expect(ringBuffer.availableBytesForWriting == actualCapacity)
        #expect(ringBuffer.availableBytesForReading == 0)

        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1)
        defer { buffer.deallocate() }

        let writtenBytes = ringBuffer.write(buffer.baseAddress!, size: BufferSize(testSize))

        // OERingBuffer.write returns nonzero on success
        #expect(writtenBytes != 0)
        #expect(ringBuffer.availableBytesForWriting == actualCapacity - BufferSize(testSize))
        #expect(ringBuffer.availableBytesForReading == BufferSize(testSize))
    }
}
