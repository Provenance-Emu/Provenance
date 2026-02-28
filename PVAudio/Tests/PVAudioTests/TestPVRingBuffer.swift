//
//  TestPVRingBuffer.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Testing
import PVLogging
@testable import PVRingBuffer
@testable import PVAudio

// MARK: - Helpers

private func makeBuffer(_ count: Int, fill: UInt8 = 0) -> [UInt8] {
    [UInt8](repeating: fill, count: count)
}

private func makePattern(_ count: Int, offset: Int = 0) -> [UInt8] {
    (0..<count).map { UInt8(($0 + offset) % 256) }
}

// MARK: - Initialization Tests

struct TestPVRingBufferInit {

    @Test func testZeroLengthReturnsNil() {
        let buffer = PVRingBuffer(withLength: 0)
        #expect(buffer == nil)
    }

    @Test func testNegativeLengthReturnsNil() {
        let buffer = PVRingBuffer(withLength: -1)
        #expect(buffer == nil)
    }

    @Test func testValidLengthSucceeds() {
        let buffer = PVRingBuffer(withLength: 4096)
        #expect(buffer != nil)
    }

    @Test func testLargeValidLengthSucceeds() {
        let buffer = PVRingBuffer(withLength: 16384 * 8)
        #expect(buffer != nil)
    }

    @Test func testInitialStateIsEnabled() {
        let buffer = PVRingBuffer(withLength: 4096)!
        #expect(buffer.isEnabled == true)
    }

    @Test func testInitialReadableIsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        #expect(buffer.availableBytesForReading == 0)
    }

    @Test func testInitialAvailableBytesIsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        #expect(buffer.availableBytes == 0)
    }

    @Test func testInitialWritableIsAtLeastRequestedLength() {
        // PVRingBuffer rounds up to OS page boundaries (4096 or 16384)
        let requestedSize = 4096
        let buffer = PVRingBuffer(withLength: requestedSize)!
        #expect(buffer.availableBytesForWriting >= requestedSize)
    }

    @Test func testWritableAndReadableSumToCapacity() {
        let buffer = PVRingBuffer(withLength: 8192)!
        let capacity = buffer.availableBytesForWriting
        #expect(buffer.availableBytesForReading + buffer.availableBytesForWriting == capacity)
    }
}

// MARK: - Write Tests

struct TestPVRingBufferWrite {

    @Test func testWriteReturnsRequestedSize() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2

        let data = makeBuffer(writeSize)
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(result == writeSize)
    }

    @Test func testWriteZeroBytesReturnsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        var dummy: UInt8 = 0
        let result = withUnsafeBytes(of: &dummy) { ptr in
            buffer.write(ptr.baseAddress!, size: 0)
        }
        #expect(result == 0)
    }

    @Test func testWriteUpdatesBytesForReading() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 4

        let data = makeBuffer(writeSize)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.availableBytesForReading == writeSize)
    }

    @Test func testWriteUpdatesBytesForWriting() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 4

        let data = makeBuffer(writeSize)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(buffer.availableBytesForWriting == capacity - writeSize)
    }

    @Test func testMultipleWritesAccumulate() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 8

        let data = makeBuffer(writeSize)
        for _ in 0..<4 {
            data.withUnsafeBytes { ptr in
                buffer.write(ptr.baseAddress!, size: writeSize)
            }
        }
        #expect(buffer.availableBytesForReading == writeSize * 4)
    }

    @Test func testWriteWhenDisabledReturnsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        buffer.isEnabled = false

        let data = makeBuffer(256)
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }
        #expect(result == 0)
        #expect(buffer.availableBytesForReading == 0)
    }

    @Test func testWriteWhenDisabledDoesNotModifyBuffer() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Write some data while enabled
        let data = makeBuffer(256)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }
        let bytesAfterEnabledWrite = buffer.availableBytesForReading

        // Disable and try again
        buffer.isEnabled = false
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }
        // Should not have changed
        #expect(buffer.availableBytesForReading == bytesAfterEnabledWrite)
        _ = capacity
    }
}

// MARK: - Read Tests

struct TestPVRingBufferRead {

    @Test func testReadReturnsRequestedSize() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2
        let readSize = 256

        let data = makeBuffer(writeSize)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }
        let result = buffer.read(readBuf, preferredSize: readSize)
        #expect(result == readSize)
    }

    @Test func testReadZeroBytesReturnsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        var dummy: UInt8 = 0
        let result = withUnsafeMutableBytes(of: &dummy) { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: 0)
        }
        #expect(result == 0)
    }

    @Test func testReadFromEmptyBufferFillsWithSilence() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let readSize = 256

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }

        // Pre-fill with non-zero
        memset(readBuf, 0xFF, readSize)

        let result = buffer.read(readBuf, preferredSize: readSize)

        #expect(result == readSize)
        let bytes = readBuf.assumingMemoryBound(to: UInt8.self)
        for i in 0..<readSize {
            #expect(bytes[i] == 0, "Expected silence at index \(i), got \(bytes[i])")
        }
    }

    @Test func testReadFromEmptyBufferReturnsRequestedSize() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: 512, alignment: 1)
        defer { readBuf.deallocate() }
        let result = buffer.read(readBuf, preferredSize: 512)
        #expect(result == 512)
    }

    @Test func testReadUpdatesBytesForReading() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 2
        let readSize = writeSize / 2

        let data = makeBuffer(writeSize)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }
        buffer.read(readBuf, preferredSize: readSize)

        #expect(buffer.availableBytesForReading == writeSize - readSize)
        #expect(buffer.availableBytesForWriting == capacity - writeSize + readSize)
    }

    @Test func testReadWhenDisabledReturnsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Write first
        let data = makeBuffer(256)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }

        buffer.isEnabled = false
        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 1)
        defer { readBuf.deallocate() }
        let result = buffer.read(readBuf, preferredSize: 256)
        #expect(result == 0)
        _ = capacity
    }

    @Test func testPartialReadFillsRemainderWithSilence() {
        let buffer = PVRingBuffer(withLength: 4096)!

        // Write only 128 bytes
        let writeSize = 128
        let readSize = 256
        let data = makePattern(writeSize, offset: 0)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }
        memset(readBuf, 0xFF, readSize)

        buffer.read(readBuf, preferredSize: readSize)

        let bytes = readBuf.assumingMemoryBound(to: UInt8.self)
        // First 128 bytes should match written data
        for i in 0..<writeSize {
            #expect(bytes[i] == data[i], "Data mismatch at index \(i)")
        }
        // Remaining bytes should be silence (0)
        for i in writeSize..<readSize {
            #expect(bytes[i] == 0, "Expected silence at index \(i), got \(bytes[i])")
        }
    }
}

// MARK: - Data Integrity Tests

struct TestPVRingBufferDataIntegrity {

    @Test func testWrittenDataReadBackCorrectly() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let dataSize = min(capacity / 2, 1024)

        let writeData = makePattern(dataSize)
        writeData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: dataSize)
        }

        var readData = makeBuffer(dataSize, fill: 0xFF)
        readData.withUnsafeMutableBytes { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: dataSize)
        }

        #expect(readData == writeData)
    }

    @Test func testWrapAroundPreservesDataIntegrity() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Write 3/4 of capacity
        let firstWriteSize = (capacity * 3) / 4
        let firstData = makePattern(firstWriteSize, offset: 0)
        firstData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: firstWriteSize)
        }

        // Read half of what we wrote to advance read pointer
        let readSize = firstWriteSize / 2
        let readBuf1 = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf1.deallocate() }
        buffer.read(readBuf1, preferredSize: readSize)

        // Verify first half of data
        let bytes1 = readBuf1.assumingMemoryBound(to: UInt8.self)
        for i in 0..<readSize {
            #expect(bytes1[i] == firstData[i], "First read mismatch at \(i)")
        }

        // Write more data that will wrap around
        let secondWriteSize = capacity / 2
        let secondData = makePattern(secondWriteSize, offset: 100)
        secondData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: secondWriteSize)
        }

        // Read remaining first-chunk data
        let remainingFirst = firstWriteSize - readSize
        var readFirst = makeBuffer(remainingFirst, fill: 0xFF)
        readFirst.withUnsafeMutableBytes { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: remainingFirst)
        }
        let expectedFirst = Array(firstData[readSize...])
        #expect(readFirst == expectedFirst, "Remaining first chunk mismatch after wrap")

        // Read second-chunk data (the wrapped part)
        var readSecond = makeBuffer(secondWriteSize, fill: 0xFF)
        readSecond.withUnsafeMutableBytes { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: secondWriteSize)
        }
        #expect(readSecond == secondData, "Second chunk mismatch after wrap")
    }

    @Test func testConsecutiveWriteReadCycles() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let chunkSize = 256

        for cycle in 0..<20 {
            let writeData = makePattern(chunkSize, offset: cycle * 17)
            writeData.withUnsafeBytes { ptr in
                buffer.write(ptr.baseAddress!, size: chunkSize)
            }

            var readData = makeBuffer(chunkSize, fill: 0xFF)
            readData.withUnsafeMutableBytes { ptr in
                buffer.read(ptr.baseAddress!, preferredSize: chunkSize)
            }
            #expect(readData == writeData, "Mismatch at cycle \(cycle)")
        }
    }

    @Test func testLargeDataIntegrity() {
        let buffer = PVRingBuffer(withLength: 65536)!
        let capacity = buffer.availableBytesForWriting
        let dataSize = min(capacity / 2, 16384)

        let writeData = makePattern(dataSize, offset: 7)
        writeData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: dataSize)
        }

        var readData = makeBuffer(dataSize, fill: 0xFF)
        readData.withUnsafeMutableBytes { ptr in
            buffer.read(ptr.baseAddress!, preferredSize: dataSize)
        }
        #expect(readData == writeData)
    }
}

// MARK: - Reset Tests

struct TestPVRingBufferReset {

    @Test func testResetClearsBytesForReading() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        let data = makeBuffer(capacity / 2)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity / 2)
        }
        #expect(buffer.availableBytesForReading > 0)

        buffer.reset()
        #expect(buffer.availableBytesForReading == 0)
    }

    @Test func testResetRestoresFullWriteCapacity() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        let data = makeBuffer(capacity / 2)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity / 2)
        }

        buffer.reset()
        #expect(buffer.availableBytesForWriting == capacity)
    }

    @Test func testResetAllowsSubsequentWrites() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Fill buffer
        let fillData = makeBuffer(capacity)
        fillData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity)
        }

        buffer.reset()

        // Should be able to write again
        let writeSize = 256
        let data = makePattern(writeSize)
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(result == writeSize)
        #expect(buffer.availableBytesForReading == writeSize)
    }

    @Test func testResetClearsAvailableBytes() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        let data = makeBuffer(capacity / 3)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity / 3)
        }

        buffer.reset()
        #expect(buffer.availableBytes == 0)
    }
}

// MARK: - Overrun / Underrun Tests

struct TestPVRingBufferOverrunUnderrun {

    @Test func testOverrunBehavior() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        // Fill the buffer completely
        let fillData = makeBuffer(capacity, fill: 0xAA)
        fillData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity)
        }
        #expect(buffer.availableBytesForReading == capacity)

        // Overrun: write more data when full
        let overrunData = makeBuffer(256, fill: 0xBB)
        overrunData.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }

        // Buffer should still have capacity bytes
        #expect(buffer.availableBytesForReading == capacity)
    }

    @Test func testUnderrunFillsSilence() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let readSize = 512

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }
        memset(readBuf, 0xFF, readSize)

        buffer.read(readBuf, preferredSize: readSize)

        let bytes = readBuf.assumingMemoryBound(to: UInt8.self)
        for i in 0..<readSize {
            #expect(bytes[i] == 0, "Expected silence at \(i)")
        }
    }

    @Test func testUnderrunReturnsRequestedSize() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let readSize = 512

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: readSize, alignment: 1)
        defer { readBuf.deallocate() }

        let result = buffer.read(readBuf, preferredSize: readSize)
        #expect(result == readSize)
    }
}

// MARK: - isEnabled Tests

struct TestPVRingBufferEnabled {

    @Test func testIsEnabledDefaultsToTrue() {
        let buffer = PVRingBuffer(withLength: 4096)!
        #expect(buffer.isEnabled == true)
    }

    @Test func testDisabledBufferWriteReturnsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        buffer.isEnabled = false

        let data = makeBuffer(256, fill: 0xAB)
        let result = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: 256)
        }
        #expect(result == 0)
    }

    @Test func testDisabledBufferReadReturnsZero() {
        let buffer = PVRingBuffer(withLength: 4096)!
        buffer.isEnabled = false

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 1)
        defer { readBuf.deallocate() }
        let result = buffer.read(readBuf, preferredSize: 256)
        #expect(result == 0)
    }

    @Test func testReenablingBufferAllowsOperations() {
        let buffer = PVRingBuffer(withLength: 4096)!
        buffer.isEnabled = false
        buffer.isEnabled = true

        let writeSize = 256
        let data = makeBuffer(writeSize, fill: 0xCD)
        let writeResult = data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }
        #expect(writeResult == writeSize)

        let readBuf = UnsafeMutableRawPointer.allocate(byteCount: writeSize, alignment: 1)
        defer { readBuf.deallocate() }
        let readResult = buffer.read(readBuf, preferredSize: writeSize)
        #expect(readResult == writeSize)
    }
}

// MARK: - availableBytes Property Tests

struct TestPVRingBufferAvailableBytes {

    @Test func testAvailableBytesMatchesAvailableBytesForReading() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting
        let writeSize = capacity / 3

        let data = makeBuffer(writeSize)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: writeSize)
        }

        #expect(buffer.availableBytes == buffer.availableBytesForReading)
        #expect(buffer.availableBytes == writeSize)
    }

    @Test func testAvailableBytesZeroOnInit() {
        let buffer = PVRingBuffer(withLength: 4096)!
        #expect(buffer.availableBytes == 0)
    }

    @Test func testAvailableBytesAfterReset() {
        let buffer = PVRingBuffer(withLength: 4096)!
        let capacity = buffer.availableBytesForWriting

        let data = makeBuffer(capacity / 2)
        data.withUnsafeBytes { ptr in
            buffer.write(ptr.baseAddress!, size: capacity / 2)
        }
        buffer.reset()
        #expect(buffer.availableBytes == 0)
    }
}

// MARK: - Concurrency Tests

struct TestPVRingBufferConcurrency {

    @Test func testConcurrentReadWriteDoesNotCrash() async {
        let buffer = PVRingBuffer(withLength: 65536)!
        let iterations = 200
        let chunkSize = 128

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let data = makeBuffer(chunkSize, fill: 0xAB)
                for _ in 0..<iterations {
                    data.withUnsafeBytes { ptr in
                        buffer.write(ptr.baseAddress!, size: chunkSize)
                    }
                    await Task.yield()
                }
            }

            group.addTask {
                let readBuf = UnsafeMutableRawPointer.allocate(byteCount: chunkSize, alignment: 1)
                defer { readBuf.deallocate() }
                for _ in 0..<iterations {
                    buffer.read(readBuf, preferredSize: chunkSize)
                    await Task.yield()
                }
            }
        }

        // If we get here without crashing, concurrency is handled
        #expect(true)
    }

    @Test func testConcurrentWritersDoNotCrash() async {
        let buffer = PVRingBuffer(withLength: 65536)!
        let iterations = 100
        let chunkSize = 64

        await withTaskGroup(of: Void.self) { group in
            for writerIdx in 0..<4 {
                group.addTask {
                    let data = makeBuffer(chunkSize, fill: UInt8(writerIdx % 256))
                    for _ in 0..<iterations {
                        data.withUnsafeBytes { ptr in
                            buffer.write(ptr.baseAddress!, size: chunkSize)
                        }
                        await Task.yield()
                    }
                }
            }
        }

        #expect(true)
    }
}

// MARK: - Protocol Conformance / Factory Integration Tests

struct TestPVRingBuffer {

    @Test func testLargeRingBuffer() async throws {
        let bufferSize = 16384 * 8
        try await testRingBuffer(ofSize: bufferSize)
    }

    @Test func testSmallRingBuffer() async throws {
        let bufferSize = 1024
        try await testRingBuffer(ofSize: bufferSize)
    }

    @Test func testViaFactory() {
        let buffer = RingBufferFactory.make(type: .provenance, withLength: 4096)
        #expect(buffer != nil)
        #expect(buffer is PVRingBuffer)
    }

    @Test func testProtocolConformance() {
        let buffer: RingBufferProtocol? = PVRingBuffer(withLength: 4096)
        #expect(buffer != nil)
        #expect(buffer?.availableBytesForReading == 0)
        #expect(buffer?.availableBytesForWriting ?? 0 > 0)
    }
}

extension TestPVRingBuffer {
    func testRingBuffer(ofSize size: Int) async throws {
        let ringBuffer = PVRingBuffer(withLength: size)!
        // Actual capacity may be larger due to page alignment
        let actualCapacity = ringBuffer.availableBytesForWriting
        let testSize = min(512, actualCapacity / 2)

        #expect(ringBuffer.isEnabled)
        #expect(ringBuffer.availableBytesForWriting == actualCapacity)
        #expect(ringBuffer.availableBytesForReading == 0)

        let writeBuffer = UnsafeMutableRawPointer.allocate(byteCount: testSize, alignment: 1)
        defer { writeBuffer.deallocate() }
        memset(writeBuffer, 0xAB, testSize)

        let writtenBytes = ringBuffer.write(writeBuffer, size: testSize)

        #expect(writtenBytes == testSize)
        #expect(ringBuffer.availableBytesForWriting == actualCapacity - testSize)
        #expect(ringBuffer.availableBytesForReading == testSize)
    }
}
